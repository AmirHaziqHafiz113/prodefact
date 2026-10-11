import {AiLevelConfig, PricingConfig} from "./pricing_config";
import {AiLevel} from "./types";
import {TOKENS_PER_MYR, tokensForTopUpMyr} from "./tokens";
import {
  ANALYSE_FINDING_FIRESTORE_OPS,
  ANALYSE_FINDING_WORST_CASE,
  OperationCost,
  OperationUsage,
  computeOperationCost,
} from "./usage_cost";

/**
 * Pure pricing math — no I/O, trivially unit-testable. This is the one
 * place usage becomes customer-facing ProDefact Tokens, via the
 * variable-cost model in `usage_cost.ts`: Tokens = (OpenAI cost +
 * infrastructure cost) × markup × 1,000,000 per RM. See
 * docs/token_billing.md.
 */

/**
 * @param {number} inputTokens provider tokens sent.
 * @param {number} outputTokens provider tokens returned.
 * @param {AiLevelConfig} levelConfig that level's provider cost rates.
 * @return {number} the raw provider cost, in USD.
 */
export function providerCostForTokensUsd(
  inputTokens: number,
  outputTokens: number,
  levelConfig: AiLevelConfig
): number {
  return (
    (inputTokens / 1000) * levelConfig.providerCostPerKInputTokensUsd +
    (outputTokens / 1000) * levelConfig.providerCostPerKOutputTokensUsd
  );
}

/**
 * @param {OperationUsage} usage what an operation consumed.
 * @param {PricingConfig} config the live pricing config.
 * @return {OperationCost} its auditable cost and Token price.
 */
export function priceUsage(
  usage: OperationUsage,
  config: PricingConfig
): OperationCost {
  return computeOperationCost(usage, {
    rates: config.infrastructureRates,
    usdToMyrRate: config.usdToMyrRate,
    markupMultiplier: config.markupMultiplier,
  });
}

/**
 * The worst-case usage of one AI analysis at [aiLevel] — the level's
 * conservative provider-token estimate plus the per-analysis
 * infrastructure worst case.
 * @param {AiLevel} aiLevel the selected level.
 * @param {PricingConfig} config the live pricing config.
 * @return {OperationUsage} the worst-case usage.
 */
export function worstCaseAnalysisUsage(
  aiLevel: AiLevel,
  config: PricingConfig
): OperationUsage {
  const level = config.aiLevels[aiLevel];
  return {
    openaiModel: level.model,
    openaiInputTokens: level.estimatedInputTokens,
    openaiOutputTokens: level.estimatedOutputTokens,
    openaiInputPerKUsd: level.providerCostPerKInputTokensUsd,
    openaiOutputPerKUsd: level.providerCostPerKOutputTokensUsd,
    storageDownloadBytes: ANALYSE_FINDING_WORST_CASE.storageDownloadBytes,
    storageRetainedBytes: ANALYSE_FINDING_WORST_CASE.storageRetainedBytes,
    firestoreReads: ANALYSE_FINDING_FIRESTORE_OPS.reads,
    firestoreWrites: ANALYSE_FINDING_FIRESTORE_OPS.writes,
    firestoreDeletes: ANALYSE_FINDING_FIRESTORE_OPS.deletes,
    functionInvocations: 1,
    functionDurationMs: ANALYSE_FINDING_WORST_CASE.functionDurationMs,
    networkBytes: ANALYSE_FINDING_WORST_CASE.networkBytes,
    imagesProcessed: ANALYSE_FINDING_WORST_CASE.imagesProcessed,
  };
}

/**
 * The "up to N Tokens" figure shown before AI analysis runs —
 * deliberately a ceiling, never the (unknowable in advance) exact
 * charge. Also the amount reserved.
 * @param {AiLevel} aiLevel the selected level.
 * @param {PricingConfig} config the live pricing config.
 * @return {number} the maximum Tokens this analysis could cost.
 */
