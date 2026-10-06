import assert from "node:assert/strict";
import {test} from "node:test";
import {buildCatalogueShortlist} from "./catalogue_shortlist";
import {defectCatalogue} from "./defect_catalogue";
import {MAX_CANDIDATE_ENTRIES, validateAndNormalize} from "./gateway";
import {editDistance, normalizeInspectorNote} from "./inspector_note";
import {ClassificationResult, ClassifyFindingInput} from "./types";

/**
 * Note tolerance (typos, BM, English, rojak, shorthand), the accuracy
 * contract (consistency checks, controlled needs-review reasons) and
 * top-4 candidates (2026-10-04).
 */

const component = (id: string) => defectCatalogue.getById(id)!.componentName;

/**
 * @param {string} note the inspector note.
 * @param {string} area the area name.
 * @param {boolean} plumbing whether it is a plumbing area.
 * @return {ClassifyFindingInput} an input carrying its real shortlist.
 */
function shortlisted(note: string, area = "Living Room",
  plumbing = false): ClassifyFindingInput {
  const base = {inspectionId: "i", findingId: "f", area,
    isPlumbingArea: plumbing, note};
  const s = buildCatalogueShortlist(base);
  return {...base, shortlistEntryIds: s.entryIds,
    shortlistStrategy: s.strategy};
}

const answer = (r: Partial<ClassificationResult>): ClassificationResult => ({
  findingId: "f",
  needsReview: false,
  ...r,
});

test("typos and spelling variants are read deterministically; the " +
  "original note is never changed", () => {
  for (const [note, expected] of [
    ["holo wall tile", "hollow wall tile"],
    ["holow wall tile", "hollow wall tile"],
    ["wall tile hallow", "wall tile hollow"],
    ["crak wall", "crack wall"],
    ["craked tile", "cracked tile"],
    ["tilee holow", "tile hollow"],
    ["win frem gap", "window frame gap"],
    ["sliding dore", "sliding door"],
  ]) {
    const r = normalizeInspectorNote(note);
    assert.equal(r.original, note);
    assert.equal(r.normalized, expected, note);
  }
  assert.equal(normalizeInspectorNote("craked tile").strategy, "fuzzy");
  assert.equal(normalizeInspectorNote("holo wall tile").strategy, "alias");
  assert.equal(normalizeInspectorNote("Poor skim finish").strategy, "none");
  assert.equal(editDistance("holow", "hollow", 1), 1);
});

test("Malay and rojak notes are read as inspection English", () => {
  for (const [note, expected] of [
    ["jubin dinding kosong", "tile wall hollow"],
    ["retak dinding", "crack wall"],
    ["tingkap frame gap", "window frame gap"],
    ["tile dinding hollow", "tile wall hollow"],
    ["sliding dr senget", "sliding door not aligned slanted"],
    ["pintu sliding gap", "sliding door gap"],
    ["pintu gelongsor tak align", "sliding door not aligned"],
  ]) {
    assert.equal(normalizeInspectorNote(note).normalized, expected, note);
  }
});

