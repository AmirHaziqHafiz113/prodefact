import {DefectCatalogueEntry, defectCatalogue} from "./defect_catalogue";
import {
  buildCatalogueShortlist,
  CatalogueShortlist,
} from "./catalogue_shortlist";
import {validateAndNormalize} from "./gateway";
import {normalizeInspectorNote} from "./inspector_note";
import {promptCatalogueFor} from "./prompt";
import {ClassificationResult, ClassifyFindingInput} from "./types";

/**
 * The note -> shortlist -> (provider) -> post-processing chain, factored
 * out of `analyseFinding` so the production callable and the terminal QA
 * harness (`src/qa/`) execute EXACTLY the same code. The provider call
 * itself stays with the caller (production wraps it in billing,
 * reservation and logging; the harness calls the same provider adapter
 * directly) — everything deterministic on either side of it lives here.
 */

/** Everything decided BEFORE the provider is called. */
export interface PreparedClassification {
  shortlist: CatalogueShortlist;
  /** The input the provider receives (shortlist + strong note attached). */
  shortlistedInput: ClassifyFindingInput;
  /** The exact entries the prompt lists (what the model may choose). */
  promptEntries: DefectCatalogueEntry[];
}

/**
 * @param {ClassifyFindingInput} input the validated request.
 * @return {PreparedClassification} the deterministic pre-provider state.
 */
export function prepareClassification(
  input: ClassifyFindingInput
): PreparedClassification {
  const shortlist = buildCatalogueShortlist(input);
  const shortlistedInput: ClassifyFindingInput = {
    ...input,
    shortlistEntryIds: shortlist.entryIds,
    shortlistStrategy: shortlist.strategy,
    strongNote: shortlist.strongNote,
  };
  return {
    shortlist,
    shortlistedInput,
    promptEntries: promptCatalogueFor(shortlistedInput),
  };
}

/**
 * What to offer when the AI could not answer at all. Derived ONLY from
 * the note — never from an image — so a failure never replaces what the
 * inspector wrote with look-alike wording. With a locked component the
 * candidates are that component's entries (the note-spelled defect
 * first); with no lock there is nothing note-derived to offer and the
 * inspector searches the full catalogue.
 */
export interface NoteFallback {
  source: "note" | "none";
  noteLevel: "A" | "B" | "C";
  lockedComponentNames: string[];
  lockedElementNames: string[];
  /** Note-spelled defect entries first, then the rest of the locked
   * component(s) — all inside the lock, nothing else. */
  candidateEntryIds: string[];
  /** How many of those the note spells out (the "Likely from your note"
   * prefix of [candidateEntryIds]). */
  likelyFromNoteCount: number;
}

/**
 * @param {PreparedClassification} prepared the pre-provider state.
 * @return {NoteFallback} the note-derived fallback.
 */
export function buildNoteFallback(
  prepared: PreparedClassification
): NoteFallback {
  const strong = prepared.shortlist.strongNote;
  if (strong.lockComponentIds.length === 0) {
    return {
      source: "none",
      noteLevel: strong.level,
      lockedComponentNames: [],
      lockedElementNames: [],
      candidateEntryIds: [],
      likelyFromNoteCount: 0,
    };
  }
  const locked = new Set(strong.lockComponentIds);
  const lead = strong.entryIds.filter((id) => {
    const e = defectCatalogue.getById(id);
    return e !== undefined && locked.has(e.componentId);
  });
  const rest = defectCatalogue.entries
    .filter((e) => locked.has(e.componentId) && !lead.includes(e.id))
    .map((e) => e.id);
  return {
    source: "note",
    noteLevel: strong.level,
    lockedComponentNames: strong.lockComponentNames,
    lockedElementNames: strong.elementNames,
    candidateEntryIds: [...lead, ...rest],
    likelyFromNoteCount: lead.length,
  };
}

/** The structured trace of one classification (Part 7 of the QA brief). */
export interface ClassificationDiagnostics {
  /** Only present when the caller opts in (terminal QA). */
  rawNote?: string;
  normalizedNote?: string;
  normalizationStrategy: string;
  noteConfidenceLevel: "A" | "B" | "C";
  lockedComponent: string[];
  lockedElement: string[];
  /** The defect wording the note spells out (descriptions of its
   * note-matched entries), empty when it spells out none. */
  defectFamily: string[];
  shortlistStrategy: string;
  shortlistSize: number;
  shortlistCatalogueIds: string[];
  shortlistComponents: string[];
  /** Entries whose component is NOT locked although a lock exists (must
   * be 0 for a locked note). */
  crossComponentCandidates: number;
  promptCandidateCount: number;
  providerSelectedId: string | null;
  /** True when the provider named a catalogue id outside the lock. */
  providerEscapedLock: boolean;
  providerNormalizedIntent: string | null;
  providerNoteComponentHint: string | null;
  providerNoteDefectHint: string | null;
  imageComponent: string | null;
  noteComponent: string | null;
  noteImageAgreement: string | null;
  postProcessingDecision: string;
  finalCatalogueId: string | null;
  needsReview: boolean;
  needsReviewReason: string | null;
  fallbackSource: "note" | "none";
}