export function estimateMaxTokens(
  aiLevel: AiLevel,
  config: PricingConfig
): number {
  return priceUsage(worstCaseAnalysisUsage(aiLevel, config), config)
    .tokensCharged;
}

/**
 * The real usage of one AI analysis — provider-reported tokens and
 * measured bytes/time, with deterministic Firestore/network estimates.
 * @param {object} params the observed facts.
 * @param {PricingConfig} config the live pricing config.
 * @return {OperationUsage} the usage, with its measurement labels.
 */
export function actualAnalysisUsage(
  params: {
    aiLevel: AiLevel;
    providerUsage?: {inputTokens: number; outputTokens: number};
    imageBytes: number;
    imageCount: number;
    functionDurationMs: number;
  },
  config: PricingConfig
): OperationUsage {
  const level = config.aiLevels[params.aiLevel];
  return {
    openaiModel: level.model,
    openaiInputTokens: params.providerUsage?.inputTokens,
    openaiOutputTokens: params.providerUsage?.outputTokens,
    openaiInputPerKUsd: level.providerCostPerKInputTokensUsd,
    openaiOutputPerKUsd: level.providerCostPerKOutputTokensUsd,
    storageDownloadBytes: params.imageBytes,
    // The photo's operational copy stays in Storage; Drive holds the
    // long-term original. One month of retention is charged once.
    storageRetainedBytes: params.imageBytes,
    firestoreReads: ANALYSE_FINDING_FIRESTORE_OPS.reads,
    firestoreWrites: ANALYSE_FINDING_FIRESTORE_OPS.writes,
    firestoreDeletes: ANALYSE_FINDING_FIRESTORE_OPS.deletes,
    functionInvocations: 1,
    functionDurationMs: params.functionDurationMs,
    // Images travel base64-encoded (~4/3 their size) to the provider.
    networkBytes: Math.round(params.imageBytes * 4 / 3),
    imagesProcessed: params.imageCount,
    measurement: {
      openai: params.providerUsage ? "measured" : "unavailable",
      storageDownload: "measured",
      storageRetained: "estimated",
      firestore: "estimated",
      functionDuration: "measured",
      network: "estimated",
      overhead: "estimated",
    },
  };
}

/**
 * @param {number} tokens a Token amount.
 * @return {number} its RM retail value, for display only.
 */
export function tokensToMyr(tokens: number): number {
  return tokens / TOKENS_PER_MYR;
}

/**
 * @param {number} myr a Ringgit amount (e.g. a top-up package price).
 * @return {number} the whole number of Tokens it buys (RM10 →
 *   10,000,000).
 */
export function myrToTokens(myr: number): number {
  return tokensForTopUpMyr(myr);
}

/**
 * The extra Tokens required when a House Pass's included AI level is
 * lower than the one the inspector selected — e.g. a pass including
 * `smart` but the inspector picks `expert`. 0 when the selected level
 * is the included level or "lower" in the fixed ranking
 * fast < smart < expert.
 * @param {AiLevel} selectedLevel the level the inspector picked.
 * @param {AiLevel} includedLevel the House Pass's included level.
 * @param {PricingConfig} config the live pricing config.
 * @return {number} the surcharge, in Tokens.
 */
export function housePassSurchargeTokens(
  selectedLevel: AiLevel,
  includedLevel: AiLevel,
  config: PricingConfig
): number {
  const rank: Record<AiLevel, number> = {fast: 0, smart: 1, expert: 2};
  if (rank[selectedLevel] <= rank[includedLevel]) return 0;
  return estimateMaxTokens(selectedLevel, config);
}

/**
 * The Token price of one analysis's real usage (before the reservation
 * cap applied in `handle_analyse_finding.ts`).
 * @param {object} params the observed facts (see [actualAnalysisUsage]).
 * @param {PricingConfig} config the live pricing config.
 * @return {number} whole Tokens.
 */
export function actualAnalysisTokens(
  params: Parameters<typeof actualAnalysisUsage>[0],
  config: PricingConfig
): number {
  return priceUsage(actualAnalysisUsage(params, config), config)
    .tokensCharged;
}
