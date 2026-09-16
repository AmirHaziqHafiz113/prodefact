import assert from "node:assert/strict";
import {test} from "node:test";
import {
  MAX_EVIDENCE_IDS_PER_FINDING,
  MAX_FINDINGS_PER_REQUEST,
  MAX_TEXT_FIELD_LENGTH,
  parseAnalyzeInspectionInput,
} from "./validation";

/**
 * @param {string} id the finding id.
 * @return {object} a minimal, valid finding payload.
 */
function baseFinding(id: string) {
  return {
    findingId: id,
    area: "Master Bathroom",
    isPlumbingArea: true,
    element: "Floor",
    evidenceCount: 1,
  };
}

test("parses a well-formed payload", () => {
  const input = parseAnalyzeInspectionInput({
    inspectionId: "inspection_1",
    propertyType: "highRise",
    findings: [baseFinding("finding_1")],
  });
  assert.equal(input.inspectionId, "inspection_1");
  assert.equal(input.findings.length, 1);
  assert.equal(input.findings[0].isPlumbingArea, true);
});

test("rejects a non-object payload", () => {
  assert.throws(() => parseAnalyzeInspectionInput(null));
  assert.throws(() => parseAnalyzeInspectionInput("not an object"));
});

test("rejects a missing findings array", () => {
  assert.throws(() =>
    parseAnalyzeInspectionInput({
      inspectionId: "inspection_1",
      propertyType: "highRise",
    })
  );
});

test("rejects an empty findings array", () => {
  assert.throws(() =>
    parseAnalyzeInspectionInput({
      inspectionId: "inspection_1",
      propertyType: "highRise",
      findings: [],
    })
  );
});

test("rejects more than the maximum number of findings", () => {
  const findings = Array.from(
    {length: MAX_FINDINGS_PER_REQUEST + 1},
    (_, i) => baseFinding(`finding_${i}`)
  );
  assert.throws(() =>
    parseAnalyzeInspectionInput({
      inspectionId: "inspection_1",
      propertyType: "highRise",
      findings,
    })
  );
});

test("rejects a duplicate findingId", () => {
  assert.throws(() =>
    parseAnalyzeInspectionInput({
      inspectionId: "inspection_1",
      propertyType: "highRise",
      findings: [baseFinding("finding_1"), baseFinding("finding_1")],
    })
  );
});

test("rejects an excessively long text field", () => {
  const finding = {
    ...baseFinding("finding_1"),
    description: "x".repeat(MAX_TEXT_FIELD_LENGTH + 1),
  };
  assert.throws(() =>
    parseAnalyzeInspectionInput({
      inspectionId: "inspection_1",
      propertyType: "highRise",
      findings: [finding],
    })
  );
});

test("rejects a malformed finding entry", () => {
  assert.throws(() =>
    parseAnalyzeInspectionInput({
      inspectionId: "inspection_1",
      propertyType: "highRise",
      findings: ["not an object"],
    })
  );
});

test("clamps a negative/absurd evidenceCount rather than throwing", () => {
  const input = parseAnalyzeInspectionInput({
    inspectionId: "inspection_1",
    propertyType: "highRise",
    findings: [{...baseFinding("finding_1"), evidenceCount: -5}],
  });
  assert.equal(input.findings[0].evidenceCount, 0);
});

test("evidenceIds is optional and omitted when not provided", () => {
  const input = parseAnalyzeInspectionInput({
    inspectionId: "inspection_1",
    propertyType: "highRise",
    findings: [baseFinding("finding_1")],
  });
  assert.equal(input.findings[0].evidenceIds, undefined);
});

test("evidenceIds is accepted and passed through when valid", () => {
  const input = parseAnalyzeInspectionInput({
    inspectionId: "inspection_1",
    propertyType: "highRise",
    findings: [
      {...baseFinding("finding_1"), evidenceIds: ["evidence_1", "evidence_2"]},
    ],
  });
  assert.deepEqual(input.findings[0].evidenceIds, [
    "evidence_1",
    "evidence_2",
  ]);
});

test("evidenceIds rejects a non-array value", () => {
  assert.throws(() =>
    parseAnalyzeInspectionInput({
      inspectionId: "inspection_1",
      propertyType: "highRise",
      findings: [{...baseFinding("finding_1"), evidenceIds: "not-an-array"}],
    })
  );
});

test("evidenceIds rejects a non-string entry", () => {
  assert.throws(() =>
    parseAnalyzeInspectionInput({
      inspectionId: "inspection_1",
      propertyType: "highRise",
      findings: [{...baseFinding("finding_1"), evidenceIds: [123]}],
    })
  );
});

test("evidenceIds silently caps an excessive array at the per-finding " +
  "limit rather than rejecting the whole request", () => {
  const ids = Array.from(
    {length: MAX_EVIDENCE_IDS_PER_FINDING + 10},
    (_, i) => `evidence_${i}`
  );
  const input = parseAnalyzeInspectionInput({
    inspectionId: "inspection_1",
    propertyType: "highRise",
    findings: [{...baseFinding("finding_1"), evidenceIds: ids}],
  });
  assert.equal(
    input.findings[0].evidenceIds?.length,
    MAX_EVIDENCE_IDS_PER_FINDING
  );
});

test("evidenceIds drops duplicate ids within the same finding", () => {
  const input = parseAnalyzeInspectionInput({
    inspectionId: "inspection_1",
    propertyType: "highRise",
    findings: [
      {
        ...baseFinding("finding_1"),
        evidenceIds: ["evidence_1", "evidence_1", "evidence_2"],
      },
    ],
  });
  assert.deepEqual(input.findings[0].evidenceIds, [
    "evidence_1",
    "evidence_2",
  ]);
});
