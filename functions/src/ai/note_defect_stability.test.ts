import assert from "node:assert/strict";
import {test} from "node:test";
import {defectCatalogue} from "./defect_catalogue";
import {finalizeClassification, prepareClassification} from "./pipeline";
import {ClassificationResult, ClassifyFindingInput} from "./types";

const input = (note: string): ClassifyFindingInput => ({
  inspectionId: "i", findingId: "f", area: "Living Room",
  isPlumbingArea: false, note,
});

const ok = (over: Partial<ClassificationResult>): ClassificationResult => ({
  findingId: "f", isRelevantInspectionImage: true, imageUsable: true,
  needsReview: false, candidateEntryIds: [], ...over,
});

const NOTES = [
  {note: "wall poor skim", component: "Concrete Wall",
    element: "Wall"},
  {note: "Wal por skim", component: "Concrete Wall", element: "Wall"},
  {note: "door frame rusty", component: "Door Frame", element: "Door"},
];

// An in-lock entry the note does NOT spell out.
const neighbour = (note: string): string => {
  const p = prepareClassification(input(note));
  const family = new Set(p.shortlist.strongNote.entryIds);
  const id = p.shortlist.entryIds.find((e) => !family.has(e));
  assert.ok(id, `${note}: shortlist has an in-lock neighbour`);
  return id;
};

for (const {note, component, element} of NOTES) {
  const prepared = prepareClassification(input(note));
  const noteId = prepared.shortlist.strongNote.entryIds[0];
  const base = {detectedElement: element, detectedComponent: component};

  test(`${note}: level A, note-derived defect leads the shortlist`, () => {
    assert.equal(prepared.shortlist.strongNote.level, "A");
    assert.equal(prepared.shortlist.entryIds[0], noteId);
  });

  test(`${note}: provider agrees -> note defect accepted`, () => {
    const {normalized} = finalizeClassification(prepared, ok({
      ...base, catalogueEntryId: noteId, confidence: 0.85,
      noteImageAgreement: "supports",
    }));
    assert.equal(normalized.catalogueEntryId, noteId);
    assert.equal(normalized.needsReview, false);
  });

  test(`${note}: weak/ambiguous neighbour pick is held to the note's ` +
    "defect (stable, not review)", () => {
    const other = neighbour(note);
    for (const [agreement, confidence] of [
      ["supports", 0.95], ["supports", 0.7], ["neutral", 0.7],
      ["unclear", 0.5], ["neutral", 0.89],
    ] as const) {
      const {normalized, diagnostics} = finalizeClassification(
        prepared, ok({
          ...base, catalogueEntryId: other, confidence,
          noteImageAgreement: agreement,
        }));
      const label = `${agreement}/${confidence}`;
      assert.equal(normalized.catalogueEntryId, noteId, label);
      assert.equal(normalized.needsReview, false, label);
      assert.match(diagnostics.postProcessingDecision,
        /note_defect_held_over_provider/, label);
    }
  });

  test(`${note}: clearly contradicting neighbour -> Needs Review, ` +
    "never a silent switch", () => {
    const other = neighbour(note);
    for (const over of [
      {noteImageAgreement: "contradicts", confidence: 0.8},
      {noteImageAgreement: "neutral", confidence: 0.95},
    ]) {
      const {normalized} = finalizeClassification(prepared, ok({
        ...base, catalogueEntryId: other, ...over,
      }));
      assert.equal(normalized.needsReview, true);
      assert.equal(normalized.needsReviewReason, "note_image_contradiction");
      assert.notEqual(normalized.catalogueEntryId, other);
      assert.equal(normalized.catalogueEntryId, noteId);
      assert.ok(normalized.candidateEntryIds?.includes(other));
    }
  });

  test(`${note}: stays inside the locked component in every outcome`, () => {
    const other = neighbour(note);
    const {normalized} = finalizeClassification(prepared, ok({
      ...base, catalogueEntryId: other, confidence: 0.95,
      noteImageAgreement: "contradicts",
    }));
    for (const id of [normalized.catalogueEntryId,
      ...(normalized.candidateEntryIds ?? [])]) {
      if (id) {
        assert.equal(defectCatalogue.getById(id)?.componentName, component);
      }
    }
  });
}

test("a different building element is still a component contradiction", () => {
  const prepared = prepareClassification(input("wall poor skim"));
  const {normalized} = finalizeClassification(prepared, ok({
    catalogueEntryId: prepared.shortlist.strongNote.entryIds[0],
    confidence: 0.9, detectedElement: "Door", detectedComponent: "Door",
    noteImageAgreement: "supports",
  }));
  assert.equal(normalized.needsReview, true);
  assert.equal(normalized.needsReviewReason, "note_image_contradiction");
});

test("component-only note (level B, incl. 'door frame dent' which no " +
  "catalogue wording spells out): the model still chooses the defect",
() => {
  for (const note of ["door frame", "door frame dent"]) {
    const prepared = prepareClassification(input(note));
    assert.equal(prepared.shortlist.strongNote.level, "B", note);
    const pick = prepared.shortlist.entryIds[8];
    const {normalized} = finalizeClassification(prepared, ok({
      catalogueEntryId: pick, defectTerm: "chipped", confidence: 0.9,
      detectedElement: "Door", detectedComponent: "Door Frame",
      noteImageAgreement: "neutral",
    }));
    assert.equal(normalized.catalogueEntryId, pick, note);
    assert.equal(normalized.needsReview, false, note);
  }
});

test("no note: pure image-led behaviour is unchanged", () => {
  const prepared = prepareClassification({
    inspectionId: "i", findingId: "f", area: "Living Room",
    isPlumbingArea: false,
  });
  const pick = prepared.shortlist.entryIds[0];
  const {normalized} = finalizeClassification(prepared, ok({
    catalogueEntryId: pick, confidence: 0.9,
  }));
  assert.equal(normalized.catalogueEntryId, pick);
});
