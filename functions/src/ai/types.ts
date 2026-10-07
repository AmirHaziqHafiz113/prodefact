/**
 * Provider-neutral shapes shared by every AI provider adapter and the
 * gateway. Nothing provider-specific (DeepSeek/OpenAI/Gemini/Anthropic
 * request/response shapes) belongs here — only what the callable
 * function and Flutter agree on.
 *
 * Camera-first model: one callable invocation classifies exactly one
 * finding (its area context, optional inspector note, and photos)
 * against the controlled defect catalogue (`defect_catalogue.ts`) —
 * never a whole-session batch. See
 * `docs/ai_provider_architecture.md`.
 */

/** One finding's redacted context — no account/user data, ever. */
export interface ClassifyFindingInput {
  inspectionId: string;
  findingId: string;
  area: string;
  isPlumbingArea: boolean;
  /** The inspector's optional side note. */
  note?: string;
  /**
   * Ids only — never a Storage path, a URL, or bytes. The callable
   * resolves each id to an actual image itself, server-side, deriving
   * the Storage location from the authenticated caller's own uid and
   * this finding's ids (see `ai/evidence.ts`) — a client-supplied path
   * is never trusted or even accepted. Missing/unsynced/corrupted
   * evidence is skipped rather than failing the request.
   */
  evidenceIds?: string[];
  /**
   * Server-side only (never read from the client payload): the
   * catalogue entries this finding's request may choose from — see
   * `catalogue_shortlist.ts`. Set by the callable before the provider
   * is called; validation rejects any id outside it.
   */
  shortlistEntryIds?: string[];
  /** Which explicit inspector "Reanalyse" this request is (0 for the
   * first analysis). Analytics/logging only — never affects billing. */
  reanalysisAttempt?: number;
  /** Server-side only: how the shortlist was built (its order is only a
   * meaningful ranking for `noteMatch`). */
  shortlistStrategy?: string;
  /** Safe structured facts about the attempt an explicit Reanalyse is
   * replacing (validated server-side; never the note or prompt). */
  previousAttempt?: PreviousAttemptContext;
  /** Server-side only: what the note itself pins down (see
   * `catalogue_shortlist.ts`). */
  strongNote?: StrongNoteMatch;
}

/** What a Reanalyse request may say about the attempt it replaces. */
export interface PreviousAttemptContext {
  needsReviewReason?: string;
  detectedComponent?: string;
  selectedEntryId?: string;
}

/**
 * What the inspector's (normalised) note determines by itself, before
 * any photo is considered — computed deterministically.
 */
export interface StrongNoteMatch {
  /** The note names at least one defect (family) in the catalogue. */
  matched: boolean;
  /** Components whose full name the note mentions. */
  componentIds: string[];
  componentNames: string[];
  /** Entries whose wording the note fully covers (within the named
   * components when there are any). */
  entryIds: string[];
  /** Building parts the note names that the catalogue has no component
   * for (e.g. "railing"): such a finding is never forced onto a
   * look-alike component. */
  unlistedTerms: string[];
}

/** One evidence image, already downloaded, validated, and normalized
 * (see `ai/evidence.ts`) — ready to hand to a multimodal provider. */
export interface ResolvedImage {
  evidenceId: string;
  /** Always a normalized, re-encoded format — see `ai/evidence.ts`. */
  mimeType: "image/jpeg";
  base64: string;
}

/** The (possibly empty) set of successfully resolved images for one
 * finding, alongside how many were requested but could not be used —
 * partial evidence never fails the whole finding/request. */
export interface FindingImages {
  findingId: string;
  images: ResolvedImage[];
  /** Requested evidence ids that could not be resolved/decoded. */
  unavailableCount: number;
}

/**
 * One finding's classification result against the controlled defect
 * catalogue. `catalogueEntryId` is either a genuinely valid catalogue
 * id or absent/null — the gateway independently re-verifies this
 * before it's ever trusted, so a hallucinated id from the provider can
 * never reach the client. The corrective action, defect description,
 * and main element/component names are **never** provided by the
 * model directly; they're always resolved server-side from
 * `catalogueEntryId` via `defectCatalogue.getById`.
 */
export interface ClassificationResult {
  findingId: string;
  catalogueEntryId?: string;
  /** 0.0-1.0. */
  confidence?: number;
  /** A short, plain-language reason — not a technical paragraph. */
  shortReason?: string;
  /** Ranked alternative catalogue entry ids, when more than one match
   * was plausible. */
  candidateEntryIds?: string[];
  /** The ONE concrete defect within the chosen entry's wording, when
   * that wording lists several (e.g. "hollow" for "... damaged/chipped/
   * hollow/uneven"). Always one of `defectTermsFor(description)`. */
  defectTerm?: string;
  /** False when the photo is not meaningfully related to a home/
   * property inspection (a selfie, food, a screenshot, ...). Such a
   * result never carries a catalogue entry and is always needsReview.
   * Absent means relevant (older answers). */
  isRelevantInspectionImage?: boolean;
  /** False only when the photo genuinely prevents useful
   * interpretation (too blurry/dark/obstructed to tell anything). A
   * defect that simply isn't visible (a hollow tile, an intermittent
   * leak) does not make a photo unusable — the note carries that. */
  imageUsable?: boolean;
  /** Controlled values only — see `QUALITY_ISSUES` in gateway.ts. */
  qualityIssues?: string[];
  /** What the model saw in the photo (catalogue element/component name
   * where possible) — used for the consistency check, never shown in a
   * report. Bounded length. */
  detectedElement?: string;
  detectedComponent?: string;
  /** Whether the photo supports the note: supports | neutral |
   * contradicts | unclear. */
  noteImageAgreement?: string;
  /** Why a result needs the inspector (controlled — see
   * `NEEDS_REVIEW_REASONS` in gateway.ts). Set by the server only. */
  needsReviewReason?: string;
  /** True when the provider could not confidently classify this
   * finding at all. Always true if `catalogueEntryId` is absent. */
  needsReview: boolean;
}

/**
 * A provider's own reported token usage for one request — internal
 * only, used solely to compute the customer's Credits charge (see
 * `billing/pricing.ts`). Never forwarded to Flutter, never logged in
 * full; see `docs/commercial_model.md` ("Actual usage settlement").
 */
export interface ProviderUsage {
  inputTokens: number;
  outputTokens: number;
}

/** What a provider adapter actually returns — the classification plus
 * (when the provider reports it) the real usage billing needs. */
export interface ProviderClassification {
  result: ClassificationResult;
  usage?: ProviderUsage;
}
