import assert from "node:assert/strict";
import {test} from "node:test";
import {
  actualCreditsForUsage,
  creditsForProviderCostUsd,
  creditsToMyr,
  estimateMaxCredits,
  housePassSurchargeCredits,
  myrToCredits,
  providerCostForTokensUsd,
} from "./pricing";
import {DEFAULT_PRICING_CONFIG} from "./pricing_config";

test("creditsForProviderCostUsd applies the configured markup and " +
  "MYR-per-Credit conversion, rounding up (never down)", () => {
  const config = {
    ...DEFAULT_PRICING_CONFIG,
    creditsPerMyr: 100,
    markupMultiplier: 2,
  };
  // $0.01 provider cost * 2x markup = $0.02 "MYR-equivalent" * 100
  // Credits/MYR = 2 Credits exactly.
  assert.equal(creditsForProviderCostUsd(0.01, config), 2);
  // A cost that doesn't divide evenly must round up, never down — the
  // customer is never undercharged by a rounding artifact.
  assert.equal(creditsForProviderCostUsd(0.0101, config), 3);
});

test("providerCostForTokensUsd combines input/output rates correctly", () => {
  const levelConfig = DEFAULT_PRICING_CONFIG.aiLevels.smart;
  const cost = providerCostForTokensUsd(2000, 100, levelConfig);
  const expected =
    (2000 / 1000) * levelConfig.providerCostPerKInputTokensUsd +
    (100 / 1000) * levelConfig.providerCostPerKOutputTokensUsd;
  assert.equal(cost, expected);
});

test("estimateMaxCredits is a ceiling computed from the level's " +
  "conservative token estimates, never the (unknowable in advance) " +
  "exact cost", () => {
  const config = DEFAULT_PRICING_CONFIG;
  const maxCredits = estimateMaxCredits("smart", config);
  assert.ok(maxCredits > 0);
  // A real request using fewer tokens than the estimate must cost at
  // most that ceiling.
  const actual = actualCreditsForUsage("smart", 100, 10, config);
  assert.ok(actual <= maxCredits);
});

test("actualCreditsForUsage scales with real token usage", () => {
  const config = DEFAULT_PRICING_CONFIG;
  const small = actualCreditsForUsage("fast", 500, 50, config);
  const large = actualCreditsForUsage("fast", 5000, 500, config);
  assert.ok(large > small);
});

test("creditsToMyr and myrToCredits are inverses of the same ratio", () => {
  const config = {...DEFAULT_PRICING_CONFIG, creditsPerMyr: 100};
  assert.equal(myrToCredits(10, config), 1000);
  assert.equal(myrToCredits(30, config), 3000);
  assert.equal(myrToCredits(50, config), 5000);
  assert.equal(myrToCredits(100, config), 10000);
  assert.equal(creditsToMyr(1000, config), 10);
});

test("housePassSurchargeCredits is 0 when the selected level is at or " +
  "below the pass's included level", () => {
  const config = DEFAULT_PRICING_CONFIG;
  assert.equal(housePassSurchargeCredits("fast", "smart", config), 0);
  assert.equal(housePassSurchargeCredits("smart", "smart", config), 0);
});

test("housePassSurchargeCredits charges the full estimated Credits for " +
  "a level above the pass's included level", () => {
  const config = DEFAULT_PRICING_CONFIG;
  const surcharge = housePassSurchargeCredits("expert", "smart", config);
  assert.equal(surcharge, estimateMaxCredits("expert", config));
  assert.ok(surcharge > 0);
});
