import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";
import sharp from "sharp";
import {FindingImages, FindingInput, ResolvedImage} from "./types";

/** Never trust a client-supplied path — see `resolveEvidenceImage`. */
const MAX_IMAGES_PER_FINDING = 4;
const MAX_IMAGES_PER_REQUEST = 24;
const MAX_SOURCE_BYTES = 15 * 1024 * 1024; // guard before decoding at all
// Long edge, in pixels — ample defect detail, bounded cost/tokens.
const MAX_OUTPUT_DIMENSION = 1568;
const OUTPUT_JPEG_QUALITY = 82;

/**
 * The exact Storage path convention the app itself uses when
 * uploading evidence (see `_storagePathFor` in
 * `firestore_cloud_inspection_repository.dart`) — reproduced here so
 * the path is always *derived* from the authenticated caller's own
 * uid plus this request's own ids, never accepted from the client.
 * @param {string} uid the authenticated caller's uid.
 * @param {string} inspectionId the inspection id.
 * @param {string} findingId the finding id.
 * @param {string} evidenceId the evidence id.
 * @return {string} the canonical Storage object path.
 */
function canonicalStoragePath(
  uid: string,
  inspectionId: string,
  findingId: string,
  evidenceId: string
): string {
  return (
    `users/${uid}/inspections/${inspectionId}/findings/` +
    `${findingId}/${evidenceId}.jpg`
  );
}

/**
 * Confirms ownership independently of the Storage download: a
 * Firestore evidence-metadata document must exist at exactly
 * `users/{uid}/inspections/{inspectionId}/findings/{findingId}/` +
 * `evidence/{evidenceId}` — the same rules-protected location every
 * other evidence write already uses. This never trusts anything the
 * document *contains*
 * (e.g. any `storagePath` field on it); it only checks the document
 * exists at the caller's own path, then downloads from the path this
 * module derives itself.
 * @param {Firestore} firestore the Admin Firestore client.
 * @param {string} uid the authenticated caller's uid.
 * @param {string} inspectionId the inspection id.
 * @param {string} findingId the finding id.
 * @param {string} evidenceId the evidence id.
 * @return {Promise<boolean>} whether the metadata document exists.
 */
async function evidenceIsOwnedByCaller(
  firestore: Firestore,
  uid: string,
  inspectionId: string,
  findingId: string,
  evidenceId: string
): Promise<boolean> {
  const doc = await firestore
    .collection("users")
    .doc(uid)
    .collection("inspections")
    .doc(inspectionId)
    .collection("findings")
    .doc(findingId)
    .collection("evidence")
    .doc(evidenceId)
    .get();
  return doc.exists;
}

/**
 * Downloads, validates, and normalizes one evidence image. Returns
 * null (never throws) for anything that can't be safely used — a
 * missing Firestore record, a missing/oversized Storage object, or an
 * image `sharp` can't decode (corrupted/unsupported) — so one bad
 * photo never fails the finding or the request; see
 * `docs/production_readiness.md` ("Partial evidence handling").
 * @param {object} params the resolution parameters.
 * @param {string} params.uid the authenticated caller's uid.
 * @param {string} params.inspectionId the inspection id.
 * @param {string} params.findingId the finding id.
 * @param {string} params.evidenceId the evidence id to resolve.
 * @param {Firestore} params.firestore the Admin Firestore client.
 * @param {Storage} params.storage the Admin Storage client.
 * @return {Promise<ResolvedImage | null>} the resolved image, or null.
 */
