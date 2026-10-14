import {LiveRun} from "./live";
import {componentOf} from "./note_report";

/**
 * @param {LiveRun} run one live run.
 * @param {string} note the note.
 * @return {string} the human-readable report (never the key or image).
 */
export function formatLiveReport(run: LiveRun, note: string): string {
  const d = run.diagnostics;
  const strong = run.prepared.shortlist.strongNote;
  const lines = [
    "RAW NOTE", `  ${note}`, "",
    "NORMALIZED NOTE",
    `  ${d?.normalizedNote ?? note}   ` +
      `(strategy: ${run.prepared.shortlist.normalizationStrategy})`, "",
    "NOTE LEVEL",
    `  ${strong.level}`, "",
    "LOCKED COMPONENT",
    `  ${strong.lockComponentNames.join(", ") || "none"}`, "",
    "SHORTLIST",
    `  ${run.prepared.shortlist.entryIds.length} entries — ` +
      `${(d?.shortlistComponents ??
        Array.from(new Set(run.prepared.shortlist.entries.map(
          (e) => e.componentName)))).join(", ")}`,
    `  prompt lists ${run.prepared.promptEntries.length} candidates; ` +
      `cross-component: ${d?.crossComponentCandidates ?? 0}`, "",
    "MODEL",
    `  ${run.model} (${run.level})   ${run.ms} ms` +
      (run.usage ? `   tokens in/out: ${run.usage.inputTokens}/` +
        `${run.usage.outputTokens}` : ""), "",
  ];
  if (run.providerError) {
    lines.push("PROVIDER FAILED", `  ${run.providerError}`, "",
      "NOTE-DERIVED FALLBACK (what the app shows instead)",
      `  source: ${run.fallback.source}; ` +
        `locked: ${run.fallback.lockedComponentNames.join(", ") || "none"}; ` +
        `${run.fallback.candidateEntryIds.length} candidates, all in the lock`);
    return lines.join("\n");
  }
  const raw = run.raw!;
  lines.push(
    "MODEL RESPONSE",
    `  normalizedIntent: ${raw.normalizedIntent ?? "-"}`,
    `  noteComponentHint: ${raw.noteComponentHint ?? "-"}`,
    `  noteDefectHint: ${raw.noteDefectHint ?? "-"}`,
    `  detectedElement / Component: ${raw.detectedElement ?? "-"} / ` +
      `${raw.detectedComponent ?? "-"}`,
    `  noteImageAgreement: ${raw.noteImageAgreement ?? "-"}`,
    `  selectedCatalogueId: ${raw.catalogueEntryId ?? "-"}` +
      (raw.catalogueEntryId ? ` (${componentOf(raw.catalogueEntryId)})` : ""),
    `  confidence: ${raw.confidence ?? "-"}   needsReview: ` +
      `${raw.needsReview}`,
    `  shortReason: ${raw.shortReason ?? "-"}`, "",
    "POST PROCESSING",
    `  ${d!.postProcessingDecision}` +
      (d!.providerEscapedLock ? "   [provider tried to leave the lock]" : ""),
    "",
    "FINAL RESULT"
  );
  const f = run.final!;
  lines.push(
    f.catalogueEntryId ?
      `  ${componentOf(f.catalogueEntryId)} — ${f.catalogueEntryId}` :
      "  (no catalogue pick)",
    `  needsReview: ${f.needsReview}` +
      (f.needsReviewReason ? ` (${f.needsReviewReason})` : ""),
    `  noteImageAgreement: ${f.noteImageAgreement ?? "-"}` +
      (f.noteComponent ? `   note: ${f.noteComponent}  image: ` +
        `${f.imageComponent}` : ""),
    `  candidates: ${(f.candidateEntryIds ?? []).map(
      (id) => `${id}[${componentOf(id)}]`).join(", ") || "none"}`
  );
  return lines.join("\n");
}

export interface BatchExpectation {
  expectedComponent?: string;
  expectedAgreement?: string;
  expectedNeedsReview?: boolean;
}

/**
 * The component a run ends up pointing at: the accepted entry's, else
 * (needs review) the first offered candidate's; "Needs Review" when
 * nothing component-specific is offered.
 * @param {LiveRun} run the run.
 * @return {string} the outcome label.
 */
export function outcomeLabel(run: LiveRun): string {
  if (run.providerError) return "Provider failed";
  const f = run.final!;
  if (f.noteImageAgreement === "contradicts") return "Contradicts";
  if (!f.needsReview && f.catalogueEntryId) {
    return componentOf(f.catalogueEntryId);
  }
  return "Needs Review";
}

/**
 * Whether one run meets the case's expectation.
 * @param {LiveRun} run the run.
 * @param {BatchExpectation} expected the expectation.
 * @return {boolean} pass/fail.
 */
export function meetsExpectation(
  run: LiveRun,
  expected: BatchExpectation
): boolean {
  if (run.providerError) return false;
  const f = run.final!;
  if (expected.expectedAgreement !== undefined) {
    // A contradiction must reach the inspector — never auto-accepted.
    return f.noteImageAgreement === expected.expectedAgreement &&
      f.needsReview === true;
  }
  if (expected.expectedComponent !== undefined) {
    const want = expected.expectedComponent.toLowerCase();
    const pick = f.catalogueEntryId ?
      componentOf(f.catalogueEntryId).toLowerCase() : undefined;
    const offered = (f.candidateEntryIds ?? []).map(
      (id) => componentOf(id).toLowerCase());
    // Accepted: it must be the expected component.
    if (!f.needsReview) return pick === want;
    // Needs review is fine ONLY if the note's component is respected:
    // nothing outside the expected component is picked or offered, and
    // something inside it is (so the inspector is never left with an
    // unrelated list).
    const inLock = (run.diagnostics?.lockedComponent ?? []).some(
      (c) => c.toLowerCase() === want);
    return (pick === undefined || pick === want) &&
      offered.every((c) => c === want) &&
      (offered.length > 0 || pick === want || inLock);
  }
  if (expected.expectedNeedsReview !== undefined) {
    return f.needsReview === expected.expectedNeedsReview;
  }
  return true;
}
