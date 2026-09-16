import assert from "node:assert/strict";
import {test} from "node:test";
import {
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