test("each note variant surfaces the right component/defect family " +
  "first", () => {
  const cases: Array<[string, string, string, boolean]> = [
    ["holo wall tile", "wall.wall_tile.04", "Master Bathroom", true],
    ["holow wall tile", "wall.wall_tile.04", "Master Bathroom", true],
    ["jubin dinding kosong", "wall.wall_tile.04", "Master Bathroom", true],
    ["wall tile hallow", "wall.wall_tile.04", "Kitchen", true],
    ["crak wall", "wall.concrete_wall.01", "Living Room", false],
    ["retak dinding", "wall.concrete_wall.01", "Bedroom", false],
    ["win frem gap", "window.window_frame.01", "Bedroom", false],
    ["tingkap frame gap", "window.window_frame.01", "Bedroom", false],
    ["loose door handle", "door.door_knob_handle.01", "Bedroom", false],
    ["tombol pintu longgar", "door.door_knob_handle.01", "Bedroom", false],
    ["pintu sliding gap", "door.sliding_door_frame.01", "Balcony", false],
  ];
  for (const [note, expected, area, plumbing] of cases) {
    const r = buildCatalogueShortlist({note, area,
      isPlumbingArea: plumbing});
    const top = r.entries.slice(0, 8).map((e) => e.componentName);
    assert.ok(top.includes(component(expected)),
      `${note} -> ${top.join(", ")}`);
    assert.ok(r.entryIds.includes(expected), `${note} misses ${expected}`);
  }
  const sink = buildCatalogueShortlist({note: "bocor bawah sinki",
    area: "Kitchen", isPlumbingArea: true});
  assert.ok(["Plumbing", "Sanitary Fitting"]
    .includes(sink.entries[0].mainElementName));
  assert.ok(sink.entries.slice(0, 6).some((e) =>
    e.componentName === "Bottle Trap"));
});

test("a weak note (defect words only) broadens instead of narrowing", () => {
  const r = buildCatalogueShortlist({note: "gap", area: "Living Room",
    isPlumbingArea: false});
  assert.equal(r.strategy, "noteWeak");
  assert.ok(r.entries.length > 30);
  assert.ok(new Set(r.entries.map((e) => e.mainElementName)).size >= 4);
});

const SLIDING_NOTES: Record<string, string> = {
  "door.sliding_door_frame.01": "pintu sliding gap dinding",
  "door.sliding_door_frame.02": "sliding frame getah tertanggal",
  "door.sliding_door_frame.03": "sliding dr frame skru hilang",
  "door.sliding_door_frame.04": "sliding frame cat tak cantik paint",
  "door.sliding_door_frame.05": "sliding frame sompek",
  "door.sliding_door_frame.06": "sliding frame kotor stain",
  "door.sliding_door_frame.07": "sliding frame senget",
  "door.sliding_door_frame.08": "sliding frame karat",
  "door.sliding_door_glass.01": "glass door stain",
  "door.sliding_door_glass.02": "kaca sliding calar",
  "door.sliding_door_panel.01": "pintu gelongsor panel gap",
  "door.sliding_door_panel.02": "sliding panel rubber cover hilang",
  "door.sliding_door_panel.03": "sliding panel getah missing",
  "door.sliding_door_panel.04": "sliding panel poor paint",
  "door.sliding_door_panel.05": "sliding dr rosak",
  "door.sliding_door_panel.06": "sliding panel stain",
  "door.sliding_door_panel.07": "sliding panel tak align",
  "door.sliding_door_panel.08": "sliding dore tak berfungsi",
  "door.sliding_door_panel.09": "sliding panel berkarat",
  "door.sliding_door_panel.10": "sliding panel berbunyi bila buka",
};

test("sliding-door regression: every real sliding-door entry is reached " +
  "from a Malay/typo/shorthand note, and sliding doors lead", () => {
  const sliding = defectCatalogue.entries.filter((e) =>
    e.componentName.startsWith("Sliding Door"));
  assert.equal(sliding.length, 20);
  for (const entry of sliding) {
    const note = SLIDING_NOTES[entry.id];
    assert.ok(note, `a note for ${entry.id}`);
    const r = buildCatalogueShortlist({note, area: "Living Room",
      isPlumbingArea: false});
    assert.ok(r.entryIds.includes(entry.id), `${note} -> ${entry.id}`);
    for (const e of r.entries.slice(0, 5)) {
      assert.ok(e.componentName.startsWith("Sliding Door"),
        `${note}: ${e.componentName} ranked in the top 5`);
    }
  }
});

test("accuracy: correct component + defect is accepted", () => {
  const r = validateAndNormalize(shortlisted("pintu sliding gap"), answer({
    isRelevantInspectionImage: true,
    detectedElement: "Door",
    detectedComponent: "Sliding Door Frame",
    noteImageAgreement: "supports",
    catalogueEntryId: "door.sliding_door_frame.01",
    confidence: 0.88,
  }));
  assert.equal(r.needsReview, false);
  assert.equal(r.needsReviewReason, undefined);
  assert.equal(r.catalogueEntryId, "door.sliding_door_frame.01");
});

