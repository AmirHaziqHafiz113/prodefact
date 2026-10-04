import {AiProvider} from "./provider";
import {ClassificationResult, ClassifyFindingInput} from "./types";
import {defectCatalogue} from "./defect_catalogue";
import {defectTermsFor, matchDefectTerm} from "./defect_terms";
import {DeepSeekProvider} from "./deepseek_provider";
import {OpenAiProvider} from "./openai_provider";
import {GeminiProvider} from "./gemini_provider";
import {AnthropicProvider} from "./anthropic_provider";

export type SupportedProviderId =
  | "deepseek"
  | "openai"
  | "gemini"
  | "anthropic";

export const DEFAULT_PROVIDER_ID: SupportedProviderId = "deepseek";

/** Maximum ranked alternative catalogue entries kept from a provider's
 * response — bounds the response size regardless of what a provider
 * sends. */
export const MAX_CANDIDATE_ENTRIES = 4;

/** Below this confidence a match is never auto-accepted: it goes to the
 * inspector as needsReview, with the entry kept as a candidate. */
export const MIN_CONFIDENT_CONFIDENCE = 0.6;

/** The only image-quality values a result may carry. */
export const QUALITY_ISSUES = [
  "blur",
  "too_dark",
  "overexposed",
  "subject_too_small",
  "obstructed",
  "insufficient_context",
  "unclear",
  "unrelated",
] as const;

/**
 * @param {unknown} value the model's qualityIssues.
 * @return {string[]} the controlled values it named, deduplicated.
 */
function controlledQualityIssues(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const allowed = new Set<string>(QUALITY_ISSUES);
  return dedupe(
    value
      .filter((v): v is string => typeof v === "string")
      .map((v) => v.trim().toLowerCase())
      .filter((v) => allowed.has(v))
  );
}

/** Whether the photo supports the note (controlled). */
export const NOTE_IMAGE_AGREEMENT = [
  "supports",
  "neutral",
  "contradicts",
  "unclear",
] as const;

/** Why a result needs the inspector (controlled; set server-side). */
export const NEEDS_REVIEW_REASONS = [
  "unrelated_image",
  "image_quality",
  "note_image_contradiction",
  "component_mismatch",
  "no_catalogue_match",
  "low_confidence",
  "ambiguous_candidates",
] as const;
export type NeedsReviewReason = typeof NEEDS_REVIEW_REASONS[number];

/** Model-written strings are bounded so they can't bloat storage, logs
 * or output tokens. */
const MAX_SHORT_REASON = 200;
const MAX_DETECTED = 60;

/**
 * @param {string} text a name.
 * @return {string[]} its significant, lightly stemmed words.
 */
function nameWords(text: string): string[] {
  return text
    .toLowerCase()
    .split(/[^a-z]+/)
    .filter((w) => w.length >= 2 && !["the", "of", "and", "a"].includes(w))
    .map((w) => (w.length > 3 && w.endsWith("s") ? w.slice(0, -1) : w));
}

/**
 * Whether what the model saw (a component or element name) is
 * consistent with the entry it chose: one name's words must be
 * contained in the other's ("Door" fits "Sliding Door Panel"; "Wall
 * Tile" does not fit "Window Frame", nor "Sliding Door Panel" fit
 * "Door Stopper").
 * @param {string} detected the model's detected component/element.
 * @param {string[]} names the chosen entry's component/element names.
 * @return {boolean} whether they agree.
 */
export function detectedMatches(detected: string, names: string[]): boolean {
  const seen = nameWords(detected);
  if (seen.length === 0) return true;
  return names.some((name) => {
    const target = nameWords(name);
    return seen.every((w) => target.includes(w)) ||
      target.every((w) => seen.includes(w));
  });
}

/** Splits an answer that names several ids at once ("a/b", "a or b"). */
const MULTI_ID_SEPARATOR = /\s*(?:\/|,|;|\||\bor\b|\band\b)\s*/i;

/**
 * Central, server-side provider selection. Flutter never sees or
 * chooses this — the callable function decides once, here.
 *
 * Swapping the active provider later means: implement the target
 * adapter's `classifyFinding` (see openai_provider.ts etc.), bind its
 * secret in index.ts, and change `AI_PROVIDER` (an environment
 * variable/function config value) — no change to the callable
 * function's request/response contract, and no change to Flutter.
 * @param {NodeJS.ProcessEnv} env the function's process environment.
 * @return {SupportedProviderId} the provider id to use.
 */
export function resolveProviderId(
  env: NodeJS.ProcessEnv
): SupportedProviderId {
  const configured = env.AI_PROVIDER?.trim().toLowerCase();
  if (
    configured === "deepseek" ||
    configured === "openai" ||
    configured === "gemini" ||
    configured === "anthropic"
  ) {
    return configured;
  }
  return DEFAULT_PROVIDER_ID;
}

