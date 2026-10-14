import {
  buildDiagnostics,
  buildNoteFallback,
  ClassificationDiagnostics,
  prepareClassification,
  PreparedClassification,
} from "../ai/pipeline";
import {ClassifyFindingInput} from "../ai/types";
import {normalizeInspectorNote} from "../ai/inspector_note";
import {defectCatalogue} from "../ai/defect_catalogue";

/**
 * The deterministic half of the pipeline, for one note — NO provider
 * call. Uses the production `prepareClassification` (note
 * normalisation, strong-note detection, component lock, shortlist and
 * the prompt's catalogue listing).
 * @param {string} note the inspector's note.
 * @param {object} [options] the area context.
 * @param {string} [options.area] the area name.
 * @param {boolean} [options.isPlumbingArea] whether it is a plumbing area.
 * @return {object} the prepared state, diagnostics and fallback.
 */
export function analyseNote(
  note: string,
  options: {area?: string; isPlumbingArea?: boolean} = {}
) {
  const input: ClassifyFindingInput = {
    inspectionId: "qa",
    findingId: "qa-finding",
    area: options.area ?? "Living Room",
    isPlumbingArea: options.isPlumbingArea ?? false,
    note,
  };
  const prepared = prepareClassification(input);
  return {
    input,
    prepared,
    reading: normalizeInspectorNote(note),
    diagnostics: buildDiagnostics(prepared, undefined, undefined, note),
    fallback: buildNoteFallback(prepared),
  };
}

/**
 * @param {PreparedClassification} prepared the prepared state.
 * @return {string[]} one line per shortlist entry.
 */
function shortlistLines(prepared: PreparedClassification): string[] {
  return prepared.shortlist.entries.map((e, i) =>
    `  ${String(i + 1).padStart(2)}. ${e.id}  ${e.componentName} — ` +
    e.defectDescription.slice(0, 70));
}

/**
 * @param {object} a the analysis from `analyseNote`.
 * @return {string} the human-readable report.
 */
export function formatNoteReport(a: ReturnType<typeof analyseNote>): string {
  const d: ClassificationDiagnostics = a.diagnostics;
  const strong = a.prepared.shortlist.strongNote;
  const comps = d.shortlistComponents;
  const lines = [
    "--------------------------------------------------",
    "Raw note:",
    `  ${a.input.note}`,
    "",
    "Normalized:",
    `  ${a.reading.normalized}   (strategy: ${a.reading.strategy})`,
    "",
    "Level:",
    `  ${d.noteConfidenceLevel}` + ({
      A: "  (component + defect family)",
      B: "  (component only)",
      C: "  (no reliable component — the photo decides)",
    } as Record<string, string>)[d.noteConfidenceLevel],
    "",
    "Locked component:",
    `  ${d.lockedComponent.length ? d.lockedComponent.join(", ") : "none"}`,
  ];
  if (d.lockedElement.length) {
    lines.push("", "Locked element:", `  ${d.lockedElement.join(", ")}`);
  }
  lines.push(
    "",
    "Defect family:",
    `  ${d.defectFamily.length ? d.defectFamily.join(" | ") : "none"}`
  );
  if (strong.unlistedTerms.length) {
    lines.push("", "Uncatalogued part named:",
      `  ${strong.unlistedTerms.join(", ")} (never forced onto a look-alike)`);
  }
  lines.push(
    "",
    `Shortlist (${d.shortlistStrategy}, ${d.shortlistSize} entries):`,
    ...shortlistLines(a.prepared),
    "",
    "Unique shortlist components:",
    `  ${comps.join(", ")}`,
    "",
    "Cross-component candidates:",
    `  ${d.crossComponentCandidates}` +
      (d.lockedComponent.length === 0 ? "  (no lock — not applicable)" : ""),
    "",
    "AI-failure fallback (note-derived):",
    `  source: ${a.fallback.source}; candidates: ` +
      `${a.fallback.candidateEntryIds.length} ` +
      `(${a.fallback.likelyFromNoteCount} spelled out by the note)`,
    "--------------------------------------------------"
  );
  return lines.join("\n");
}

/**
 * @param {string} id a catalogue id.
 * @return {string} the entry's component name, or "?".
 */
export function componentOf(id: string | null | undefined): string {
  return id ? defectCatalogue.getById(id)?.componentName ?? "?" : "?";
}
