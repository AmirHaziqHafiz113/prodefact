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
export const MAX_CANDIDATE_ENTRIES = 5;

/** Below this confidence a match is never auto-accepted: it goes to the
 * inspector as needsReview, with the entry kept as a candidate. */
export const MIN_CONFIDENT_CONFIDENCE = 0.5;

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
  if (result.isRelevantInspectionImage === false) {
    return {
      findingId: input.findingId,
      isRelevantInspectionImage: false,
      confidence: clampConfidence(result.confidence),
      shortReason:
        asOptionalString(result.shortReason) ??
        "Image does not appear related to home inspection.",
      candidateEntryIds: [],
      needsReview: true,
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

  const needsReview =
    result.needsReview === true ||
    validId === undefined ||
    missingTerm ||
    lowConfidence;

  const candidateEntryIds = dedupe([
    ...combinedIds,
    ...(Array.isArray(result.candidateEntryIds) ?
      result.candidateEntryIds.filter(
        (id): id is string => typeof id === "string" && isAllowed(id)
      ) :
      []),
  ]).slice(0, MAX_CANDIDATE_ENTRIES);

  return {
    findingId: input.findingId,
    isRelevantInspectionImage: true,
    // An uncertain pick is still returned as the AI's best guess (the
    // inspector can Accept it in one tap); needsReview is what keeps it
    // from being accepted automatically.
    catalogueEntryId: validId,
    defectTerm,
    confidence,
    shortReason: asOptionalString(result.shortReason),
    candidateEntryIds,
    needsReview,
  };
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
