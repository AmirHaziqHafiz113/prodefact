import assert from "node:assert/strict";
import {test} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import {handleClassifyFinding} from "./handle_classify_finding";
import {AiProvider, AiProviderError} from "./ai/provider";
import {
  ClassificationResult,
  ClassifyFindingInput,
  FindingImages,
} from "./ai/types";

const VALID_ID = "door.door_hinge.03"; // "produces a creaking sound..."

/** @return {Record<string, unknown>} a minimal, valid payload. */
function basePayload() {
  return {
    inspectionId: "inspection_1",
    findingId: "finding_1",
    area: "Master Bathroom",
    isPlumbingArea: true,
    // Names the component, so VALID_ID is on this finding's shortlist
    // (an id the request was not offered is rejected).
    note: "door hinge creaking",
  };
}

type ClassifyImpl = (
  input: ClassifyFindingInput,
  images: FindingImages
) => Promise<ClassificationResult>;

/**
 * @param {ClassifyImpl} classify the fake classify implementation.
 * @param {boolean} [supportsImages] whether the fake supports images.
 * @return {AiProvider} a fake provider.
 */
function fakeProvider(
  classify: ClassifyImpl,
  supportsImages = false
): AiProvider {
  return {
    id: "fake",
    supportsImages,
    classifyFinding: async (input, images) => ({
      result: await classify(input, images),
    }),
  };
}

// Neither Firestore nor Storage is ever touched by these tests, since
// every fake provider here has supportsImages: false — passing objects
// that would throw if called is itself a check that evidence
// resolution is correctly skipped.
const untouchedFirestore = new Proxy(
  {},
  {get: () => {
    throw new Error("Firestore should not be touched");
  }}
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
) as any;
const untouchedStorage = new Proxy(
  {},
  {get: () => {
    throw new Error("Storage should not be touched");
  }}
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
) as any;

test("an unauthenticated request is rejected before the provider is " +
  "ever invoked", async () => {
  let called = false;
  const provider = fakeProvider(async (input) => {
    called = true;
    return {findingId: input.findingId, needsReview: true};
  });

  await assert.rejects(
    () =>
      handleClassifyFinding({
        auth: null,
        data: basePayload(),
        provider,
        firestore: untouchedFirestore,
        storage: untouchedStorage,
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal((error as HttpsError).code, "unauthenticated");
      return true;
    }
  );
  assert.equal(called, false);
});

test("a malformed payload is rejected as invalid-argument", async () => {
  const provider = fakeProvider(async (input) => ({
    findingId: input.findingId,
    needsReview: true,
  }));

  await assert.rejects(
    () =>
      handleClassifyFinding({
        auth: {uid: "uid_1"},
        data: {inspectionId: "inspection_1"}, // missing findingId/area
        provider,
        firestore: untouchedFirestore,
        storage: untouchedStorage,
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal((error as HttpsError).code, "invalid-argument");
      return true;
    }
  );
});

test("a valid catalogue id from the provider is accepted", async () => {
  const provider = fakeProvider(async (input) => ({
    findingId: input.findingId,
    catalogueEntryId: VALID_ID,
    needsReview: false,
  }));

  const result = await handleClassifyFinding({
    auth: {uid: "uid_1"},
    data: basePayload(),
    provider,
    firestore: untouchedFirestore,
    storage: untouchedStorage,
  });

  assert.equal(result.catalogueEntryId, VALID_ID);
  assert.equal(result.needsReview, false);
});

test("a hallucinated/unknown catalogue id from the provider is " +
  "rejected — the response is forced to needsReview instead of " +
  "reaching the client with a fake id", async () => {
  const provider = fakeProvider(async (input) => ({
    findingId: input.findingId,
    catalogueEntryId: "totally_made_up.entry.1",
    needsReview: false,
  }));

  const result = await handleClassifyFinding({
    auth: {uid: "uid_1"},
    data: basePayload(),
    provider,
    firestore: untouchedFirestore,
    storage: untouchedStorage,
  });

  assert.equal(result.catalogueEntryId, undefined);
  assert.equal(result.needsReview, true);
});

test("needs_review behavior: a provider that can't confidently " +
  "classify returns needsReview with no catalogueEntryId", async () => {
  const provider = fakeProvider(async (input) => ({
    findingId: input.findingId,
    needsReview: true,
    candidateEntryIds: [VALID_ID],
  }));

  const result = await handleClassifyFinding({
    auth: {uid: "uid_1"},
    data: basePayload(),
    provider,
    firestore: untouchedFirestore,
    storage: untouchedStorage,
  });

  assert.equal(result.needsReview, true);
  assert.equal(result.catalogueEntryId, undefined);
  assert.deepEqual(result.candidateEntryIds, [VALID_ID]);
});

test("a provider timeout maps to deadline-exceeded, never a raw " +
  "provider error message", async () => {
  const provider = fakeProvider(async () => {
    throw new AiProviderError("DeepSeek request failed (transient).");
  });

  await assert.rejects(
    () =>
      handleClassifyFinding({
        auth: {uid: "uid_1"},
        data: basePayload(),
        provider,
        firestore: untouchedFirestore,
        storage: untouchedStorage,
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal((error as HttpsError).code, "deadline-exceeded");
      assert.doesNotMatch(
        (error as HttpsError).message,
        /DeepSeek/
      );
      return true;
    }
  );
});

test("a non-transient provider failure maps to internal, never a raw " +
  "provider error message", async () => {
  const provider = fakeProvider(async () => {
    throw new AiProviderError("DeepSeek request failed with status 401.");
  });

  await assert.rejects(
    () =>
      handleClassifyFinding({
        auth: {uid: "uid_1"},
        data: basePayload(),
        provider,
        firestore: untouchedFirestore,
        storage: untouchedStorage,
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal((error as HttpsError).code, "internal");
      assert.doesNotMatch((error as HttpsError).message, /401/);
      return true;
    }
  );
});

test("ownership enforcement: evidence resolution is only attempted for " +
  "an image-capable provider — a text-only provider never touches " +
  "Firestore/Storage at all", async () => {
  const provider = fakeProvider(async (input) => ({
    findingId: input.findingId,
    needsReview: true,
  }), false);

  // Would throw if Firestore/Storage were touched — see
  // untouchedFirestore/untouchedStorage above.
  const result = await handleClassifyFinding({
    auth: {uid: "uid_1"},
    data: {...basePayload(), evidenceIds: ["evidence_1"]},
    provider,
    firestore: untouchedFirestore,
    storage: untouchedStorage,
  });
  assert.equal(result.needsReview, true);
});
