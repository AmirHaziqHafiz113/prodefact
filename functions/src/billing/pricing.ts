import {AiLevelConfig, PricingConfig} from "./pricing_config";
import {AiLevel} from "./types";

/**
 * Pure pricing math — no I/O, no Firestore, trivially unit-testable.
 * This is the one place provider-cost-in-USD becomes customer-facing
 * Credits. See docs/commercial_model.md for the full worked
 * explanation.
 */

/**
 * Converts a provider cost in USD to Credits, via the configured
 * MYR-per-USD-equivalent markup chain: Credits = providerCostUsd ×
 * markupMultiplier × creditsPerMyr, rounded up (never round a customer
 * charge down — see `providerCostForTokensUsd`). Note: this treats
 * provider cost as already expressed in a currency-neutral "USD ≈ MYR
 * cost basis" for this pass — a real FX conversion step is explicitly
 * deferred (see docs/commercial_model.md, "Future: payment fees, FX,
 * taxes").
 * @param {number} providerCostUsd the raw provider cost, in USD.
 * @param {PricingConfig} config the live pricing config.
 * @return {number} the customer charge, in whole Credits (rounded up).
 */
export function creditsForProviderCostUsd(
  providerCostUsd: number,
  config: PricingConfig
): number {
  const customerCostUsd = providerCostUsd * config.markupMultiplier;
  return Math.ceil(customerCostUsd * config.creditsPerMyr);
}

/**
 * @param {number} inputTokens tokens sent to the provider.
 * @param {number} outputTokens tokens returned by the provider.
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
 * The "up to N Credits" figure shown before the inspector approves AI
 * analysis — computed from each level's conservative estimated token
 * counts. Deliberately a ceiling, never the (unknowable in advance)
 * exact charge.
 * @param {AiLevel} aiLevel the selected level.
 * @param {PricingConfig} config the live pricing config.
 * @return {number} the maximum Credits this analysis could cost.
 */
export function estimateMaxCredits(
  aiLevel: AiLevel,
  config: PricingConfig
): number {
  const levelConfig = config.aiLevels[aiLevel];
  const worstCaseUsd = providerCostForTokensUsd(
    levelConfig.estimatedInputTokens,
    levelConfig.estimatedOutputTokens,
    levelConfig
  );
  return creditsForProviderCostUsd(worstCaseUsd, config);
}

/**
 * The actual customer charge once the provider has responded, from its
 * real (server-observed, never client-supplied) token usage. Never
 * exceeds [estimateMaxCredits] in practice since real usage is
 * normally within the conservative estimate — but if a provider
 * response is unusually large, the charge is still capped at the
 * originally-reserved maximum (the customer is never charged more than
 * what they were shown and approved) — see `wallet.ts`'s settlement
 * logic, which clamps to the reservation amount.
 * @param {AiLevel} aiLevel the level actually used.
 * @param {number} inputTokens the provider's reported prompt tokens.
 * @param {number} outputTokens the provider's reported completion
 *   tokens.
 * @param {PricingConfig} config the live pricing config.
 * @return {number} the actual customer charge, in Credits.
 */
export function actualCreditsForUsage(
  aiLevel: AiLevel,
  inputTokens: number,
  outputTokens: number,
  config: PricingConfig
): number {
  const levelConfig = config.aiLevels[aiLevel];
  const costUsd = providerCostForTokensUsd(
    inputTokens,
    outputTokens,
    levelConfig
  );
  return creditsForProviderCostUsd(costUsd, config);
}

/**
 * @param {number} credits a Credits amount.
 * @param {PricingConfig} config the live pricing config.
 * @return {number} the equivalent MYR value, for display only (e.g.
 *   "≈ RM0.18").
 */
export function creditsToMyr(credits: number, config: PricingConfig): number {
  return credits / config.creditsPerMyr;
}

/**
 * @param {number} myr a Ringgit amount (e.g. a top-up package price).
 * @param {PricingConfig} config the live pricing config.
 * @return {number} the whole number of Credits that amount buys.
 */
export function myrToCredits(myr: number, config: PricingConfig): number {
  return Math.round(myr * config.creditsPerMyr);
}

/**
 * The extra Credits required when a House Pass's included AI level is
 * lower than the one the inspector selected — e.g. a pass including
 * `smart` but the inspector picks `expert`. 0 when the selected level
 * is the included level or "lower" in the fixed ranking
 * fast < smart < expert.
 * @param {AiLevel} selectedLevel the level the inspector picked.
 * @param {AiLevel} includedLevel the House Pass's included level.
 * @param {PricingConfig} config the live pricing config.
 * @return {number} the surcharge, in Credits.
 */
export function housePassSurchargeCredits(
  selectedLevel: AiLevel,
  includedLevel: AiLevel,
  config: PricingConfig
): number {
  const rank: Record<AiLevel, number> = {fast: 0, smart: 1, expert: 2};
  if (rank[selectedLevel] <= rank[includedLevel]) return 0;
  return estimateMaxCredits(selectedLevel, config);
}
