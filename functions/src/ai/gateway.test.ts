import assert from "node:assert/strict";
import {test} from "node:test";
import {resolveProviderId, validateAndNormalize} from "./gateway";
import {AnalyzeInspectionInput, AnalyzeInspectionResult} from "./types";

/** @return {AnalyzeInspectionInput} a small, two-finding sample request. */
function sampleInput(): AnalyzeInspectionInput {
  return {
    inspectionId: "inspection_1",
    propertyType: "highRise",
    findings: [
      {
        findingId: "finding_1",
        area: "Master Bathroom",
        isPlumbingArea: true,
        element: "Floor",
        evidenceCount: 1,
      },
      {
        findingId: "finding_2",
        area: "Kitchen",
        isPlumbingArea: true,
        element: "Wall",
        evidenceCount: 0,
      },
    ],
  };
}

test("keeps a suggestion matching a requested findingId", () => {
  const result: AnalyzeInspectionResult = {
    providerId: "deepseek",
    suggestions: [
      {
        findingId: "finding_1",
        defectType: "Cracked tile",
        recommendation: "Replace tile",
      },
    ],
  };
  const normalized = validateAndNormalize(sampleInput(), result);
  assert.equal(normalized.suggestions.length, 1);
  assert.equal(normalized.suggestions[0].findingId, "finding_1");
  assert.equal(normalized.suggestions[0].defectType, "Cracked tile");
});

test("rejects a suggestion for an unknown findingId", () => {
  const result: AnalyzeInspectionResult = {
    providerId: "deepseek",
    suggestions: [
      {findingId: "finding_1", defectType: "Cracked tile"},
      {
        findingId: "finding_never_requested",
        defectType: "Should be dropped",
      },
    ],
  };
  const normalized = validateAndNormalize(sampleInput(), result);
  assert.equal(normalized.suggestions.length, 1);
  assert.equal(normalized.suggestions[0].findingId, "finding_1");
});

test("drops a duplicate findingId, keeping the first", () => {
  const result: AnalyzeInspectionResult = {
    providerId: "deepseek",
    suggestions: [
      {findingId: "finding_1", defectType: "First"},
      {findingId: "finding_1", defectType: "Duplicate, dropped"},
    ],
  };
  const normalized = validateAndNormalize(sampleInput(), result);
  assert.equal(normalized.suggestions.length, 1);
  assert.equal(normalized.suggestions[0].defectType, "First");
});

test("coerces a non-string field to undefined instead of throwing", () => {
  const result = {
    providerId: "deepseek",
    suggestions: [
      {findingId: "finding_1", defectType: 12345},
    ],
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as any as AnalyzeInspectionResult;
  const normalized = validateAndNormalize(sampleInput(), result);
  assert.equal(normalized.suggestions.length, 1);
  assert.equal(normalized.suggestions[0].defectType, undefined);
});

test("handles an empty suggestions array", () => {
  const result: AnalyzeInspectionResult = {
    providerId: "deepseek",
    suggestions: [],
  };
  const normalized = validateAndNormalize(sampleInput(), result);
  assert.deepEqual(normalized.suggestions, []);
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
