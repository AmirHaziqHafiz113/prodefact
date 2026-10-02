import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {test} from "node:test";
import {
  buildFindingContent,
  buildSystemPrompt,
  parseClassificationPayload,
} from "./prompt";
import {validateAndNormalize} from "./gateway";
import {defectCatalogue} from "./defect_catalogue";
import {defectTermsFor} from "./defect_terms";
import {normalizeInspectorNote} from "./inspector_note";
import {ClassifyFindingInput, FindingImages} from "./types";

/**
 * AI accuracy contract (2026-10-02): the inspector's note is the
 * primary signal, the photo verifies it, and the answer is ONE
 * catalogue entry with ONE concrete defect — anything else is
 * needsReview.
 */

const WALL_TILE = "wall.wall_tile.04"; // "...damaged/chipped/hollow/..."
const input: ClassifyFindingInput = {
  inspectionId: "i1",
  findingId: "f1",
  area: "Kitchen",
  isPlumbingArea: false,
  note: "jubin holo",
};
const images: FindingImages = {
  findingId: "f1",
  unavailableCount: 0,
  images: [{evidenceId: "e1", mimeType: "image/jpeg", base64: "AAAA"}],
} as FindingImages;

/**
 * @return {string} the user-message text block.
 */
function userText(): string {
  return (buildFindingContent(input, images)[0] as {text: string}).text;
}

test("17 + 18. the note and the one photo are both sent", () => {
  const blocks = buildFindingContent(input, images);
  assert.match(userText(), /jubin holo/);
  const photos = blocks.filter((b) => b.type === "image_url");
  assert.equal(photos.length, 1);
});

test("19. the note is the primary signal: it comes before the area, and " +
  "the system prompt ranks it above the photo", () => {
  const text = userText();
  assert.ok(text.indexOf("inspector note (PRIMARY") < text.indexOf("area:"));
  const system = buildSystemPrompt();
  const priority = system.indexOf("EVIDENCE PRIORITY");
  assert.ok(priority >= 0);
  assert.ok(
    system.indexOf("note is the PRIMARY signal", priority) <
      system.indexOf("Use the photo to verify", priority)
  );
  assert.match(system, /clearly contradicts the note/);
  assert.match(system, /prefer the note/);
});

test("20 + 21. the original note is preserved; shorthand is read " +
  "internally only", () => {
  assert.match(userText(), /inspector note \(PRIMARY, verbatim\): jubin holo/);
  assert.match(userText(), /likely meaning: tile hollow/);
  for (const [note, expected] of [
    ["holo", "hollow"],
    ["tile kosong", "tile hollow"],
    ["frem", "frame"],
    ["win", "window"],
    ["bocor", "leak"],
    ["retak", "crack"],
  ]) {
    const n = normalizeInspectorNote(note);
    assert.equal(n.original, note);
    assert.equal(n.normalized, expected, note);
  }
});

test("22. one catalogue entry and one concrete term are kept", () => {
  const description = defectCatalogue.getById(WALL_TILE)!.defectDescription;
  assert.ok(defectTermsFor(description).includes("hollow"));
  const r = validateAndNormalize(input, {
    findingId: "f1",
    catalogueEntryId: WALL_TILE,
    defectTerm: "hollow",
    confidence: 0.85,
    needsReview: false,
  });
  assert.equal(r.catalogueEntryId, WALL_TILE);
  assert.equal(r.defectTerm, "hollow");
  assert.equal(r.needsReview, false);
});

test("23. combined answers are never accepted: two ids, or a " +
  "slash-separated term, become needsReview", () => {
  const twoIds = validateAndNormalize(input, {
    findingId: "f1",
    catalogueEntryId: `${WALL_TILE}/floor.floor_tiles.01`,
    confidence: 0.9,
    needsReview: false,
  });
  assert.equal(twoIds.needsReview, true);
  assert.equal(twoIds.catalogueEntryId, undefined);
  assert.deepEqual(twoIds.candidateEntryIds, [
    WALL_TILE,
    "floor.floor_tiles.01",
  ]);

  const twoTerms = validateAndNormalize(input, {
    findingId: "f1",
    catalogueEntryId: WALL_TILE,
    defectTerm: "chipped/hollow",
    confidence: 0.9,
    needsReview: false,
  });
  assert.equal(twoTerms.needsReview, true);
  assert.equal(twoTerms.defectTerm, undefined);

  const noTerm = validateAndNormalize(input, {
    findingId: "f1",
    catalogueEntryId: WALL_TILE,
    confidence: 0.9,
    needsReview: false,
  });
  assert.equal(noTerm.needsReview, true, "a multi-defect entry needs a term");
});

test("24. an invalid id is needsReview", () => {
  const r = validateAndNormalize(input, {
    findingId: "f1",
    catalogueEntryId: "wall.made_up.99",
    confidence: 0.99,
    needsReview: false,
  });
  assert.equal(r.needsReview, true);
  assert.equal(r.catalogueEntryId, undefined);
});

test("25. low confidence is needsReview, with the guess kept", () => {
  const r = validateAndNormalize(input, {
    findingId: "f1",
    catalogueEntryId: WALL_TILE,
    defectTerm: "hollow",
    confidence: 0.3,
    needsReview: false,
  });
  assert.equal(r.needsReview, true);
  assert.equal(r.catalogueEntryId, WALL_TILE);
});

test("an entry with a single defect needs no term", () => {
  const single = defectCatalogue.entries.find(
    (e) => defectTermsFor(e.defectDescription).length === 0
  )!;
  const r = validateAndNormalize(input, {
    findingId: "f1",
    catalogueEntryId: single.id,
    confidence: 0.8,
    needsReview: false,
  });
  assert.equal(r.needsReview, false);
  assert.equal(r.defectTerm, undefined);
});

test("the parser reads defectTerm; the system prompt lists terms and " +
  "forbids combining defects", () => {
  const parsed = parseClassificationPayload(
    {catalogueEntryId: WALL_TILE, defectTerm: "hollow", needsReview: false},
    "f1"
  );
  assert.equal(parsed.defectTerm, "hollow");
  const system = buildSystemPrompt();
  assert.match(system, /ONE CONCRETE DEFECT ONLY/);
  assert.match(system, /wall\.wall_tile\.04 \|.*\| terms: .*hollow/);
  assert.match(system, /"defectTerm"/);
});

test("every catalogue entry's terms match the fixture the Flutter app " +
  "is also pinned to", () => {
  const fixture = JSON.parse(
    readFileSync(
      join(__dirname, "..", "..", "src", "ai", "defect_terms.fixture.json"),
      "utf8"
    )
  ) as Record<string, string[]>;
  const actual: Record<string, string[]> = {};
  for (const e of defectCatalogue.entries) {
    const terms = defectTermsFor(e.defectDescription);
    if (terms.length) actual[e.id] = terms;
  }
  assert.deepEqual(actual, fixture);
  for (const [id, terms] of Object.entries(actual)) {
    const description = defectCatalogue.getById(id)!.defectDescription;
    for (const t of terms) {
      assert.ok(description.toLowerCase().includes(t), `${id}: ${t}`);
    }
  }
});