test("accuracy: a note-backed non-visual defect (hollow tile, photo " +
  "neutral) is accepted when confident", () => {
  const r = validateAndNormalize(shortlisted("holo wall tile",
    "Master Bathroom", true), answer({
    detectedComponent: "Wall Tile",
    noteImageAgreement: "neutral",
    catalogueEntryId: "wall.wall_tile.04",
    defectTerm: "hollow",
    confidence: 0.8,
  }));
  assert.equal(r.needsReview, false);
  assert.equal(r.defectTerm, "hollow");
});

test("accuracy: an image that contradicts the note is never auto-accepted",
  () => {
    const r = validateAndNormalize(shortlisted("holo wall tile",
      "Master Bathroom", true), answer({
      detectedComponent: "Wall Tile",
      noteImageAgreement: "contradicts",
      catalogueEntryId: "wall.wall_tile.04",
      defectTerm: "hollow",
      confidence: 0.9,
    }));
    assert.equal(r.needsReview, true);
    assert.equal(r.needsReviewReason, "note_image_contradiction");
    assert.equal(r.candidateEntryIds?.[0], "wall.wall_tile.04");
  });

test("accuracy: a chosen entry whose component contradicts what the model " +
  "saw is never auto-accepted", () => {
  const free = (detected: string, id: string) => validateAndNormalize(
    {inspectionId: "i", findingId: "f", area: "Living Room",
      isPlumbingArea: false},
    answer({detectedComponent: detected, catalogueEntryId: id,
      confidence: 0.95}));
  const windowFrame = defectCatalogue.entries.find((e) =>
    e.componentName === "Window Frame" &&
    !e.defectDescription.includes("/"))!.id;
  const stopper = defectCatalogue.entries.find((e) =>
    e.componentName === "Door Stopper" &&
    !e.defectDescription.includes("/"))!.id;
  for (const [detected, id] of [["Wall Tile", windowFrame],
    ["Sliding Door Panel", stopper]]) {
    const r = free(detected, id);
    assert.equal(r.needsReview, true, `${detected} vs ${id}`);
    assert.equal(r.needsReviewReason, "component_mismatch");
  }
  // A generic element name is consistent with a specific component.
  const ok = free("Door", "door.sliding_door_frame.01");
  assert.equal(ok.needsReview, false);
});

test("accuracy: low confidence, unrelated and poor images each get their " +
  "own controlled reason", () => {
  const input = shortlisted("sliding dr senget");
  const low = validateAndNormalize(input, answer({
    detectedComponent: "Sliding Door Panel",
    catalogueEntryId: "door.sliding_door_panel.07", confidence: 0.45}));
  assert.equal(low.needsReviewReason, "low_confidence");
  const unrelated = validateAndNormalize(input, answer({
    isRelevantInspectionImage: false, catalogueEntryId:
      "door.sliding_door_panel.07", confidence: 0.9}));
  assert.equal(unrelated.needsReviewReason, "unrelated_image");
  assert.deepEqual(unrelated.candidateEntryIds, []);
  const poor = validateAndNormalize(input, answer({
    imageUsable: false, qualityIssues: ["blur"],
    catalogueEntryId: "door.sliding_door_panel.07", confidence: 0.9}));
  assert.equal(poor.needsReviewReason, "image_quality");
});

test("weak note + strong image: a vague note still lets the model choose " +
  "the sliding door it clearly sees", () => {
  const input = shortlisted("rosak");
  assert.ok(input.shortlistEntryIds!.includes("door.sliding_door_panel.05"));
  const r = validateAndNormalize(input, answer({
    detectedComponent: "Sliding Door Panel",
    noteImageAgreement: "supports",
    catalogueEntryId: "door.sliding_door_panel.05",
    defectTerm: "damaged",
    confidence: 0.82,
  }));
  assert.equal(r.needsReview, false);
});

