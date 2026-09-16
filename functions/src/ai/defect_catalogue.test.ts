import assert from "node:assert/strict";
import {test} from "node:test";
import {defectCatalogue} from "./defect_catalogue";

test("has the expected number of main elements/components/entries", () => {
  assert.equal(defectCatalogue.mainElements.length, 11);
  assert.equal(defectCatalogue.components.length, 34);
  assert.equal(defectCatalogue.entries.length, 222);
});

test("every entry id is unique", () => {
  const ids = new Set(defectCatalogue.entries.map((e) => e.id));
  assert.equal(ids.size, defectCatalogue.entries.length);
});

test("every entry belongs to a component that belongs to a main " +
  "element", () => {
  const mainElementIds = new Set(
    defectCatalogue.mainElements.map((m) => m.id)
  );
  const componentIds = new Set(defectCatalogue.components.map((c) => c.id));
  for (const entry of defectCatalogue.entries) {
    assert.ok(entry.componentId.startsWith(`${entry.mainElementId}.`));
    assert.ok(entry.defectId.startsWith(`${entry.componentId}.`));
    assert.ok(mainElementIds.has(entry.mainElementId));
    assert.ok(componentIds.has(entry.componentId));
  }
});

test("corrective action mapping is deterministic", () => {
  for (const entry of defectCatalogue.entries) {
    const resolved = defectCatalogue.getById(entry.id);
    assert.ok(resolved);
    assert.equal(resolved?.correctiveAction, entry.correctiveAction);
    assert.equal(resolved?.defectDescription, entry.defectDescription);
  }
});

test("no duplicate component ids", () => {
  const ids = new Set(defectCatalogue.components.map((c) => c.id));
  assert.equal(ids.size, defectCatalogue.components.length);
});

test("no duplicate main element ids", () => {
  const ids = new Set(defectCatalogue.mainElements.map((m) => m.id));
  assert.equal(ids.size, defectCatalogue.mainElements.length);
});

test("isValidEntryId rejects an unknown/hallucinated id — this is the " +
  "guard the callable relies on to reject an AI response referencing a " +
  "catalogue id that doesn't exist", () => {
  assert.equal(defectCatalogue.isValidEntryId("door.door_bell_switch.01"),
    true);
  assert.equal(defectCatalogue.isValidEntryId("made_up.entry.99"), false);
  assert.equal(defectCatalogue.isValidEntryId(""), false);
});

test("Furniture and Others exist with no components (preserved as " +
  "blank, not invented)", () => {
  const ids = defectCatalogue.mainElements.map((m) => m.id);
  assert.ok(ids.includes("furniture"));
  assert.ok(ids.includes("others"));
  assert.deepEqual(defectCatalogue.forMainElement("furniture"), []);
  assert.deepEqual(defectCatalogue.forMainElement("others"), []);
});

test("a defect with a genuinely blank source corrective action stays " +
  "null", () => {
  const entry = defectCatalogue.entries.find(
    (e) => e.defectDescription === "Missing shower head"
  );
  assert.ok(entry);
  assert.equal(entry?.correctiveAction, null);
});

test("forComponent scopes to that component only", () => {
  const entries = defectCatalogue.forComponent("door.door_bell_switch");
  assert.ok(entries.length > 0);
  assert.ok(entries.every((e) => e.componentId === "door.door_bell_switch"));
});
