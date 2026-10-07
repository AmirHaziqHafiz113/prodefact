import assert from "node:assert/strict";
import {test} from "node:test";
import {
  buildCatalogueShortlist,
  detectStrongNote,
} from "./catalogue_shortlist";
import {defectCatalogue} from "./defect_catalogue";
import {validateAndNormalize} from "./gateway";
import {normalizeInspectorNote} from "./inspector_note";
import {buildFindingContent, buildSystemPrompt} from "./prompt";
import {ClassificationResult, ClassifyFindingInput} from "./types";
import {parsePreviousAttempt} from "../billing/handle_analyse_finding";

/**
 * Strong-note anchoring (2026-10-07): a clear quick note ("poor paint",
 * "railing poor paint") pins the component and/or defect family down
 * deterministically, ahead of a vague image reading — and a part the
 * catalogue does not list is never forced onto a look-alike.
 */

const answer = (r: Partial<ClassificationResult>): ClassificationResult => ({
  findingId: "f",
  needsReview: false,
  ...r,
});

/**
 * @param {string} note the inspector note.
 * @param {number} [reanalysisAttempt] which Reanalyse this is.
 * @return {ClassifyFindingInput} an input carrying its real shortlist.
 */
function shortlisted(note: string, reanalysisAttempt = 0):
  ClassifyFindingInput {
  const base = {inspectionId: "i", findingId: "f", area: "Balcony",
    isPlumbingArea: false, note, reanalysisAttempt};
  const s = buildCatalogueShortlist(base);
  return {...base, shortlistEntryIds: s.entryIds,
    shortlistStrategy: s.strategy, strongNote: s.strongNote};
}

test("typo variants of 'poor paint' and 'railing' normalise", () => {
  for (const note of ["poor paint", "por paint", "poor peint",
    "por peint"]) {
    assert.match(normalizeInspectorNote(note).normalized, /poor paint/,
      note);
  }
  assert.match(normalizeInspectorNote("railng por peint").normalized,
    /railing poor paint/);
  assert.match(normalizeInspectorNote("poor paint railin").normalized,
    /railing/);
});

test("'poor paint' in any spelling pins the paint-finish family, every " +
  "entry of it is on the shortlist and leads it", () => {
  const family = defectCatalogue.entries
    .filter((e) => /poor (paint|skim\/paint)|poor painting/i
      .test(e.defectDescription)).map((e) => e.id);
  assert.ok(family.length >= 5);
  for (const note of ["poor paint", "por paint", "poor peint",
    "paint poor"]) {
    const s = shortlisted(note);
    assert.equal(s.strongNote!.matched, true, note);
    for (const id of family) {
      assert.ok(s.strongNote!.entryIds.includes(id) ||
        s.shortlistEntryIds!.includes(id), `${note}: ${id}`);
    }
    assert.ok(s.strongNote!.entryIds.every((id) =>
      /paint/i.test(defectCatalogue.getById(id)!.defectDescription)), note);
    const lead = s.shortlistEntryIds!.slice(0, s.strongNote!.entryIds.length);
    assert.deepEqual(lead, s.strongNote!.entryIds, note);
  }
});

test("component + defect in the note: component first, one entry", () => {
  const s = shortlisted("door frame por peint");
  assert.deepEqual(s.strongNote!.componentNames, ["Door Frame"]);
  assert.deepEqual(s.strongNote!.entryIds, ["door.door_frame.07"]);
  assert.equal(s.shortlistEntryIds![0], "door.door_frame.07");
  const frameIds = defectCatalogue.entries
    .filter((e) => e.componentName === "Door Frame").map((e) => e.id);
  for (const id of frameIds) assert.ok(s.shortlistEntryIds!.includes(id));

  const sliding = detectStrongNote("sliding door frame poor paint");
  assert.deepEqual(sliding.componentNames, ["Sliding Door Frame"]);
  assert.deepEqual(sliding.entryIds, ["door.sliding_door_frame.04"]);
});

test("a part the catalogue lacks (railing, floor trap) is detected, and " +
  "its words are not mistaken for defect wording", () => {
  const railing = shortlisted("railng por peint");
  assert.deepEqual(railing.strongNote!.unlistedTerms, ["railing"]);
  assert.deepEqual(railing.strongNote!.componentIds, []);
  assert.deepEqual(
    detectStrongNote(normalizeInspectorNote("flo trap blocked").normalized)
      .unlistedTerms, ["floor trap"]);
  assert.deepEqual(detectStrongNote("holo wall tile").unlistedTerms, []);
});

