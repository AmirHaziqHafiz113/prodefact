import assert from "node:assert/strict";
import {test} from "node:test";
import {
  MAX_EVIDENCE_IDS_PER_FINDING,
  MAX_TEXT_FIELD_LENGTH,
  parseClassifyFindingInput,
} from "./validation";

/**
 * @param {string} id the finding id.
 * @return {object} a minimal, valid finding payload.
 */
function basePayload(id = "finding_1") {
  return {
    inspectionId: "inspection_1",
    findingId: id,
    area: "Master Bathroom",
    isPlumbingArea: true,
  };
}

test("parses a well-formed payload", () => {
  const input = parseClassifyFindingInput(basePayload());
  assert.equal(input.inspectionId, "inspection_1");
  assert.equal(input.findingId, "finding_1");
  assert.equal(input.isPlumbingArea, true);
});

test("rejects a non-object payload", () => {
  assert.throws(() => parseClassifyFindingInput(null));
  assert.throws(() => parseClassifyFindingInput("not an object"));
});

test("rejects a missing findingId", () => {
  const payload = basePayload();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  delete (payload as any).findingId;
  assert.throws(() => parseClassifyFindingInput(payload));
});

test("rejects a missing inspectionId", () => {
  const payload = basePayload();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  delete (payload as any).inspectionId;
  assert.throws(() => parseClassifyFindingInput(payload));
});

test("rejects a missing area", () => {
  const payload = basePayload();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  delete (payload as any).area;
  assert.throws(() => parseClassifyFindingInput(payload));
});

test("rejects an excessively long note", () => {
  assert.throws(() =>
    parseClassifyFindingInput({
      ...basePayload(),
      note: "x".repeat(MAX_TEXT_FIELD_LENGTH + 1),
    })
  );
});

test("note is optional and omitted when not provided", () => {
  const input = parseClassifyFindingInput(basePayload());
  assert.equal(input.note, undefined);
});

test("evidenceIds is optional and omitted when not provided", () => {
  const input = parseClassifyFindingInput(basePayload());
  assert.equal(input.evidenceIds, undefined);
});

test("evidenceIds is accepted and passed through when valid", () => {
  const input = parseClassifyFindingInput({
    ...basePayload(),
    evidenceIds: ["evidence_1", "evidence_2"],
  });
  assert.deepEqual(input.evidenceIds, ["evidence_1", "evidence_2"]);
});

test("evidenceIds rejects a non-array value", () => {
  assert.throws(() =>
    parseClassifyFindingInput({...basePayload(), evidenceIds: "not-an-array"})
  );
});

test("evidenceIds rejects a non-string entry", () => {
  assert.throws(() =>
    parseClassifyFindingInput({...basePayload(), evidenceIds: [123]})
  );
});

test("evidenceIds silently caps an excessive array at the per-finding " +
  "limit rather than rejecting the whole request", () => {
  const ids = Array.from(
    {length: MAX_EVIDENCE_IDS_PER_FINDING + 10},
    (_, i) => `evidence_${i}`
  );
  const input = parseClassifyFindingInput({...basePayload(), evidenceIds: ids});
  assert.equal(input.evidenceIds?.length, MAX_EVIDENCE_IDS_PER_FINDING);
});

test("evidenceIds drops duplicate ids within the same finding", () => {
  const input = parseClassifyFindingInput({
    ...basePayload(),
    evidenceIds: ["evidence_1", "evidence_1", "evidence_2"],
  });
  assert.deepEqual(input.evidenceIds, ["evidence_1", "evidence_2"]);
});
