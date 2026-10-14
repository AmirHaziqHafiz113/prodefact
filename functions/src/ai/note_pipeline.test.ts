import assert from "node:assert/strict";
import {test} from "node:test";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import sharp from "sharp";
import {defectCatalogue} from "./defect_catalogue";
import {
  buildNoteFallback,
  finalizeClassification,
  prepareClassification,
  safeDiagnostics,
} from "./pipeline";
import {buildFindingContent, buildSystemPrompt} from "./prompt";
import {ClassificationResult, ClassifyFindingInput} from "./types";
import {analyseNote, formatNoteReport} from "../qa/note_report";
import {runLiveCase} from "../qa/live";
import {meetsExpectation, outcomeLabel} from "../qa/live_report";

const input = (note: string): ClassifyFindingInput => ({
  inspectionId: "i", findingId: "f", area: "Living Room",
  isPlumbingArea: false, note,
});

const components = (note: string) => Array.from(new Set(
  prepareClassification(input(note)).shortlist.entries.map(
    (e) => e.componentName)));

// ---- Part 14: deterministic note authority -------------------------------

test("typo, clean English and Malay wall notes all lock to Concrete " +
  "Wall", () => {
  for (const note of ["Wal por skim", "wall poor skim", "dinding por skim"]) {
    const p = prepareClassification(input(note));
    assert.equal(p.shortlist.strongNote.level, "A", note);
    assert.deepEqual(p.shortlist.strongNote.lockComponentNames,
      ["Concrete Wall"], note);
    assert.deepEqual(components(note), ["Concrete Wall"], note);
    assert.equal(p.shortlist.entryIds[0], "wall.concrete_wall.03", note);
    assert.equal(p.promptEntries.length, p.shortlist.entryIds.length);
  }
});

test("door frame and sliding door notes lock to their own component", () => {
  assert.deepEqual(components("door frame dent"), ["Door Frame"]);
  assert.deepEqual(components("door frame"), ["Door Frame"]);
  const sliding = components("sliding door scratch");
  assert.ok(
    sliding.length > 0 && sliding.every((c) => /^Sliding Door/.test(c)),
    sliding.join());
  const floorTile = components("floor tile hollow");
  assert.deepEqual(floorTile, ["Floor Tiles"]);
});

test("an element-only note ('wall') locks the element's components", () => {
  const p = prepareClassification(input("wall"));
  assert.equal(p.shortlist.strongNote.level, "B");
  assert.deepEqual(new Set(components("wall")),
    new Set(["Concrete Wall", "Wall Tile"]));
});

test("an ambiguous note forces no component; 'frem dent' leads with Door " +
  "Frame without locking", () => {
  for (const note of ["crack", "frem dent"]) {
    const p = prepareClassification(input(note));
    assert.equal(p.shortlist.strongNote.level, "C", note);
    assert.deepEqual(p.shortlist.strongNote.lockComponentIds, [], note);
  }
  assert.equal(prepareClassification(input("frem dent")).shortlist
    .entries[0].componentName, "Door Frame");
  assert.ok(components("crack").length > 3, "no narrowing for 'crack'");
});

test("a locked shortlist never contains another component's entries", () => {
  for (const note of ["Wal por skim", "wall poor skim", "door frame dent",
    "door frame", "sliding door scratch", "floor tile hollow", "wall"]) {
    const a = analyseNote(note);
    assert.equal(a.diagnostics.crossComponentCandidates, 0, note);
  }
});

test("the provider prompt carries the verbatim note and lists ONLY the " +
  "locked component's ids", () => {
  const p = prepareClassification(input("wall poor skim"));
  const system = buildSystemPrompt(p.promptEntries);
  const listing = system.slice(
    system.lastIndexOf("CONTROLLED DEFECT CATALOGUE"));
  assert.ok(listing.includes("wall.concrete_wall.03"));
  assert.ok(!/\bdoor\.|\bwindow\.|\bfloor\./.test(listing),
    "no door/window/floor ids in the lock listing");
  const user = buildFindingContent(p.shortlistedInput,
    {findingId: "f", images: [], unavailableCount: 0});
  const text = user[0].type === "text" ? user[0].text : "";
  assert.ok(text.includes(
    "inspector note (PRIMARY, verbatim): wall poor skim"));
  assert.ok(text.includes("note names component: Concrete Wall"));
});

// ---- Part 15: AI-failure fallback is note-derived ------------------------

test("fallback for 'wall poor skim' is the note's component only", () => {
  const fb = buildNoteFallback(prepareClassification(input("wall poor skim")));
  assert.equal(fb.source, "note");
  assert.deepEqual(fb.lockedComponentNames, ["Concrete Wall"]);
  assert.equal(fb.candidateEntryIds[0], "wall.concrete_wall.03");
  assert.equal(fb.likelyFromNoteCount, 1);
  assert.ok(fb.candidateEntryIds.every(
    (id) => defectCatalogue.getById(id)?.componentName === "Concrete Wall"));
});