test("Reanalyse sends ONE request over a broader (capped) shortlist", () => {
  const first = shortlisted("door");
  const again = shortlisted("door", 1);
  assert.ok(first.shortlistEntryIds!.length <= 30);
  assert.ok(again.shortlistEntryIds!.length > first.shortlistEntryIds!.length);
  assert.ok(again.shortlistEntryIds!.length <= 60);
});

test("note anchoring: no usable model pick + a note that names exactly " +
  "one entry + a non-contradicting photo = that entry, accepted", () => {
  const r = validateAndNormalize(
    shortlisted("door frame poor paint"),
    answer({needsReview: true, detectedComponent: "Door Frame",
      noteImageAgreement: "neutral"}));
  assert.equal(r.catalogueEntryId, "door.door_frame.07");
  assert.equal(r.needsReview, false);
});

test("note anchoring never overrides a contradicting photo or an unlisted " +
  "part, and never replaces a pick the model made", () => {
  const input = shortlisted("door frame poor paint");
  const contradicted = validateAndNormalize(input, answer({
    needsReview: true, noteImageAgreement: "contradicts"}));
  assert.equal(contradicted.needsReview, true);
  assert.equal(contradicted.needsReviewReason, "note_image_contradiction");

  const otherComponent = validateAndNormalize(input, answer({
    needsReview: true, detectedComponent: "Wall Tile"}));
  assert.equal(otherComponent.needsReview, true);
  assert.equal(otherComponent.catalogueEntryId, undefined);
});

test("wrong confident answers are refused: the note names Door Frame, the " +
  "model picks Sliding Door Frame without saying the photo contradicts",
() => {
  const r = validateAndNormalize(
    shortlisted("door frame poor paint"),
    answer({catalogueEntryId: "door.sliding_door_frame.04",
      confidence: 0.95, noteImageAgreement: "supports"}));
  assert.equal(r.needsReview, true);
  assert.equal(r.needsReviewReason, "component_mismatch");
  assert.equal(r.candidateEntryIds![0], "door.door_frame.07");
});

test("railing: never forced onto a door; needsReview with no entry, " +
  "but the paint family stays available as candidates", () => {
  const input = shortlisted("railng por peint");
  const r = validateAndNormalize(input, answer({
    catalogueEntryId: "door.door_frame.07", confidence: 0.9,
    detectedComponent: "Door Frame"}));
  assert.equal(r.needsReview, true);
  assert.equal(r.needsReviewReason, "no_catalogue_match");
  assert.equal(r.catalogueEntryId, undefined);
  assert.ok(r.candidateEntryIds!.length > 0);
});

test("the reanalysis prompt is deliberate, structured and not 'pick " +
  "something else'", () => {
  const input: ClassifyFindingInput = {
    ...shortlisted("poor paint", 2),
    previousAttempt: {needsReviewReason: "component_mismatch",
      detectedComponent: "Door Frame", selectedEntryId: "door.door_frame.07"},
  };
  const text = buildFindingContent(input, {findingId: "f", images: [],
    unavailableCount: 0}).map((b) => b.type === "text" ? b.text : "")
    .join("\n");
  assert.match(text, /reanalysis attempt 2/);
  assert.match(text, /previous outcome: component_mismatch/);
  assert.match(text, /previously detected component: Door Frame/);
  assert.match(text, /Do not simply pick a different/);
  assert.doesNotMatch(text, /choose a different|pick another/i);

  const first = buildFindingContent(shortlisted("poor paint"), {
    findingId: "f", images: [], unavailableCount: 0})
    .map((b) => b.type === "text" ? b.text : "").join("\n");
  assert.doesNotMatch(first, /reanalysis attempt/);

  const system = buildSystemPrompt(defectCatalogue.entries.slice(0, 3));
  assert.match(system, /COMPONENT FIRST, DEFECT SECOND/);
});

test("previousAttempt is reduced to controlled values only", () => {
  assert.equal(parsePreviousAttempt(undefined), undefined);
  assert.equal(parsePreviousAttempt("x"), undefined);
  assert.equal(parsePreviousAttempt({needsReviewReason: "drop table",
    selectedEntryId: "not.an.id"}), undefined);
  assert.deepEqual(parsePreviousAttempt({
    needsReviewReason: "low_confidence",
    detectedComponent: "Door\nFrame" + "x".repeat(100),
    selectedEntryId: "door.door_frame.07",
    extra: "ignored",
  }), {
    needsReviewReason: "low_confidence",
    detectedComponent: ("Door Frame" + "x".repeat(100)).slice(0, 60),
    selectedEntryId: "door.door_frame.07",
  });
});
