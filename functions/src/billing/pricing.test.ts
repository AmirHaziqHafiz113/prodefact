import assert from "node:assert/strict";
import {test} from "node:test";
import {
  actualAnalysisTokens,
  estimateMaxTokens,
  housePassSurchargeTokens,
  myrToTokens,
  priceUsage,
  providerCostForTokensUsd,
  tokensToMyr,
} from "./pricing";
import {DEFAULT_PRICING_CONFIG} from "./pricing_config";

test("providerCostForTokensUsd combines input/output rates correctly", () => {
  const levelConfig = DEFAULT_PRICING_CONFIG.aiLevels.smart;
  const cost = providerCostForTokensUsd(2000, 100, levelConfig);
  const expected =
    (2000 / 1000) * levelConfig.providerCostPerKInputTokensUsd +
    (100 / 1000) * levelConfig.providerCostPerKOutputTokensUsd;
  assert.equal(cost, expected);
});

test("100% markup: an RM1 variable cost is charged RM2 = 2,000,000 " +
  "Tokens (a 50% gross margin, not 100%)", () => {
  const config = {
    ...DEFAULT_PRICING_CONFIG,
    usdToMyrRate: 1,
    markupMultiplier: 2,
    infrastructureRates: {
      ...DEFAULT_PRICING_CONFIG.infrastructureRates,
      overheadPerOperationUsd: 0,
    },
  };
  // 1M input tokens at $1/1K = $1,000 … scale down: 1,000 tokens at
  // $1/1K = $1 = RM1 at a 1:1 rate.
  const cost = priceUsage({
    openaiInputTokens: 1000,
    openaiInputPerKUsd: 1,
  }, config);
  assert.equal(cost.variableCostRm, 1);
  assert.equal(cost.retailCostRm, 2);
  assert.equal(cost.tokensCharged, 2_000_000);
  const grossMargin = (cost.retailCostRm - cost.variableCostRm) /
    cost.retailCostRm;
  assert.equal(grossMargin, 0.5);
});

test("the FX rate converts USD list prices into RM cost", () => {
  const base = {
    ...DEFAULT_PRICING_CONFIG,
    infrastructureRates: {
      ...DEFAULT_PRICING_CONFIG.infrastructureRates,
      overheadPerOperationUsd: 0,
    },
  };
  const usage = {openaiInputTokens: 1000, openaiInputPerKUsd: 0.001};
  const atOne = priceUsage(usage, {...base, usdToMyrRate: 1});
  const atFour = priceUsage(usage, {...base, usdToMyrRate: 4});
  assert.equal(atOne.openaiCostRm, 0.001);
  assert.equal(atFour.openaiCostRm, 0.004);
  assert.equal(atFour.tokensCharged, 4 * atOne.tokensCharged);
});

test("estimateMaxTokens is a ceiling: real usage below the worst case " +
  "never costs more", () => {
  const config = DEFAULT_PRICING_CONFIG;
  const max = estimateMaxTokens("smart", config);
  assert.ok(Number.isSafeInteger(max) && max > 0);
  const actual = actualAnalysisTokens({
    aiLevel: "smart",
    providerUsage: {inputTokens: 100, outputTokens: 10},
    imageBytes: 1_000_000,
    imageCount: 1,
    functionDurationMs: 5_000,
  }, config);
  assert.ok(actual <= max, `${actual} <= ${max}`);
});

test("actual Tokens scale with real provider usage", () => {
  const config = DEFAULT_PRICING_CONFIG;
  const at = (inputTokens: number, outputTokens: number) =>
    actualAnalysisTokens({
      aiLevel: "fast",
      providerUsage: {inputTokens, outputTokens},
      imageBytes: 0,
      imageCount: 0,
      functionDurationMs: 0,
    }, config);
  const small = at(500, 50);
  const large = at(500_000, 50_000);
  assert.ok(small > 0);
  assert.ok(large > small);
});

test("RM ↔ Tokens: 1,000,000 Tokens = RM1 (RM10/50/100 packages)", () => {
  assert.equal(myrToTokens(10), 10_000_000);
  assert.equal(myrToTokens(30), 30_000_000);
  assert.equal(myrToTokens(50), 50_000_000);
  assert.equal(myrToTokens(100), 100_000_000);
  assert.equal(tokensToMyr(10_000_000), 10);
});

test("housePassSurchargeTokens is 0 when the selected level is at or " +
  "below the pass's included level", () => {
  const config = DEFAULT_PRICING_CONFIG;
  assert.equal(housePassSurchargeTokens("fast", "smart", config), 0);
  assert.equal(housePassSurchargeTokens("smart", "smart", config), 0);
});

test("housePassSurchargeTokens charges the full estimated Tokens for " +
  "a level above the pass's included level", () => {
  const config = DEFAULT_PRICING_CONFIG;
  const surcharge = housePassSurchargeTokens("expert", "smart", config);
  assert.equal(surcharge, estimateMaxTokens("expert", config));
  assert.ok(surcharge > 0);
});