test("fallback for a component-only note ('door frame') is all Door Frame " +
  "entries; for an ambiguous note there is no note-derived fallback", () => {
  const fb = buildNoteFallback(prepareClassification(input("door frame")));
  assert.equal(fb.source, "note");
  assert.equal(fb.likelyFromNoteCount, 0);
  assert.ok(fb.candidateEntryIds.length > 1 && fb.candidateEntryIds.every(
    (id) => defectCatalogue.getById(id)?.componentName === "Door Frame"));
  assert.equal(
    buildNoteFallback(prepareClassification(input("crack"))).source, "none");
});

// ---- Part 16: contradiction / escape --------------------------------------

const ok = (over: Partial<ClassificationResult>): ClassificationResult => ({
  findingId: "f", isRelevantInspectionImage: true, imageUsable: true,
  needsReview: false, candidateEntryIds: [], ...over,
});

test("a door photo against a wall note contradicts and is never " +
  "auto-accepted — even when the model claims 'supports'", () => {
  const prepared = prepareClassification(input("wall poor skim"));
  for (const agreement of ["contradicts", "supports", "neutral"]) {
    const {normalized, diagnostics} = finalizeClassification(prepared, ok({
      catalogueEntryId: "wall.concrete_wall.03", confidence: 0.9,
      detectedElement: "Door", detectedComponent: "Door",
      noteImageAgreement: agreement,
    }));
    assert.equal(normalized.noteImageAgreement, "contradicts", agreement);
    assert.equal(normalized.needsReview, true, agreement);
    assert.equal(normalized.needsReviewReason, "note_image_contradiction");
    assert.equal(normalized.noteComponent, "Concrete Wall");
    assert.equal(normalized.imageComponent, "Door");
    assert.match(diagnostics.postProcessingDecision,
      /^needs_review:note_image_contradiction/);
  }
});

test("a provider pick outside the lock is discarded, never accepted", () => {
  const prepared = prepareClassification(input("wall poor skim"));
  const doorId = defectCatalogue.entries.find(
    (e) => e.componentName === "Door Frame")!.id;
  const {normalized, diagnostics} = finalizeClassification(prepared, ok({
    catalogueEntryId: doorId, confidence: 0.95,
    detectedElement: "Wall", detectedComponent: "Concrete Wall",
    noteImageAgreement: "supports",
  }));
  assert.equal(normalized.catalogueEntryId, undefined);
  assert.equal(normalized.needsReview, true);
  assert.equal(diagnostics.providerEscapedLock, true);
  assert.match(diagnostics.postProcessingDecision,
    /provider_pick_outside_shortlist_discarded/);
  assert.ok((normalized.candidateEntryIds ?? []).every(
    (id) => defectCatalogue.getById(id)?.componentName === "Concrete Wall"));
});

test("a supporting wall photo is accepted for the note's defect", () => {
  const prepared = prepareClassification(input("Wal por skim"));
  const {normalized, diagnostics} = finalizeClassification(prepared, ok({
    catalogueEntryId: "wall.concrete_wall.03", confidence: 0.9,
    detectedElement: "Wall", detectedComponent: "Concrete Wall",
    noteImageAgreement: "supports",
  }), "Wal por skim");
  assert.equal(normalized.catalogueEntryId, "wall.concrete_wall.03");
  assert.equal(normalized.needsReview, false);
  assert.equal(diagnostics.postProcessingDecision, "accepted");
  assert.equal(diagnostics.normalizedNote, "wall poor skim");
});

test("an ambiguous (neutral) photo with no model pick never overrides the " +
  "note: the note's own defect leads the offered candidates, all inside " +
  "the lock", () => {
  const prepared = prepareClassification(input("wall poor skim"));
  const {normalized} = finalizeClassification(prepared, ok({
    detectedElement: "Wall", detectedComponent: "Concrete Wall",
    noteImageAgreement: "neutral", needsReview: true,
  }));
  assert.equal(normalized.needsReview, true);
  assert.equal(normalized.noteImageAgreement, "neutral");
  assert.equal(normalized.candidateEntryIds![0], "wall.concrete_wall.03");
  assert.ok(normalized.candidateEntryIds!.every((id) =>
    defectCatalogue.getById(id)?.componentName === "Concrete Wall"));
});

test("production diagnostics never contain the note, its reading or " +
  "ids", () => {
  const a = analyseNote("wall poor skim");
  const safe = safeDiagnostics(a.diagnostics);
  const text = JSON.stringify(safe);
  assert.ok(!text.includes("wall poor skim"));
  assert.ok(!("rawNote" in safe) && !("normalizedNote" in safe));
  assert.equal(safe.shortlistCatalogueIdCount, 9);
});