test("top 4: an uncertain answer still returns up to 4 ranked, valid " +
  "catalogue options — the model's pick first, then its alternatives",
() => {
  const input = shortlisted("sliding dr senget");
  const r = validateAndNormalize(input, answer({
    detectedComponent: "Sliding Door",
    catalogueEntryId: "door.sliding_door_panel.07",
    candidateEntryIds: ["door.sliding_door_frame.07", "made.up.99",
      "door.sliding_door_frame.01", "door.sliding_door_panel.08",
      "door.sliding_door_panel.05"],
    confidence: 0.5,
    needsReview: true,
  }));
  assert.equal(r.needsReview, true);
  assert.deepEqual(r.candidateEntryIds, [
    "door.sliding_door_panel.07",
    "door.sliding_door_frame.07",
    "door.sliding_door_frame.01",
    "door.sliding_door_panel.08",
  ]);
  assert.equal(r.candidateEntryIds!.length, MAX_CANDIDATE_ENTRIES);
  for (const id of r.candidateEntryIds!) {
    assert.ok(defectCatalogue.isValidEntryId(id));
  }
});

test("top 4: when the model gives no candidates, a clear note still " +
  "yields useful sliding-door options (never generic doors)", () => {
  const r = validateAndNormalize(shortlisted("sliding dr senget"), answer({
    needsReview: true, confidence: 0.3,
  }));
  assert.equal(r.needsReview, true);
  assert.equal(r.candidateEntryIds!.length, 4);
  for (const id of r.candidateEntryIds!) {
    assert.ok(component(id).startsWith("Sliding Door"), id);
  }
  assert.ok(r.candidateEntryIds!.includes("door.sliding_door_panel.07") ||
    r.candidateEntryIds!.includes("door.sliding_door_frame.07"));
});

test("model text is bounded: shortReason and detected names are capped",
  () => {
    const r = validateAndNormalize(shortlisted("holo wall tile"), answer({
      shortReason: "x".repeat(1000),
      detectedComponent: "y".repeat(500),
      noteImageAgreement: "maybe",
      catalogueEntryId: "wall.wall_tile.04",
      defectTerm: "hollow",
      confidence: 0.9,
    }));
    assert.equal(r.shortReason!.length, 200);
    assert.equal(r.detectedComponent!.length, 60);
    assert.equal(r.noteImageAgreement, undefined);
  });

test("real case: an ordinary Door Frame dent is never auto-accepted as a " +
  "Sliding Door Frame, while the genuine sliding entry still is", () => {
  const slidingFrame = "door.sliding_door_frame.01";
  const input = shortlisted("frame dented", "Master Bedroom");
  const wrong = validateAndNormalize(input, answer({
    detectedComponent: "Door Frame",
    catalogueEntryId: slidingFrame,
    confidence: 0.95,
  }));
  assert.equal(wrong.needsReview, true);
  assert.equal(wrong.needsReviewReason, "component_mismatch");

  const sliding = shortlisted("sliding door frame gap", "Balcony");
  assert.ok(sliding.shortlistEntryIds!.includes(slidingFrame));
  const right = validateAndNormalize(sliding, answer({
    detectedComponent: "Sliding Door Frame",
    catalogueEntryId: slidingFrame,
    confidence: 0.95,
  }));
  assert.equal(right.needsReview, false);
  assert.equal(right.catalogueEntryId, slidingFrame);
});

test("floor trap shorthand and BM are read as 'floor trap' (no AI call)",
  () => {
    for (const note of ["flo trap blocked", "perangkap lantai tersumbat"]) {
      const reading = normalizeInspectorNote(note).normalized;
      assert.ok(reading.includes("trap"), `${note} -> ${reading}`);
      assert.ok(/\bfloor\b/.test(reading), `${note} -> ${reading}`);
    }
  });
