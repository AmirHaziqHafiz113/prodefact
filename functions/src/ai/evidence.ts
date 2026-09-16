import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";
import sharp from "sharp";
import {ClassifyFindingInput, FindingImages, ResolvedImage} from "./types";

/** Never trust a client-supplied path — see `resolveEvidenceImage`. */
export const MAX_IMAGES_PER_FINDING = 4;
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
 * Resolves one finding's requested evidence, bounded so a client can
 * never force an unbounded number of downloads/decodes: at most
 * [MAX_IMAGES_PER_FINDING] images, downloaded with bounded concurrency
 * so several photos don't all download/decode at once. A caller with
 * more evidence ids than that limit still gets a useful (partial)
 * result rather than a rejection — see `unavailableCount`.
 * @param {object} params the resolution parameters.
 * @param {string} params.uid the authenticated caller's uid.
 * @param {ClassifyFindingInput} params.input the validated request.
 * @param {Firestore} params.firestore the Admin Firestore client.
 * @param {Storage} params.storage the Admin Storage client.
 * @return {Promise<FindingImages>} the resolved images for this finding.
 */
export async function resolveFindingEvidence(params: {
  uid: string;
  input: ClassifyFindingInput;
  firestore: Firestore;
  storage: Storage;
}): Promise<FindingImages> {
  const {uid, input, firestore, storage} = params;
  const evidenceIds = (input.evidenceIds ?? []).slice(
    0,
    MAX_IMAGES_PER_FINDING
  );

  // Bounded concurrency — a handful of downloads in flight at once
  // rather than one at a time (slow) or all at once (a burst of large
  // Storage/decoding work per request).
  const CONCURRENCY = 4;
  const images: ResolvedImage[] = [];
  let cursor = 0;
  /** Pulls evidence ids off the shared queue until it's empty. */
  async function worker() {
    while (cursor < evidenceIds.length) {
      const evidenceId = evidenceIds[cursor++];
      const resolved = await resolveEvidenceImage({
        uid,
        inspectionId: input.inspectionId,
        findingId: input.findingId,
        evidenceId,
        firestore,
        storage,
      });
      if (resolved) images.push(resolved);
    }
  }
  await Promise.all(
    Array.from(
      {length: Math.min(CONCURRENCY, evidenceIds.length)},
      () => worker()
    )
  );

  return {
    findingId: input.findingId,
    images,
    unavailableCount: Math.max(0, evidenceIds.length - images.length),
  };
}
