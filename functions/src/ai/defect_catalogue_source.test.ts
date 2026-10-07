import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {test} from "node:test";
import {defectCatalogue} from "./defect_catalogue";

/**
 * The active catalogue must equal the DEFECT LIST sheet of
 * DEFECT_REPORT_LIST.xlsx, snapshotted in tool/defect_list_source.json
 * (the Flutter test pins the same file, and that the Dart and TypeScript
 * copies are identical).
 */
interface Row {
  element: string;
  component: string;
  defect: string;
  action: string | null;
}
const source: {elements: string[]; entries: Row[]} = JSON.parse(
  readFileSync(
    join(__dirname, "..", "..", "..", "tool", "defect_list_source.json"),
    "utf8"
  )
);

/**
 * @param {string | null | undefined} s text to normalise.
 * @return {string} lower-cased text, collapsed spacing, "/" unpadded.
 */
function norm(s: string | null | undefined): string {
  return (s ?? "")
    .replace(/’/g, "'")
    .replace(/\s*\/\s*/g, "/")
    .replace(/\s+/g, " ")
    .trim()
    .toLowerCase();
}

// Typos/artefacts in the workbook itself that the catalogue does not copy.
const TYPO_DEFECTS = new Set([39]);
const TYPO_ACTIONS = new Set([113, 125]);
const TYPO_COMPONENTS = new Set([183, 184, 185, 186, 187, 188, 189]);

test("active catalogue: 11 elements, 34 components, 222 defects, in " +
  "the same order as the source sheet", () => {
  const {entries} = defectCatalogue;
  assert.equal(source.elements.length, 11);
  assert.equal(defectCatalogue.mainElements.length, 11);
  assert.equal(defectCatalogue.components.length, 34);
  assert.equal(entries.length, 222);
  assert.equal(source.entries.length, 222);
  source.entries.forEach((r, i) => {
    const e = entries[i];
    assert.equal(norm(e.mainElementName), norm(r.element), `row ${i}`);
    if (!TYPO_COMPONENTS.has(i)) {
      assert.equal(norm(e.componentName), norm(r.component), `row ${i}`);
    }
    if (!TYPO_DEFECTS.has(i)) {
      assert.equal(norm(e.defectDescription), norm(r.defect), `row ${i}`);
    }
    if (!TYPO_ACTIONS.has(i)) {
      assert.equal(norm(e.correctiveAction), norm(r.action), `row ${i}`);
    }
  });
});

test("no normalised duplicate element + component + defect", () => {
  const keys = new Set(defectCatalogue.entries.map((e) =>
    [e.mainElementName, e.componentName, e.defectDescription]
      .map(norm).join("|")));
  assert.equal(keys.size, defectCatalogue.entries.length);
});
