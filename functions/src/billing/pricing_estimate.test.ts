import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {join} from "node:path";
import {test} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import {fakeFirestore} from "./fakes";
import {
  DEFAULT_PRICING_CONFIG,
  MODEL_LINEUP_VERSION,
  resolvePricingConfig,
} from "./pricing_config";
import {
  handleEstimateFindingAnalysis,
} from "./handle_estimate_finding_analysis";

/**
 * The "Could not check pricing" fix (2026-10-01). Production logs showed
 * every estimate returning HTTP 403 (permission-denied): the finding's
 * Firestore document didn't exist yet, so the ownership check refused
 * it. These tests pin the ownership contract and harden pricing/config.
 */

const UID = "uid_1";

/**
 * @param {object} [extra] extra documents to seed.
 * @return {Firestore} a fake Firestore with one owned, synced finding.
 */
function seeded(extra: Record<string, Record<string, unknown>> = {}) {
  const {db} = fakeFirestore({
    [`users/${UID}/inspections/inspection_1/findings/finding_1`]: {},
    [`users/${UID}/wallet/main`]: {userId: UID, balanceCredits: 500,
      updatedAt: 0},
    ...extra,
  });
  return db as unknown as Firestore;
}

const request = {
  inspectionId: "inspection_1",
  findingId: "finding_1",
  aiLevel: "smart",
};

test("1 + 10. a synced finding gets an estimate with the full response " +
  "shape the app parses", async () => {
  const result = await handleEstimateFindingAnalysis({
    auth: {uid: UID},
    data: request,
    firestore: seeded(),
  });
  assert.deepEqual(Object.keys(result).sort(), [
    "aiLevel", "currentBalance", "eligible", "estimatedCredits",
    "includedInHousePass", "maximumCredits", "paymentMode", "reason",
    "surchargeCredits",
  ]);
  assert.equal(result.aiLevel, "smart");
  assert.equal(result.maximumCredits, 2);
  assert.equal(result.currentBalance, 500);
  assert.equal(result.paymentMode, "flexCredits");
  assert.equal(result.eligible, true);
});

test("2. a finding with no Firestore document is refused with " +
  "permission-denied and a findingNotSynced reason", async () => {
  await assert.rejects(
    handleEstimateFindingAnalysis({
      auth: {uid: UID},
      data: {...request, findingId: "finding_local_only"},
      firestore: seeded(),
    }),
    (error) => error instanceof HttpsError &&
      error.code === "permission-denied" &&
      (error.details as {reason: string}).reason === "findingNotSynced"
  );
});

test("13. ownership is still enforced: another user's finding is refused",
  async () => {
    const firestore = seeded({
      "users/uid_2/inspections/inspection_9/findings/finding_9": {},
    });
    await assert.rejects(
      handleEstimateFindingAnalysis({
        auth: {uid: UID},
        data: {...request, inspectionId: "inspection_9",
          findingId: "finding_9"},
        firestore,
      }),
      (error) => error instanceof HttpsError &&
        error.code === "permission-denied"
    );
    await assert.rejects(
      handleEstimateFindingAnalysis({auth: null, data: request, firestore}),
      (error) => error instanceof HttpsError &&
        error.code === "unauthenticated"
    );
  });

test("8. no pricing/config document: the deployed defaults apply", () => {
  const resolved = resolvePricingConfig(undefined);
  assert.equal(resolved.source, "default");
  assert.deepEqual(resolved.issues, []);
  assert.equal(resolved.config, DEFAULT_PRICING_CONFIG);
});

test("9. the deployed model lineup is intact", () => {
  const levels = resolvePricingConfig(undefined).config.aiLevels;
  assert.equal(levels.fast.model, "gpt-6-luna");
  assert.equal(levels.smart.model, "gpt-6.1-sol");
  assert.equal(
    Object.values(levels).some((l) => l.model === "gpt-5.6-terra"),
    false,
    "gpt-5.6-terra is retired from the active lineup"
  );
  assert.equal(levels.expert.model, "gpt-6.1-sol");
});

