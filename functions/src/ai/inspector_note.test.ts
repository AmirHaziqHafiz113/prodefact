import assert from "node:assert/strict";
import {test} from "node:test";
import {normalizeInspectorNote} from "./inspector_note";
import {defectCatalogue} from "./defect_catalogue";
import {buildFindingContent, buildSystemPrompt} from "./prompt";

test("QA #17 examples: holo, frem and win are read as hollow, frame, window",
  () => {
    assert.equal(normalizeInspectorNote("tile holo").normalized, "tile hollow");
    assert.equal(
      normalizeInspectorNote("win frem gap").normalized,
      "window frame gap"
    );
  });

test("Malay and mixed-language notes are expanded, including phrases",
  () => {
    assert.equal(
      normalizeInspectorNote("retak dinding").normalized,
      "crack wall"
    );
    assert.equal(
      normalizeInspectorNote("air bertakung at bilik air flr").normalized,
      "water ponding at bathroom floor"
    );
    assert.equal(
      normalizeInspectorNote("Jubin kosong, crak near dr").normalized,
      "tile hollow, crack near door"
    );
  });

test("the original note is preserved exactly; unknown words are untouched",
  () => {
    const note = normalizeInspectorNote("  Poor skim finish near DB box ");
    assert.equal(note.original, "Poor skim finish near DB box");
    assert.equal(note.normalized, "Poor skim finish near DB box");
    assert.deepEqual(note.expansions, []);

    const mixed = normalizeInspectorNote("Win frem gap!");
    assert.equal(mixed.original, "Win frem gap!");
    assert.deepEqual(
      mixed.expansions.map((e) => e.from),
      ["win", "frem"]
    );
  });

test("words that merely contain a shorthand token are not rewritten", () => {
  assert.equal(
    normalizeInspectorNote("window frame").normalized,
    "window frame"
  );
  assert.equal(normalizeInspectorNote("drain").normalized, "drain");
});

test("the prompt carries the verbatim note plus a separate likely " +
  "meaning, and the system prompt explains shorthand and BM/English", () => {
  const blocks = buildFindingContent(
    {
      inspectionId: "i1",
      findingId: "f1",
      area: "Kitchen",
      isPlumbingArea: false,
      note: "win frem gap",
    } as Parameters<typeof buildFindingContent>[0],
    {findingId: "f1", images: [], unavailableCount: 0}
  );
  const text = (blocks[0] as {text: string}).text;
  assert.match(text, /inspector note \(PRIMARY, verbatim\): win frem gap/);
  assert.match(text, /likely meaning: window frame gap/);

  const system = buildSystemPrompt(defectCatalogue.entries.slice(0, 3));
  assert.match(system, /shorthand/);
  assert.match(system, /Malay \(BM\)/);
  assert.match(system, /spelling/);
});

test("a note with nothing to expand gets no likely-meaning line", () => {
  const blocks = buildFindingContent(
    {
      inspectionId: "i1",
      findingId: "f1",
      area: "Kitchen",
      isPlumbingArea: false,
      note: "Poor skim finish",
    } as Parameters<typeof buildFindingContent>[0],
    {findingId: "f1", images: [], unavailableCount: 0}
  );
  const text = (blocks[0] as {text: string}).text;
  assert.match(text, /inspector note \(PRIMARY, verbatim\): Poor skim finish/);
  assert.doesNotMatch(text, /likely meaning/);
});
