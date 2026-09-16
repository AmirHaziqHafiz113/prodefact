import {AiProvider} from "./provider";
import {
  AnalyzeInspectionInput,
  AnalyzeInspectionResult,
  FindingSuggestion,
} from "./types";
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

/**
 * Central, server-side provider selection. Flutter never sees or
 * chooses this — the callable function decides once, here.
 *
 * Swapping the active provider later means: implement the target
 * adapter's `analyzeInspection` (see openai_provider.ts etc.), bind
 * its secret in index.ts, and change `AI_PROVIDER` (an environment
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
 * @return {AiProvider} the constructed adapter.
 */
export function createProvider(
  providerId: SupportedProviderId,
  apiKey: string
): AiProvider {
  switch (providerId) {
  case "deepseek":
    return new DeepSeekProvider(apiKey);
  case "openai":
    return new OpenAiProvider(apiKey);
  case "gemini":
    return new GeminiProvider(apiKey);
  case "anthropic":
    return new AnthropicProvider(apiKey);
  }
}

/**
 * Never trusts a provider's raw output. Rejects/normalizes:
 *  - a suggestion whose findingId wasn't in the request
 *  - a duplicate findingId (first occurrence wins)
 *  - non-string fields (coerced to undefined rather than throwing —
 *    one malformed field must not discard an otherwise-usable
 *    suggestion)
 *
 * A finding present in the request with no matching suggestion in
 * the (validated) result is simply absent from the output — callers
 * treat "no suggestion returned" the same as "provider omitted it".
 * @param {AnalyzeInspectionInput} input the original request.
 * @param {AnalyzeInspectionResult} result the provider's raw result.
 * @return {AnalyzeInspectionResult} the validated, normalized result.
 */
export function validateAndNormalize(
  input: AnalyzeInspectionInput,
  result: AnalyzeInspectionResult
): AnalyzeInspectionResult {
  const requestedIds = new Set(input.findings.map((f) => f.findingId));
  const seen = new Set<string>();
  const suggestions: FindingSuggestion[] = [];

  for (const raw of result.suggestions) {
    if (!raw || typeof raw.findingId !== "string") continue;
    if (!requestedIds.has(raw.findingId)) continue;
    if (seen.has(raw.findingId)) continue;
    seen.add(raw.findingId);

    suggestions.push({
      findingId: raw.findingId,
      suggestedElement: asOptionalString(raw.suggestedElement),
      suggestedComponent: asOptionalString(raw.suggestedComponent),
      defectType: asOptionalString(raw.defectType),
      recommendation: asOptionalString(raw.recommendation),
      notes: asOptionalString(raw.notes),
    });
  }

  return {providerId: result.providerId, suggestions};
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