/**
 * Constructs the adapter for one provider id.
 * @param {SupportedProviderId} providerId the provider to construct.
 * @param {string} apiKey that provider's API key.
 * @param {string} [model] the exact model id to request — required for
 *   `openai` (see `billing/pricing_config.ts`'s AI-level -> model
 *   mapping); ignored by providers with a single, fixed model.
 * @return {AiProvider} the constructed adapter.
 */
export function createProvider(
  providerId: SupportedProviderId,
  apiKey: string,
  model?: string
): AiProvider {
  switch (providerId) {
  case "deepseek":
    return new DeepSeekProvider(apiKey);
  case "openai":
    if (!model) {
      throw new Error("The OpenAI provider requires a model id.");
    }
    return new OpenAiProvider(apiKey, model);
  case "gemini":
    return new GeminiProvider(apiKey);
  case "anthropic":
    return new AnthropicProvider(apiKey);
  }
}

/**
 * Never trusts a provider's raw output. This is the single place a
 * catalogue id crosses from "the model said this" to "the app will
 * act on this" — anything that doesn't check out is dropped/coerced to
 * `needsReview` rather than propagated:
 *  - a response for the wrong findingId is rejected outright
 *  - `catalogueEntryId` must be a real, existing `DefectCatalogue`
 *    entry (see `defectCatalogue.isValidEntryId`) AND one of the ids
 *    this request was offered (`input.shortlistEntryIds`) — anything
 *    else is discarded, forcing `needsReview: true`
 *  - `isRelevantInspectionImage: false` (not an inspection photo) never
 *    carries an entry, term or candidates and is always needsReview
 *  - `candidateEntryIds` are filtered to valid ids only, deduplicated,
 *    and capped at [MAX_CANDIDATE_ENTRIES]
 *  - `confidence` is clamped to [0, 1]; below
 *    [MIN_CONFIDENT_CONFIDENCE] the result is needsReview
 *  - a combined answer ("a/b", "a or b") is never accepted; its valid
 *    ids become candidates
 *  - an entry that words several defects needs ONE valid `defectTerm`
 *    (see `defect_terms.ts`), otherwise needsReview
 *  - non-string/non-number fields are coerced to undefined rather than
 *    propagated
 *
 * The corrective action, defect description, and main element/
 * component names are never taken from the provider at all — the
 * caller resolves those separately from `catalogueEntryId` via
 * `defectCatalogue.getById`.
 * @param {ClassifyFindingInput} input the original request.
 * @param {ClassificationResult} result the provider's raw result.
 * @return {ClassificationResult} the validated, normalized result.
 */
