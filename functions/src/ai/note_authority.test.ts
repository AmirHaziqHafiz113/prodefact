import assert from "node:assert/strict";
import {test} from "node:test";
import {buildCatalogueShortlist} from "./catalogue_shortlist";
import {defectCatalogue} from "./defect_catalogue";
import {validateAndNormalize} from "./gateway";
import {buildFindingContent, buildSystemPrompt, parseClassificationPayload}
  from "./prompt";
import {ClassificationResult, ClassifyFindingInput} from "./types";

/**
 * Inspector-note AUTHORITY (2026-10-12): a note that clearly names a
 * component locks the shortlist to it, so look-alike wording in other
 * components ("poor paint finishing on grill door") can never outrank
 * "wal por skim". Level A = component + defect, B = component only,
 * C = no reliable component (photo decides).
 */

const answer = (r: Partial<ClassificationResult>): ClassificationResult => ({
  findingId: "f",
  needsReview: false,
  ...r,
});

/**
 * @param {string} note the inspector note.
 * @return {ClassifyFindingInput} an input carrying its real shortlist.
 */
function shortlisted(note: string): ClassifyFindingInput {
  const base = {inspectionId: "i", findingId: "f", area: "Living Room",
    isPlumbingArea: false, note};
  const s = buildCatalogueShortlist(base);
  return {...base, shortlistEntryIds: s.entryIds,
    shortlistStrategy: s.strategy, strongNote: s.strongNote};
}

const WALL_SKIM = "wall.concrete_wall.03";
const componentsOf = (ids: string[]) => new Set(
  ids.map((id) => defectCatalogue.getById(id)!.componentName));
const elementsOf = (ids: string[]) => new Set(
  ids.map((id) => defectCatalogue.getById(id)!.mainElementName));

test("'wal por skim' in every spelling: Concrete Wall dominates, level A, " +
  "and no Door/Window entry is on the shortlist at all", () => {
  for (const note of ["Wal por skim", "wal poor skim", "wall por skim",
    "wall poor skim", "dinding por skim"]) {
    const s = shortlisted(note);
    assert.equal(s.strongNote!.level, "A", note);
    assert.deepEqual(s.strongNote!.lockComponentNames, ["Concrete Wall"],
      note);
    assert.equal(s.shortlistEntryIds![0], WALL_SKIM, note);
    assert.deepEqual([...elementsOf(s.shortlistEntryIds!)], ["Wall"], note);
    assert.deepEqual([...componentsOf(s.shortlistEntryIds!)],
      ["Concrete Wall"], note);
  }
});

test("level A: top-4 candidates after an uncertain model answer are the " +
  "note-derived wall entries, never door/window ones", () => {
  const r = validateAndNormalize(shortlisted("Wal por skim"),
    answer({needsReview: true, candidateEntryIds: []}));
  assert.equal(r.needsReview, true);
  assert.equal(r.candidateEntryIds![0], WALL_SKIM);
  assert.ok(r.candidateEntryIds!.length <= 4);
  assert.deepEqual([...elementsOf(r.candidateEntryIds!)], ["Wall"]);
});

test("level B: a component-only note locks the component; the model picks " +
  "within it", () => {
  for (const [note, element] of [["wall", "Wall"], ["window", "Window"]]) {
    const s = shortlisted(note);
    assert.equal(s.strongNote!.level, "B", note);
    assert.deepEqual([...elementsOf(s.shortlistEntryIds!)], [element], note);
  }
  const frame = shortlisted("door frame");
  assert.equal(frame.strongNote!.level, "B");
  assert.deepEqual([...componentsOf(frame.shortlistEntryIds!)],
    ["Door Frame"]);
  const sliding = shortlisted("sliding door");
  assert.equal(sliding.strongNote!.level, "B");
  assert.ok([...componentsOf(sliding.shortlistEntryIds!)]
    .every((c) => /sliding/i.test(c)));
});

test("component + defect notes: door frame dent, sliding door scratch, " +
  "floor tile hollow", () => {
  const dent = shortlisted("door frame dent");
  assert.deepEqual(dent.strongNote!.lockComponentNames, ["Door Frame"]);
  assert.deepEqual([...componentsOf(dent.shortlistEntryIds!)],
    ["Door Frame"]);
  const scratch = shortlisted("sliding door scratch");
  assert.ok(scratch.strongNote!.lockComponentNames.length > 0);
  assert.ok(scratch.strongNote!.lockComponentNames
    .every((c) => /sliding/i.test(c)));
  assert.ok([...componentsOf(scratch.shortlistEntryIds!)]
    .every((c) => /sliding/i.test(c)));
  const hollow = shortlisted("floor tile hollow");
  assert.deepEqual(hollow.strongNote!.lockComponentNames, ["Floor Tiles"]);
  assert.deepEqual([...componentsOf(hollow.shortlistEntryIds!)],
    ["Floor Tiles"]);
  assert.ok(/hollow/i.test(
    defectCatalogue.getById(hollow.shortlistEntryIds![0])!.defectDescription));
});

