import assert from "node:assert/strict";
import {test} from "node:test";
import {resolveEvidenceImage, resolveFindingEvidence} from "./evidence";
import {ClassifyFindingInput} from "./types";

// A genuine, valid tiny (4x4) PNG — small, real, decodable image
// bytes (generated via `sharp` itself and verified to decode cleanly)
// so these tests exercise real decode/resize/re-encode rather than a
// mock.
const TINY_PNG_BASE64 =
  "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAACXBIWXMAAAPoAAAD" +
  "6AG1e1JrAAAAEElEQVQImWM4YWQERwzEcQDxIxLBd1QpUgAAAABJRU5ErkJggg==";

/**
 * A minimal fake matching only the Firestore surface `evidence.ts`
 * actually calls.
 * @param {Set<string>} existingDocIds evidence ids to report as owned.
 * @return {unknown} the fake Firestore client.
 */
function fakeFirestore(existingDocIds: Set<string>) {
  return {
    // users/{uid}/inspections/{inspectionId}/findings/{findingId}/
    //   evidence/{evidenceId} — four collection()/doc() pairs deep,
    // matching `evidenceIsOwnedByCaller` exactly.
    collection: () => ({
      doc: () => ({
        collection: () => ({
          doc: () => ({
            collection: () => ({
              doc: () => ({
                collection: () => ({
                  doc: (evidenceId: string) => ({
                    get: async () => ({
                      exists: existingDocIds.has(evidenceId),
                    }),
                  }),
                }),
              }),
            }),
          }),
        }),
      }),
    }),
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as any;
}

/**
 * A minimal fake matching only the Storage surface `evidence.ts`
 * actually calls.
 * @param {Map<string, Buffer>} filesByPath bytes keyed by path.
 * @return {unknown} the fake Storage client.
 */
function fakeStorage(filesByPath: Map<string, Buffer>) {
  return {
    bucket: () => ({
      file: (path: string) => ({
        exists: async () => [filesByPath.has(path)],
        getMetadata: async () => [
          {size: filesByPath.get(path)?.length ?? 0},
        ],
        download: async () => [filesByPath.get(path)],
      }),
    }),
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as any;
}

/**
 * @param {string} id the finding id.
 * @param {string[]} [evidenceIds] evidence ids to request.
 * @return {ClassifyFindingInput} a minimal valid finding.
 */
function baseFinding(
  id: string,
  evidenceIds?: string[]
): ClassifyFindingInput {
  return {
    inspectionId: "inspection_1",
    findingId: id,
    area: "Master Bathroom",
    isPlumbingArea: true,
    evidenceIds,
  };
}

test("resolveEvidenceImage returns null when no Firestore metadata " +
  "document exists at the caller's own path (ownership check)", async () => {
  const firestore = fakeFirestore(new Set()); // nothing owned
  const storage = fakeStorage(new Map());

  const result = await resolveEvidenceImage({
    uid: "uid_1",
    inspectionId: "inspection_1",
    findingId: "finding_1",
    evidenceId: "evidence_1",
    firestore,
    storage,
  });

  assert.equal(result, null);
});

test("resolveEvidenceImage returns null when the Storage object is " +
  "missing even though the Firestore document exists (unsynced photo)",
async () => {
  const firestore = fakeFirestore(new Set(["evidence_1"]));
  const storage = fakeStorage(new Map()); // no file at the derived path

  const result = await resolveEvidenceImage({
    uid: "uid_1",
    inspectionId: "inspection_1",
    findingId: "finding_1",
    evidenceId: "evidence_1",
    firestore,
    storage,
  });

  assert.equal(result, null);
});

test("resolveEvidenceImage downloads, decodes, and re-encodes a real " +
  "image as normalized JPEG base64", async () => {
  const path =
    "users/uid_1/inspections/inspection_1/findings/finding_1/evidence_1.jpg";
  const firestore = fakeFirestore(new Set(["evidence_1"]));
  const storage = fakeStorage(
    new Map([[path, Buffer.from(TINY_PNG_BASE64, "base64")]])
  );

  const result = await resolveEvidenceImage({
    uid: "uid_1",
    inspectionId: "inspection_1",
    findingId: "finding_1",
    evidenceId: "evidence_1",
    firestore,
    storage,
  });

  assert.notEqual(result, null);
  assert.equal(result?.evidenceId, "evidence_1");
  assert.equal(result?.mimeType, "image/jpeg");
  assert.ok((result?.base64.length ?? 0) > 0);
});

test("resolveEvidenceImage returns null (never throws) for corrupted/" +
  "undecodable image bytes", async () => {
  const path =
    "users/uid_1/inspections/inspection_1/findings/finding_1/evidence_1.jpg";
  const firestore = fakeFirestore(new Set(["evidence_1"]));
  const storage = fakeStorage(
    new Map([[path, Buffer.from("not a real image", "utf8")]])
  );

  const result = await resolveEvidenceImage({
    uid: "uid_1",
    inspectionId: "inspection_1",
    findingId: "finding_1",
    evidenceId: "evidence_1",
    firestore,
    storage,
  });

  assert.equal(result, null);
});

test("resolveFindingEvidence never trusts a client-supplied path — it " +
  "only ever derives the path itself from uid/inspectionId/findingId/" +
  "evidenceId, regardless of what the caller's request contained",
async () => {
  const legitimatePath =
    "users/uid_1/inspections/inspection_1/findings/finding_1/evidence_1.jpg";
  const attackerPath = "users/someone_else/secret.jpg";
  const firestore = fakeFirestore(new Set(["evidence_1"]));
  const storage = fakeStorage(
    new Map([
      [legitimatePath, Buffer.from(TINY_PNG_BASE64, "base64")],
      [attackerPath, Buffer.from(TINY_PNG_BASE64, "base64")],
    ])
  );

  const result = await resolveFindingEvidence({
    uid: "uid_1",
    input: baseFinding("finding_1", ["evidence_1"]),
    firestore,
    storage,
  });

  assert.equal(result.images.length, 1);
  // Resolution succeeded purely because the *derived* canonical path
  // matched — there was never a "path" field anywhere in the input for
  // an attacker to control in the first place.
});

test("resolveFindingEvidence reports partial failure without " +
  "discarding the finding entirely when some evidence can't be resolved",
async () => {
  const goodPath =
    "users/uid_1/inspections/inspection_1/findings/finding_1/good.jpg";
  const firestore = fakeFirestore(new Set(["good", "missing"]));
  const storage = fakeStorage(
    new Map([[goodPath, Buffer.from(TINY_PNG_BASE64, "base64")]])
  );

  const result = await resolveFindingEvidence({
    uid: "uid_1",
    input: baseFinding("finding_1", ["good", "missing"]),
    firestore,
    storage,
  });

  assert.equal(result.images.length, 1);
  assert.equal(result.images[0].evidenceId, "good");
  assert.equal(result.unavailableCount, 1);
});

test("resolveFindingEvidence caps the number of images resolved per " +
  "finding, protecting against an excessive evidenceIds array",
async () => {
  const ids = Array.from({length: 10}, (_, i) => `evidence_${i}`);
  const firestore = fakeFirestore(new Set(ids));
  const storage = fakeStorage(
    new Map(
      ids.map((id) => [
        `users/uid_1/inspections/inspection_1/findings/finding_1/${id}.jpg`,
        Buffer.from(TINY_PNG_BASE64, "base64"),
      ])
    )
  );

  const result = await resolveFindingEvidence({
    uid: "uid_1",
    input: baseFinding("finding_1", ids),
    firestore,
    storage,
  });

  // Bounded well below the raw 10 ids supplied.
  assert.ok(result.images.length <= 4);
});

test("resolveFindingEvidence returns an empty (not error) result for a " +
  "finding with no evidenceIds at all", async () => {
  const firestore = fakeFirestore(new Set());
  const storage = fakeStorage(new Map());

  const result = await resolveFindingEvidence({
    uid: "uid_1",
    input: baseFinding("finding_1"),
    firestore,
    storage,
  });

  assert.equal(result.images.length, 0);
  assert.equal(result.unavailableCount, 0);
});