test("7. a valid persisted config applies its commercial overrides and, " +
  "when it declares the current lineup, its model settings", () => {
  const resolved = resolvePricingConfig({
    version: 7,
    creditsPerMyr: 120,
    markupMultiplier: 2.5,
    modelLineupVersion: MODEL_LINEUP_VERSION,
    aiLevels: {
      smart: {...DEFAULT_PRICING_CONFIG.aiLevels.smart,
        estimatedOutputTokens: 400},
    },
    housePass: {priceMyr: 35},
  });
  assert.equal(resolved.source, "firestore");
  assert.equal(resolved.config.version, 7);
  assert.equal(resolved.config.creditsPerMyr, 120);
  assert.equal(resolved.config.markupMultiplier, 2.5);
  assert.equal(resolved.config.aiLevels.smart.estimatedOutputTokens, 400);
  assert.equal(resolved.config.housePass.priceMyr, 35);
  // Fields the document didn't mention keep their deployed values.
  assert.equal(resolved.config.housePass.allowanceFindings,
    DEFAULT_PRICING_CONFIG.housePass.allowanceFindings);
  assert.deepEqual(resolved.config.aiLevels.fast,
    DEFAULT_PRICING_CONFIG.aiLevels.fast);
});

test("an older document cannot silently revert the deployed lineup", () => {
  const resolved = resolvePricingConfig({
    version: 3,
    aiLevels: {
      fast: {...DEFAULT_PRICING_CONFIG.aiLevels.fast, model: "gpt-5.6-luna",
        providerCostPerKInputTokensUsd: 0.001},
    },
  });
  assert.equal(resolved.config.aiLevels.fast.model, "gpt-6-luna");
  assert.equal(resolved.config.version, 3);
  assert.ok(resolved.issues.some((i) => i.includes("older model lineup")));
});

test("4-6. a malformed document never causes undefined access: missing " +
  "Smart and missing price fields are reported and defaulted", () => {
  const resolved = resolvePricingConfig({
    creditsPerMyr: "100",
    markupMultiplier: Number.NaN,
    modelLineupVersion: MODEL_LINEUP_VERSION,
    aiLevels: {
      fast: {provider: "openai", model: "gpt-6-luna",
        providerCostPerKInputTokensUsd: "cheap",
        providerCostPerKOutputTokensUsd: null},
      expert: "broken",
    },
    housePass: 42,
    topUpPackagesMyr: [10, -5],
  });
  const issues = resolved.issues;
  for (const expected of [
    "creditsPerMyr is invalid",
    "markupMultiplier is invalid",
    "aiLevels.smart is missing",
    "aiLevels.expert is invalid",
    "aiLevels.fast.providerCostPerKInputTokensUsd is invalid",
    "aiLevels.fast.providerCostPerKOutputTokensUsd is invalid",
    "housePass is invalid",
    "topUpPackagesMyr is invalid",
  ]) {
    assert.ok(issues.includes(expected), `${expected} in ${issues}`);
  }
  const config = resolved.config;
  for (const level of ["fast", "smart", "expert"] as const) {
    const c = config.aiLevels[level];
    assert.ok(Number.isFinite(c.providerCostPerKInputTokensUsd), level);
    assert.ok(Number.isFinite(c.providerCostPerKOutputTokensUsd), level);
  }
  assert.equal(config.creditsPerMyr, DEFAULT_PRICING_CONFIG.creditsPerMyr);
  assert.equal(config.housePass.priceMyr,
    DEFAULT_PRICING_CONFIG.housePass.priceMyr);
  assert.deepEqual(resolvePricingConfig("nonsense").config,
    DEFAULT_PRICING_CONFIG);
});

test("a malformed persisted config still produces a valid estimate",
  async () => {
    const firestore = seeded({
      "pricing/config": {aiLevels: {smart: null}, markupMultiplier: "x"},
    });
    const result = await handleEstimateFindingAnalysis({
      auth: {uid: UID},
      data: request,
      firestore,
    });
    assert.equal(result.maximumCredits, 2);
  });

test("12. App Check is not enforced on estimateFindingAnalysis (unchanged)",
  () => {
    const index = readFileSync(join(__dirname, "..", "..", "src",
      "index.ts"), "utf8");
    assert.equal(/enforceAppCheck:\s*true/.test(index), false);
  });