test("level C: shorthand without a component ('frem dent', 'holo tile') " +
  "stays unlocked and still surfaces the right wording", () => {
  const frem = shortlisted("frem dent");
  assert.equal(frem.strongNote!.level, "C");
  assert.deepEqual(frem.strongNote!.lockComponentIds, []);
  assert.ok(frem.shortlistEntryIds!.slice(0, 6).some((id) =>
    /frame/i.test(defectCatalogue.getById(id)!.componentName)));
  const holo = shortlisted("holo tile");
  assert.equal(holo.strongNote!.level, "C");
  assert.ok(holo.shortlistEntryIds!.slice(0, 8).some((id) =>
    /hollow/i.test(defectCatalogue.getById(id)!.defectDescription)));
  for (const note of ["crack", "stain", "damage"]) {
    assert.equal(shortlisted(note).strongNote!.level, "C", note);
  }
});

test("an uncatalogued part is never locked onto a look-alike element", () => {
  const s = shortlisted("floor trap crack");
  assert.equal(s.strongNote!.level, "C");
  assert.deepEqual(s.strongNote!.lockComponentIds, []);
});

test("contradiction: note says wall, photo says Door -> Needs Review with " +
  "noteImageAgreement=contradicts and both components named", () => {
  const r = validateAndNormalize(shortlisted("wall poor skim"), answer({
    catalogueEntryId: WALL_SKIM, confidence: 0.9, detectedComponent: "Door",
    detectedElement: "Door", noteImageAgreement: "supports"}));
  assert.equal(r.needsReview, true);
  assert.equal(r.needsReviewReason, "note_image_contradiction");
  assert.equal(r.noteImageAgreement, "contradicts");
  assert.equal(r.noteComponent, "Concrete Wall");
  assert.equal(r.imageComponent, "Door");
});

test("a Wall Tile photo does not contradict a 'wall' note (same element); " +
  "a Wall photo is accepted", () => {
  const ok = validateAndNormalize(shortlisted("wall poor skim"), answer({
    catalogueEntryId: WALL_SKIM, confidence: 0.9, detectedComponent: "Wall",
    noteImageAgreement: "supports"}));
  assert.equal(ok.needsReview, false);
  assert.equal(ok.catalogueEntryId, WALL_SKIM);
  assert.equal(ok.noteComponent, undefined);
  const tile = validateAndNormalize(shortlisted("wall poor skim"), answer({
    catalogueEntryId: WALL_SKIM, confidence: 0.9,
    detectedComponent: "Wall Tile", noteImageAgreement: "supports"}));
  assert.notEqual(tile.needsReviewReason, "note_image_contradiction");
});

test("a model pick outside the note's locked component is refused as a " +
  "component mismatch, never accepted", () => {
  const r = validateAndNormalize(shortlisted("wall poor skim"), answer({
    catalogueEntryId: "door.door_hinge.01", confidence: 0.95,
    noteImageAgreement: "supports"}));
  assert.equal(r.needsReview, true);
  assert.equal(r.needsReviewReason, "component_mismatch");
  assert.equal(r.catalogueEntryId, undefined);
  assert.deepEqual([...elementsOf(r.candidateEntryIds!)], ["Wall"]);
});

test("semantic interpretation fields are bounded, returned and never " +
  "replace the verbatim note", () => {
  const raw = parseClassificationPayload({
    normalizedIntent: "wall poor skim " + "x".repeat(500),
    noteComponentHint: "Concrete Wall", noteDefectHint: "poor skim",
    noteIntentConfidence: 7, catalogueEntryId: WALL_SKIM, confidence: 0.9,
    needsReview: false,
  }, "f");
  assert.equal(raw.noteComponentHint, "Concrete Wall");
  const r = validateAndNormalize(shortlisted("Wal por skim"), raw);
  assert.ok(r.normalizedIntent!.length <= 80);
  assert.equal(r.noteIntentConfidence, 1);
  assert.equal(r.noteDefectHint, "poor skim");
  const content = buildFindingContent(
    shortlisted("Wal por skim"),
    {findingId: "f", images: [], unavailableCount: 0});
  const text = (content[0] as {text: string}).text;
  assert.match(text, /inspector note \(PRIMARY, verbatim\): Wal por skim/);
  assert.match(text, /limited to it|LIMITED/);
});

test("the same single request asks the model to read the note " +
  "semantically (no second call, no extra provider)", () => {
  const prompt = buildSystemPrompt(
    shortlisted("Wal por skim").shortlistEntryIds!
      .map((id) => defectCatalogue.getById(id)!));
  assert.match(prompt, /READ THE NOTE SEMANTICALLY/);
  assert.match(prompt, /normalizedIntent/);
  assert.match(prompt, /noteIntentConfidence/);
});
