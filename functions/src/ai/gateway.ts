import {AiProvider} from "./provider";
import {ClassificationResult, ClassifyFindingInput} from "./types";
import {defectCatalogue} from "./defect_catalogue";
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
 *    entry (see `defectCatalogue.isValidEntryId`) — a hallucinated or
 *    unknown id is discarded, forcing `needsReview: true`
 *  - `candidateEntryIds` are filtered to valid ids only, deduplicated,
 *    and capped at [MAX_CANDIDATE_ENTRIES]
 *  - `confidence` is clamped to [0, 1]
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

  const catalogueEntryId =
    typeof result.catalogueEntryId === "string" &&
    defectCatalogue.isValidEntryId(result.catalogueEntryId) ?
      result.catalogueEntryId :
      undefined;

  const candidateEntryIds = Array.isArray(result.candidateEntryIds) ?
    dedupe(
      result.candidateEntryIds.filter(
        (id): id is string =>
          typeof id === "string" && defectCatalogue.isValidEntryId(id)
      )
    ).slice(0, MAX_CANDIDATE_ENTRIES) :
    [];

  const confidence =
    typeof result.confidence === "number" &&
    Number.isFinite(result.confidence) ?
      Math.min(1, Math.max(0, result.confidence)) :
      undefined;

  return {
    findingId: input.findingId,
    catalogueEntryId,
    confidence,
    shortReason: asOptionalString(result.shortReason),
    candidateEntryIds,
    needsReview: result.needsReview === true || catalogueEntryId === undefined,
  };
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