export function validateAndNormalize(
  input: ClassifyFindingInput,
  result: ClassificationResult
): ClassificationResult {
  if (result.findingId !== input.findingId) {
    return {findingId: input.findingId, needsReview: true};
  }

  // A photo that isn't an inspection photo is never matched to the
  // catalogue — whatever else the answer says.
  const qualityIssues = controlledQualityIssues(result.qualityIssues);
  if (result.isRelevantInspectionImage === false) {
    return {
      findingId: input.findingId,
      isRelevantInspectionImage: false,
      imageUsable: false,
      qualityIssues: dedupe(["unrelated", ...qualityIssues]),
      confidence: clampConfidence(result.confidence),
      shortReason:
        bounded(result.shortReason, MAX_SHORT_REASON) ??
        "Image does not appear related to home inspection.",
      candidateEntryIds: [],
      needsReview: true,
      needsReviewReason: "unrelated_image",
    };
  }

  // Only the ids this request was offered (its shortlist) count as
  // valid — anything else is treated exactly like an unknown id.
  const shortlist = input.shortlistEntryIds ?
    new Set(input.shortlistEntryIds) :
    undefined;
  const isAllowed = (id: string) =>
    defectCatalogue.isValidEntryId(id) && (!shortlist || shortlist.has(id));

  const rawId =
    typeof result.catalogueEntryId === "string" ?
      result.catalogueEntryId.trim() :
      undefined;
  const validId =
    rawId !== undefined && isAllowed(rawId) ?
      rawId :
      undefined;
  // A combined answer ("a/b") is never one defect: its valid parts
  // become candidates for the inspector instead.
  const combinedIds =
    rawId !== undefined && validId === undefined ?
      rawId.split(MULTI_ID_SEPARATOR).filter(isAllowed) :
      [];

  const confidence = clampConfidence(result.confidence);

  const entry = validId ? defectCatalogue.getById(validId) : undefined;
  const allowedTerms = entry ? defectTermsFor(entry.defectDescription) : [];
  const defectTerm = entry ?
    matchDefectTerm(entry.defectDescription, result.defectTerm) :
    undefined;
  // An entry that words several defects needs the ONE term too;
  // without a valid one the finding isn't concrete yet.
  const missingTerm = allowedTerms.length > 0 && defectTerm === undefined;
  const lowConfidence =
    confidence !== undefined && confidence < MIN_CONFIDENT_CONFIDENCE;
  // Imperfect quality alone never rejects a classification (the note is
  // the primary evidence); only a photo the model says it could not
  // interpret at all sends the finding to the inspector.
  const imageUsable = result.imageUsable !== false;

  const detectedComponent = bounded(result.detectedComponent, MAX_DETECTED);
  const detectedElement = bounded(result.detectedElement, MAX_DETECTED);
  const noteImageAgreement = (NOTE_IMAGE_AGREEMENT as readonly string[])
    .includes(String(result.noteImageAgreement)) ?
    String(result.noteImageAgreement) :
    undefined;
  const contradicts = noteImageAgreement === "contradicts";
  // The chosen entry must be consistent with what the model itself
  // says the photo shows; a mismatch is never auto-accepted.
  const componentMismatch = entry !== undefined && (
    // A component is compared with the entry's component (a generic
    // "Door" still fits "Sliding Door Frame"); an element with its
    // element — never across, or "Door" would excuse any door part.
    (detectedComponent !== undefined &&
      !detectedMatches(detectedComponent, [entry.componentName])) ||
    (detectedComponent === undefined && detectedElement !== undefined &&
      !detectedMatches(detectedElement, [entry.mainElementName]))
  );

  const reason: NeedsReviewReason | undefined =
    !imageUsable ? "image_quality" :
      contradicts ? "note_image_contradiction" :
        componentMismatch ? "component_mismatch" :
          lowConfidence ? "low_confidence" :
            validId === undefined && combinedIds.length === 0 &&
              !hasValidCandidate(result, isAllowed) ? "no_catalogue_match" :
              validId === undefined || missingTerm ||
                result.needsReview === true ? "ambiguous_candidates" :
                undefined;
  const needsReview = reason !== undefined;

  // Uncertain should still be useful: up to 4 ranked catalogue options,
  // best first — the model's own pick, then its alternatives, then
  // (for a note that clearly pointed somewhere) the deterministic
  // shortlist ranking. Never invented text: only shortlisted ids.
  const modelCandidates = Array.isArray(result.candidateEntryIds) ?
    result.candidateEntryIds.filter(
      (id): id is string => typeof id === "string" && isAllowed(id)
    ) :
    [];
  const fallback = needsReview && input.shortlistStrategy === "noteMatch" ?
    (input.shortlistEntryIds ?? []) :
    [];
  const candidateEntryIds = dedupe([
    ...(needsReview && validId ? [validId] : []),
    ...combinedIds,
    ...modelCandidates,
    ...fallback,
  ]).slice(0, MAX_CANDIDATE_ENTRIES);

  return {
    findingId: input.findingId,
    isRelevantInspectionImage: true,
    imageUsable,
    qualityIssues,
    detectedElement,
    detectedComponent,
    noteImageAgreement,
    // An uncertain pick is still returned as the AI's best guess (the
    // inspector can Accept it in one tap); needsReview is what keeps it
    // from being accepted automatically.
    catalogueEntryId: validId,
    defectTerm,
    confidence,
    shortReason: bounded(result.shortReason, MAX_SHORT_REASON),
    candidateEntryIds,
    needsReview,
    needsReviewReason: reason,
  };
}

/**
 * @param {ClassificationResult} result the model's answer.
 * @param {Function} isAllowed whether an id may be used.
 * @return {boolean} whether any candidate it named is usable.
 */
function hasValidCandidate(
  result: ClassificationResult,
  isAllowed: (id: string) => boolean
): boolean {
  return Array.isArray(result.candidateEntryIds) &&
    result.candidateEntryIds.some((id) =>
      typeof id === "string" && isAllowed(id));
}

/**
 * @param {unknown} value a model-written string.
 * @param {number} max the length cap.
 * @return {string | undefined} it trimmed and capped, if non-empty.
 */
function bounded(value: unknown, max: number): string | undefined {
  const text = asOptionalString(value);
  return text === undefined ? undefined : text.slice(0, max);
}

/**
 * @param {unknown} value a candidate confidence.
 * @return {number | undefined} it clamped to [0, 1], if it was a number.
 */
function clampConfidence(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ?
    Math.min(1, Math.max(0, value)) :
    undefined;
}

/**
 * @param {string[]} ids a list of ids, possibly with duplicates.
 * @return {string[]} the same ids, first occurrence order, deduped.
 */
function dedupe(ids: string[]): string[] {
  return Array.from(new Set(ids));
}

/**
 * @param {unknown} value a candidate string field.
 * @return {string | undefined} the trimmed string, or undefined if
 *   it wasn't a non-empty string.
 */
function asOptionalString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0 ?
    value.trim() :
    undefined;
}