/**
 * @param {PreparedClassification} prepared the pre-provider state.
 * @param {ClassificationResult | undefined} raw the provider's result.
 * @param {ClassificationResult | undefined} final the post-processed one.
 * @param {string} [note] the verbatim note, only when opted in.
 * @return {ClassificationDiagnostics} the trace.
 */
export function buildDiagnostics(
  prepared: PreparedClassification,
  raw: ClassificationResult | undefined,
  final: ClassificationResult | undefined,
  note?: string
): ClassificationDiagnostics {
  const {shortlist} = prepared;
  const strong = shortlist.strongNote;
  const locked = new Set(strong.lockComponentIds);
  const entries = shortlist.entries;
  const rawId = typeof raw?.catalogueEntryId === "string" ?
    raw.catalogueEntryId.trim() : undefined;
  const rawEntry = rawId ? defectCatalogue.getById(rawId) : undefined;
  const escaped = rawEntry !== undefined && locked.size > 0 &&
    !locked.has(rawEntry.componentId);
  const inShortlist = rawId !== undefined &&
    shortlist.entryIds.includes(rawId);

  let decision = "no_provider_result";
  if (final) {
    decision = final.needsReview ?
      `needs_review:${final.needsReviewReason ?? "unspecified"}` :
      final.catalogueEntryId && rawId === undefined ?
        "accepted:anchored_by_note" :
        "accepted";
    if (rawId !== undefined && !inShortlist) {
      decision += rawEntry ?
        "|provider_pick_outside_shortlist_discarded" :
        "|provider_pick_not_in_catalogue_discarded";
    }
  }
  const reading = note ? normalizeInspectorNote(note) : undefined;
  return {
    rawNote: note,
    normalizedNote: reading?.normalized,
    normalizationStrategy: shortlist.normalizationStrategy,
    noteConfidenceLevel: strong.level,
    lockedComponent: strong.lockComponentNames,
    lockedElement: strong.elementNames,
    defectFamily: strong.entryIds.flatMap((id) => {
      const e = defectCatalogue.getById(id);
      return e ? [e.defectDescription] : [];
    }),
    shortlistStrategy: shortlist.strategy,
    shortlistSize: entries.length,
    shortlistCatalogueIds: shortlist.entryIds,
    shortlistComponents: Array.from(new Set(entries.map(
      (e) => e.componentName))),
    crossComponentCandidates: locked.size === 0 ? 0 :
      entries.filter((e) => !locked.has(e.componentId)).length,
    promptCandidateCount: prepared.promptEntries.length,
    providerSelectedId: rawId ?? null,
    providerEscapedLock: escaped,
    providerNormalizedIntent: raw?.normalizedIntent ?? null,
    providerNoteComponentHint: raw?.noteComponentHint ?? null,
    providerNoteDefectHint: raw?.noteDefectHint ?? null,
    imageComponent: final?.imageComponent ?? final?.detectedComponent ?? null,
    noteComponent: final?.noteComponent ?? null,
    noteImageAgreement: final?.noteImageAgreement ?? null,
    postProcessingDecision: decision,
    finalCatalogueId: final?.catalogueEntryId ?? null,
    needsReview: final?.needsReview ?? true,
    needsReviewReason: final?.needsReviewReason ?? null,
    fallbackSource: buildNoteFallback(prepared).source,
  };
}

/** Production-safe subset of the trace: ids, counts and component names
 * only — never the note, the image or the prompt. */
export type SafeDiagnostics = Omit<ClassificationDiagnostics,
  "rawNote" | "normalizedNote" | "defectFamily" | "shortlistCatalogueIds"> & {
  shortlistCatalogueIdCount: number;
};

/**
 * @param {ClassificationDiagnostics} d the full trace.
 * @return {SafeDiagnostics} the bounded production-log form.
 */
export function safeDiagnostics(d: ClassificationDiagnostics): SafeDiagnostics {
  /* eslint-disable @typescript-eslint/no-unused-vars */
  const {
    rawNote, normalizedNote, defectFamily, shortlistCatalogueIds, ...rest
  } = d;
  /* eslint-enable @typescript-eslint/no-unused-vars */
  return {...rest, shortlistCatalogueIdCount: shortlistCatalogueIds.length};
}

/**
 * Post-processes the provider's raw answer with the production
 * validator and returns it alongside the diagnostic trace.
 * @param {PreparedClassification} prepared the pre-provider state.
 * @param {ClassificationResult} raw the provider's raw result.
 * @param {string} [note] the verbatim note, only when opted in.
 * @return {object} the validated result and the trace.
 */
export function finalizeClassification(
  prepared: PreparedClassification,
  raw: ClassificationResult,
  note?: string
): {normalized: ClassificationResult; diagnostics: ClassificationDiagnostics} {
  const normalized = validateAndNormalize(prepared.shortlistedInput, raw);
  return {normalized, diagnostics: buildDiagnostics(
    prepared, raw, normalized, note)};
}
