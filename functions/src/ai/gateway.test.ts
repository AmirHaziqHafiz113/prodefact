import assert from "node:assert/strict";
import {test} from "node:test";
import {resolveProviderId, validateAndNormalize} from "./gateway";
import {ClassificationResult, ClassifyFindingInput} from "./types";

/** @return {ClassifyFindingInput} a sample plumbing-area request. */
function sampleInput(): ClassifyFindingInput {
  return {
    inspectionId: "inspection_1",
    findingId: "finding_1",
    area: "Master Bathroom",
    isPlumbingArea: true,
  };
}

// Two real, valid catalogue ids used across these tests.
const VALID_ID = "sanitary_fitting.water_tap.03"; // "leaking/dripping"
const OTHER_VALID_ID = "sanitary_fitting.water_tap.02"; // "is damaged"

test("keeps a valid catalogue id and marks it not needing review", () => {
  const result: ClassificationResult = {
    findingId: "finding_1",
    catalogueEntryId: VALID_ID,
    confidence: 0.9,
    needsReview: false,
  };
  const normalized = validateAndNormalize(sampleInput(), result);
  assert.equal(normalized.catalogueEntryId, VALID_ID);
  assert.equal(normalized.needsReview, false);
});

test("rejects a hallucinated/unknown catalogue id — forces needsReview", () => {
  const result: ClassificationResult = {
    findingId: "finding_1",
    catalogueEntryId: "made_up.entry.99",
    needsReview: false,
  };
  const normalized = validateAndNormalize(sampleInput(), result);
  assert.equal(normalized.catalogueEntryId, undefined);
  assert.equal(normalized.needsReview, true);
});

test("a response for a different findingId is rejected as needsReview", () => {
  const result: ClassificationResult = {
    findingId: "finding_other",
    catalogueEntryId: VALID_ID,
    needsReview: false,
  };
  const normalized = validateAndNormalize(sampleInput(), result);
  assert.equal(normalized.findingId, "finding_1");
  assert.equal(normalized.catalogueEntryId, undefined);
  assert.equal(normalized.needsReview, true);
});

test("filters candidateEntryIds to valid ids only, deduplicated and " +
  "capped", () => {
  const result: ClassificationResult = {
    findingId: "finding_1",
    needsReview: true,
    candidateEntryIds: [
      VALID_ID,
      VALID_ID,
      OTHER_VALID_ID,
      "made_up.entry.1",
      "made_up.entry.2",
      "made_up.entry.3",
      "made_up.entry.4",
      "made_up.entry.5",
      "made_up.entry.6",
    ],
  };
  const normalized = validateAndNormalize(sampleInput(), result);
  assert.deepEqual(normalized.candidateEntryIds, [VALID_ID, OTHER_VALID_ID]);
});

test("clamps an out-of-range confidence to [0, 1]", () => {
  const tooHigh = validateAndNormalize(sampleInput(), {
    findingId: "finding_1",
    catalogueEntryId: VALID_ID,
    confidence: 5,
    needsReview: false,
  });
  assert.equal(tooHigh.confidence, 1);

  const negative = validateAndNormalize(sampleInput(), {
    findingId: "finding_1",
    catalogueEntryId: VALID_ID,
    confidence: -3,
    needsReview: false,
  });
  assert.equal(negative.confidence, 0);
});

test("coerces a non-string shortReason to undefined instead of " +
  "throwing", () => {
  const result = {
    findingId: "finding_1",
    catalogueEntryId: VALID_ID,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    shortReason: 12345 as any,
    needsReview: false,
  } as ClassificationResult;
  const normalized = validateAndNormalize(sampleInput(), result);
  assert.equal(normalized.shortReason, undefined);
});

test("needsReview stays true when explicitly set even with a valid id", () => {
  const normalized = validateAndNormalize(sampleInput(), {
    findingId: "finding_1",
    catalogueEntryId: VALID_ID,
    needsReview: true,
  });
  assert.equal(normalized.needsReview, true);
  // The id itself is still preserved/valid — needsReview only affects
  // how the caller treats it (e.g. still offering it as a candidate).
  assert.equal(normalized.catalogueEntryId, VALID_ID);
});

test("resolveProviderId defaults to deepseek when unset", () => {
  assert.equal(resolveProviderId({}), "deepseek");
});

test("resolveProviderId defaults to deepseek for an unsupported value", () => {
  assert.equal(
    resolveProviderId({AI_PROVIDER: "not-a-real-provider"}),
    "deepseek"
  );
});

test("resolveProviderId honors a supported configured value", () => {
  assert.equal(resolveProviderId({AI_PROVIDER: "openai"}), "openai");
  assert.equal(resolveProviderId({AI_PROVIDER: "GEMINI"}), "gemini");
});