// ---- the QA harness reuses the production chain ----------------------------

test("qa:note report shows the lock and zero cross-component candidates",
  () => {
    const report = formatNoteReport(analyseNote("Wal por skim"));
    assert.match(report, /Normalized:\n {2}wall poor skim/);
    assert.match(report, /Locked component:\n {2}Concrete Wall/);
    assert.match(report, /Unique shortlist components:\n {2}Concrete Wall\n/);
    assert.match(report, /Cross-component candidates:\n {2}0\n/);
  });

/**
 * @return {Promise<string>} a small valid JPEG on disk.
 */
async function tempImage(): Promise<string> {
  const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "pdqa-")),
    "x.jpg");
  fs.writeFileSync(file, await sharp({create: {width: 64, height: 64,
    channels: 3, background: "#cccccc"}}).jpeg().toBuffer());
  return file;
}

test("runLiveCase executes the production chain with an injected provider " +
  "and never needs a key", async () => {
  const imagePath = await tempImage();
  let seen: ClassifyFindingInput | undefined;
  const run = await runLiveCase(
    {note: "wall poor skim", imagePath, level: "smart"},
    () => ({
      classifyFinding: async (i) => {
        seen = i;
        return {result: ok({
          findingId: i.findingId,
          catalogueEntryId: "wall.concrete_wall.03", confidence: 0.9,
          detectedComponent: "Concrete Wall", noteImageAgreement: "supports",
        }), usage: {inputTokens: 1, outputTokens: 1}};
      },
    })
  );
  assert.deepEqual(seen?.shortlistEntryIds, run.prepared.shortlist.entryIds);
  assert.deepEqual(seen?.strongNote?.lockComponentNames, ["Concrete Wall"]);
  assert.equal(run.final?.catalogueEntryId, "wall.concrete_wall.03");
  assert.equal(outcomeLabel(run), "Concrete Wall");
  assert.equal(meetsExpectation(run, {expectedComponent: "Concrete Wall"}),
    true);
  assert.equal(meetsExpectation(run, {expectedComponent: "Door Frame"}),
    false);
});

test("a provider failure in the harness is reported with the note-derived " +
  "fallback, not a guess", async () => {
  const imagePath = await tempImage();
  const run = await runLiveCase(
    {note: "wall poor skim", imagePath, level: "fast"},
    () => ({classifyFinding: async () => {
      throw new Error("boom");
    }})
  );
  assert.equal(run.providerError, "boom");
  assert.equal(run.fallback.source, "note");
  assert.deepEqual(run.fallback.lockedComponentNames, ["Concrete Wall"]);
  assert.equal(outcomeLabel(run), "Provider failed");
});

test("batch expectations: contradiction must be needs-review; a component-" +
  "only note may end in needs-review only inside its component", async () => {
  const imagePath = await tempImage();
  const contradicting = await runLiveCase(
    {note: "wall poor skim", imagePath, level: "fast"},
    () => ({classifyFinding: async (i) => ({result: ok({
      findingId: i.findingId,
      detectedComponent: "Door", noteImageAgreement: "contradicts",
      needsReview: true, catalogueEntryId: "wall.concrete_wall.03",
    })})})
  );
  assert.equal(meetsExpectation(contradicting,
    {expectedAgreement: "contradicts"}), true);
  assert.equal(outcomeLabel(contradicting), "Contradicts");

  const componentOnly = await runLiveCase(
    {note: "door frame", imagePath, level: "fast"},
    () => ({classifyFinding: async (i) => ({result: ok({
      findingId: i.findingId,
      detectedComponent: "Door Frame", noteImageAgreement: "neutral",
      needsReview: true, confidence: 0,
      candidateEntryIds: ["door.door_frame.01", "door.door_frame.02"],
    })})})
  );
  assert.equal(meetsExpectation(componentOnly,
    {expectedComponent: "Door Frame"}), true);
  assert.equal(meetsExpectation(componentOnly,
    {expectedComponent: "Concrete Wall"}), false);
});

// ---- backend <-> on-device parity ------------------------------------------

test("the note reading matches the fixture the Flutter twin is pinned to",
  () => {
    const fixture = JSON.parse(fs.readFileSync(
      path.join(__dirname, "..", "..", "src", "ai", "note_intent.fixture.json"),
      "utf8")) as Record<string, {
      level: string; lockComponentNames: string[];
      leadEntryId: string | null; unlisted: string[];
    }>;
    for (const [note, expected] of Object.entries(fixture)) {
      const s = prepareClassification(input(note)).shortlist.strongNote;
      assert.deepEqual({
        level: s.level,
        lockComponentNames: [...s.lockComponentNames].sort(),
        leadEntryId: s.entryIds[0] ?? null,
        unlisted: [...s.unlistedTerms],
      }, expected, note);
    }
  });
