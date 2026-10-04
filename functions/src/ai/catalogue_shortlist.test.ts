import assert from "node:assert/strict";
import {test} from "node:test";
import {
  SHORTLIST_BROAD_MAX,
  SHORTLIST_MAX,
  SHORTLIST_MIN,
  buildCatalogueShortlist,
} from "./catalogue_shortlist";
import {defectCatalogue} from "./defect_catalogue";
import {validateAndNormalize} from "./gateway";
import {buildSystemPrompt, promptCatalogueFor} from "./prompt";
import {ClassifyFindingInput} from "./types";

/**
 * Deterministic catalogue shortlisting (2026-10-04): the model sees,
 * and may choose from, only the entries a finding's note and area
 * point to — never all 222 on a normal request.
 */

const input = (note: string | undefined, area = "Master Bathroom",
  isPlumbingArea = true): ClassifyFindingInput => ({
  inspectionId: "i1",
  findingId: "f1",
  area,
  isPlumbingArea,
  note,
});

test("2. \"holo wall tile\" puts every wall-tile entry first, then close " +
  "alternatives, within the target size", () => {
  const r = buildCatalogueShortlist(input("holo wall tile"));
  assert.equal(r.strategy, "noteMatch");
  assert.ok(r.entries.length >= SHORTLIST_MIN);
  assert.ok(r.entries.length <= SHORTLIST_MAX);
  const wallTile = defectCatalogue.entries
    .filter((e) => e.componentName === "Wall Tile")
    .map((e) => e.id);
  assert.deepEqual(r.entryIds.slice(0, wallTile.length).sort(),
    [...wallTile].sort());
  // Alternatives are kept, not excluded: e.g. a hollow floor tile.
  assert.ok(r.entries.some((e) => e.componentName === "Floor Tiles"));
});

test("shorthand and Malay are understood: \"win frem gap\" -> windows, " +
  "\"bocor\" -> plumbing/sanitary", () => {
  const win = buildCatalogueShortlist(input("win frem gap", "Bedroom 2",
    false));
  assert.equal(win.entries[0].componentName, "Window Frame");
  const leak = buildCatalogueShortlist(input("bocor", "Kitchen"));
  assert.ok(["Plumbing", "Sanitary Fitting"]
    .includes(leak.entries[0].mainElementName));
});

test("4. no note, or a vague one, gives a broader spread (never one " +
  "tiny category)", () => {
  for (const note of [undefined, "check this"]) {
    const r = buildCatalogueShortlist(input(note, "Master Bedroom", false));
    assert.equal(r.strategy, "areaContext");
    assert.ok(r.entries.length > SHORTLIST_MAX);
    assert.ok(r.entries.length <= SHORTLIST_BROAD_MAX);
    const elements = new Set(r.entries.map((e) => e.mainElementName));
    for (const e of ["Door", "Window", "Wall", "Floor", "Ceiling"]) {
      assert.ok(elements.has(e), e);
    }
  }
  const broad = buildCatalogueShortlist(input(undefined, "Unit", false));
  assert.equal(broad.strategy, "broad");
  assert.equal(broad.entries.length, SHORTLIST_BROAD_MAX);
  // Every component is represented.
  assert.equal(
    new Set(broad.entries.map((e) => e.componentId)).size,
    defectCatalogue.components.length
  );
});

test("the shortlist is deterministic and never the whole catalogue", () => {
  for (const [note, area] of [["holo wall tile", "Bathroom"],
    [undefined, "Kitchen"], ["xyz", "Nowhere"]] as const) {
    const a = buildCatalogueShortlist(input(note, area));
    const b = buildCatalogueShortlist(input(note, area));
    assert.deepEqual(a.entryIds, b.entryIds);
    assert.ok(a.entryIds.length < defectCatalogue.entries.length);
    assert.equal(a.totalCatalogueSize, defectCatalogue.entries.length);
  }
});

test("1. the system prompt lists the shortlist only", () => {
  const i = input("holo wall tile");
  const shortlist = buildCatalogueShortlist(i).entryIds;
  const system = buildSystemPrompt(promptCatalogueFor(i));
  const listed = defectCatalogue.entries.filter((e) =>
    system.includes(`${e.id} |`)).map((e) => e.id);
  assert.deepEqual(listed.sort(), [...shortlist].sort());
  assert.ok(listed.length < defectCatalogue.entries.length);
  assert.match(system, /isRelevantInspectionImage/);
});

test("3. controlled: an id the request was not offered is rejected like " +
  "an unknown one, and candidates are limited to the shortlist", () => {
  const i = {...input("holo wall tile"),
    shortlistEntryIds: buildCatalogueShortlist(input("holo wall tile"))
      .entryIds};
  const outside = defectCatalogue.entries.find((e) =>
    !i.shortlistEntryIds.includes(e.id))!.id;
  const r = validateAndNormalize(i, {
    findingId: "f1",
    catalogueEntryId: outside,
    confidence: 0.95,
    candidateEntryIds: [outside, "wall.wall_tile.04"],
    needsReview: false,
  });
  assert.equal(r.catalogueEntryId, undefined);
  assert.equal(r.needsReview, true);
  assert.deepEqual(r.candidateEntryIds, ["wall.wall_tile.04"]);
});

test("9. a valid in-shortlist answer is still accepted", () => {
  const i = {...input("holo wall tile"),
    shortlistEntryIds: buildCatalogueShortlist(input("holo wall tile"))
      .entryIds};
  const r = validateAndNormalize(i, {
    findingId: "f1",
    catalogueEntryId: "wall.wall_tile.04",
    defectTerm: "hollow",
    confidence: 0.9,
    needsReview: false,
  });
  assert.equal(r.catalogueEntryId, "wall.wall_tile.04");
  assert.equal(r.defectTerm, "hollow");
  assert.equal(r.needsReview, false);
  assert.equal(r.isRelevantInspectionImage, true);
});

test("5. an unrelated image is never matched to the catalogue, even if " +
  "the model also named an entry", () => {
  const r = validateAndNormalize(input("holo wall tile"), {
    findingId: "f1",
    isRelevantInspectionImage: false,
    catalogueEntryId: "wall.wall_tile.04",
    defectTerm: "hollow",
    confidence: 0.97,
    candidateEntryIds: ["wall.wall_tile.04"],
    needsReview: false,
  });
  assert.equal(r.isRelevantInspectionImage, false);
  assert.equal(r.catalogueEntryId, undefined);
  assert.equal(r.defectTerm, undefined);
  assert.deepEqual(r.candidateEntryIds, []);
  assert.equal(r.needsReview, true);
  assert.equal(r.confidence, 0.97);
  assert.match(r.shortReason!, /not appear related to home inspection/);
});