export async function resolveEvidenceImage(params: {
  uid: string;
  inspectionId: string;
  findingId: string;
  evidenceId: string;
  firestore: Firestore;
  storage: Storage;
}): Promise<ResolvedImage | null> {
  const {uid, inspectionId, findingId, evidenceId, firestore, storage} =
    params;
  try {
    const owned = await evidenceIsOwnedByCaller(
      firestore,
      uid,
      inspectionId,
      findingId,
      evidenceId
    );
    if (!owned) return null;

    const path = canonicalStoragePath(uid, inspectionId, findingId, evidenceId);
    const file = storage.bucket().file(path);
    const [exists] = await file.exists();
    if (!exists) return null;

    const [metadata] = await file.getMetadata();
    const size = Number(metadata.size ?? 0);
    if (size <= 0 || size > MAX_SOURCE_BYTES) return null;

    const [bytes] = await file.download();

    // `sharp` both validates (throws on anything it can't decode —
    // this is the corrupted/unsupported-format guard) and normalizes:
    // auto-orients per EXIF, downsamples to a bounded long edge, and
    // re-encodes as JPEG at a fixed quality so payload size/tokens are
    // predictable regardless of the original photo's resolution.
    const normalized = await sharp(bytes)
      .rotate()
      .resize({
        width: MAX_OUTPUT_DIMENSION,
        height: MAX_OUTPUT_DIMENSION,
        fit: "inside",
        withoutEnlargement: true,
      })
      .jpeg({quality: OUTPUT_JPEG_QUALITY})
      .toBuffer();

    return {
      evidenceId,
      mimeType: "image/jpeg",
      base64: normalized.toString("base64"),
    };
  } catch {
    // Any failure (Firestore/Storage error, corrupted image, etc.) —
    // treat as "unavailable", never as a request-ending error.
    return null;
  }
}

/**
 * Resolves every finding's requested evidence, bounded so a client
 * can never force an unbounded number of downloads/decodes: at most
 * [MAX_IMAGES_PER_FINDING] per finding and [MAX_IMAGES_PER_REQUEST]
 * total, with bounded concurrency so many images don't all download
 * at once.
 * @param {object} params the resolution parameters.
 * @param {string} params.uid the authenticated caller's uid.
 * @param {string} params.inspectionId the inspection id.
 * @param {FindingInput[]} params.findings the validated request findings.
 * @param {Firestore} params.firestore the Admin Firestore client.
 * @param {Storage} params.storage the Admin Storage client.
 * @return {Promise<FindingImages[]>} resolved images per finding.
 */
export async function resolveAllEvidence(params: {
  uid: string;
  inspectionId: string;
  findings: FindingInput[];
  firestore: Firestore;
  storage: Storage;
}): Promise<FindingImages[]> {
  const {uid, inspectionId, findings, firestore, storage} = params;

  type Job = {findingId: string; evidenceId: string};
  const jobs: Job[] = [];
  for (const finding of findings) {
    const ids = (finding.evidenceIds ?? []).slice(0, MAX_IMAGES_PER_FINDING);
    for (const evidenceId of ids) {
      if (jobs.length >= MAX_IMAGES_PER_REQUEST) break;
      jobs.push({findingId: finding.findingId, evidenceId});
    }
    if (jobs.length >= MAX_IMAGES_PER_REQUEST) break;
  }

  const resolvedByFinding = new Map<string, ResolvedImage[]>();
  const requestedByFinding = new Map<string, number>();
  for (const finding of findings) {
    requestedByFinding.set(
      finding.findingId,
      Math.min(finding.evidenceIds?.length ?? 0, MAX_IMAGES_PER_FINDING)
    );
  }

  // Bounded concurrency — a handful of downloads in flight at once
  // rather than one at a time (slow) or all at once (a burst of large
  // Storage/decoding work per request).
  const CONCURRENCY = 4;
  let cursor = 0;
  /** Pulls jobs off the shared queue until it's empty. */
  async function worker() {
    while (cursor < jobs.length) {
      const job = jobs[cursor++];
      const resolved = await resolveEvidenceImage({
        uid,
        inspectionId,
        findingId: job.findingId,
        evidenceId: job.evidenceId,
        firestore,
        storage,
      });
      if (resolved) {
        const list = resolvedByFinding.get(job.findingId) ?? [];
        list.push(resolved);
        resolvedByFinding.set(job.findingId, list);
      }
    }
  }
  await Promise.all(
    Array.from({length: Math.min(CONCURRENCY, jobs.length)}, () => worker())
  );

  return findings.map((finding) => {
    const images = resolvedByFinding.get(finding.findingId) ?? [];
    const requested = requestedByFinding.get(finding.findingId) ?? 0;
    return {
      findingId: finding.findingId,
      images,
      unavailableCount: Math.max(0, requested - images.length),
    };
  });
}
