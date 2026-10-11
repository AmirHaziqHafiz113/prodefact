import assert from "node:assert/strict";
import {test} from "node:test";
import type {Firestore} from "firebase-admin/firestore";
import {fakeFirestore} from "./fakes";
import {
  InvalidTokenAmountError,
  TOKENS_PER_MYR,
  assertTokenAmount,
  tokensForLegacyCredits,
  tokensForRetailRm,
  tokensForTopUpMyr,
} from "./tokens";
import {
  buildUsageRecord,
  computeOperationCost,
  DEFAULT_INFRASTRUCTURE_RATES,
  splitTokens,
} from "./usage_cost";
import {
  LEGACY_MIGRATION_ENTRY_ID,
  getWalletBalance,
  migrateLegacyWallet,
  recordTopUp,
  recordUsageOnce,
  reserveTokens,
  settleReservation,
} from "./wallet";
import {DEFAULT_PRICING_CONFIG, resolvePricingConfig} from "./pricing_config";
import {tokensForIntent} from "./payment_intent";

const UID = "uid_1";

/**
 * @param {Record<string, Record<string, unknown>>} seed initial docs.
 * @return {object} the fake db and its backing store.
 */
function db(seed: Record<string, Record<string, unknown>> = {}) {
  const fake = fakeFirestore(seed);
  return {db: fake.db as unknown as Firestore, store: fake.store};
}

const noOverhead = {
  ...DEFAULT_INFRASTRUCTURE_RATES,
  overheadPerOperationUsd: 0,
};

// ---- denomination & conversion ----

test("1,000,000 Tokens = RM1: RM10/50/100 top-ups are 10M/50M/100M " +
  "Tokens", () => {
  assert.equal(TOKENS_PER_MYR, 1_000_000);
  assert.equal(tokensForTopUpMyr(10), 10_000_000);
  assert.equal(tokensForTopUpMyr(50), 50_000_000);
  assert.equal(tokensForTopUpMyr(100), 100_000_000);
  // Whole-sen amounts are exact despite binary floating point.
  assert.equal(tokensForTopUpMyr(0.1), 100_000);
  assert.equal(tokensForTopUpMyr(19.99), 19_990_000);
});

test("retail RM → Tokens: RM0.009146 is exactly 9,146 Tokens; any " +
  "fraction of a Token rounds UP, never down", () => {
  assert.equal(tokensForRetailRm(0.009146), 9_146);
  assert.equal(tokensForRetailRm(0.0091461), 9_147);
  assert.equal(tokensForRetailRm(0.1 + 0.2), 300_000);
  assert.equal(tokensForRetailRm(0), 0);
  assert.equal(tokensForRetailRm(-1), 0);
});

test("Token amounts must be safe non-negative integers — never a " +
  "float balance", () => {
  assert.equal(assertTokenAmount(125_840_000, "b"), 125_840_000);
  assert.throws(() => assertTokenAmount(1.5, "b"), InvalidTokenAmountError);
  assert.throws(() => assertTokenAmount(-1, "b"), InvalidTokenAmountError);
  assert.throws(
    () => assertTokenAmount(Number.MAX_SAFE_INTEGER + 2, "b"),
    InvalidTokenAmountError
  );
});

test("legacy Credits keep their RM value: 100 Credits/RM → 10,000 " +
  "Tokens per Credit", () => {
  assert.equal(tokensForLegacyCredits(1, 100), 10_000);
  assert.equal(tokensForLegacyCredits(500, 100), 5_000_000);
  // An operator-configured legacy rate is honoured.
  assert.equal(tokensForLegacyCredits(120, 120), 1_000_000);
});

// ---- cost model & 100% markup ----

test("100% markup: variable cost × 2 — RM0.004573 cost charges " +
  "RM0.009146 = 9,146 Tokens", () => {
  const cost = computeOperationCost(
    {openaiInputTokens: 1000, openaiInputPerKUsd: 0.004573},
    {rates: noOverhead, usdToMyrRate: 1, markupMultiplier: 2}
  );
  assert.equal(cost.variableCostRm, 0.004573);
  assert.equal(cost.retailCostRm, 0.009146);
  assert.equal(cost.tokensCharged, 9_146);
});

test("infrastructure costs are priced per component and land in their " +
  "user-facing category", () => {
  const cost = computeOperationCost({
    storageDownloadBytes: 1_000_000_000,
    firestoreReads: 100_000,
    functionDurationMs: 1000,
    functionInvocations: 1,
  }, {rates: noOverhead, usdToMyrRate: 1, markupMultiplier: 2});
  assert.equal(cost.costByCategoryRm.storage, 0.12);
  assert.equal(cost.costByCategoryRm.other, 0.06);
  assert.ok(cost.costByCategoryRm.processing > 0);
  assert.equal(cost.costByCategoryRm.aiAnalysis, 0);
  assert.equal(cost.openaiCostRm, 0);
  assert.equal(
    cost.infrastructureCostRm,
    Math.round((0.12 + 0.06 + cost.costByCategoryRm.processing) * 1e9) / 1e9
  );
});

test("the small overhead bucket covers platform micro-costs instead of " +
  "metering them one by one", () => {
  const cost = computeOperationCost({}, {
    rates: DEFAULT_INFRASTRUCTURE_RATES,
    usdToMyrRate: 1,
    markupMultiplier: 2,
  });
  assert.equal(cost.costByCategoryRm.other,
    DEFAULT_INFRASTRUCTURE_RATES.overheadPerOperationUsd);
  assert.ok(cost.tokensCharged > 0);
});

test("the category split of a charge is whole Tokens that always add " +
  "back up to the charge", () => {
  for (const total of [0, 1, 7, 9_146, 27_952, 100_000_001]) {
    const split = splitTokens(total,
      {aiAnalysis: 0.3, storage: 0.1, processing: 0.2, other: 0.05});
    const sum = split.aiAnalysis + split.storage + split.processing +
      split.other;
    assert.equal(sum, total, `${total}`);
    for (const part of Object.values(split)) {
      assert.ok(Number.isInteger(part));
    }
  }
});

// ---- ledger: deduction, idempotency, large balances ----

test("a 125,840,000-Token balance is reserved from and settled exactly",
  async () => {
    const {db: fs} = db({
      [`users/${UID}/wallet/main`]: {
        userId: UID, balanceTokens: 125_840_000, updatedAt: 0,
      },
    });
    await reserveTokens(fs, {
      uid: UID, amountTokens: 27_952, idempotencyKey: "job_reservation",
      inspectionId: "i", findingId: "f", aiLevel: "smart",
      description: "AI Analysis",
    });
    assert.equal(await getWalletBalance(fs, UID), 125_840_000 - 27_952);
    await settleReservation(fs, {
      uid: UID, reservationTransactionId: "job_reservation",
      actualTokens: 9_146, idempotencyKey: "job_settlement",
      description: "AI Analysis",
    });
    assert.equal(await getWalletBalance(fs, UID), 125_840_000 - 9_146);
  });

test("balances of hundreds of millions stay exact integers", async () => {
  const {db: fs, store} = db();
  for (let i = 0; i < 5; i++) {
    await recordTopUp(fs, {
      uid: UID, amountTokens: 100_000_000, idempotencyKey: `topup_${i}`,
      externalPaymentRef: `ref_${i}`, description: "Top Up — RM100",
    });
  }
  assert.equal(await getWalletBalance(fs, UID), 500_000_000);
  const wallet = store.get(`users/${UID}/wallet/main`) as Record<
    string, unknown
  >;
  assert.ok(Number.isSafeInteger(wallet.balanceTokens));
});

test("the usage record is written with the settlement, once: a replayed " +
  "settlement never charges or records twice", async () => {
  const {db: fs, store} = db({
    [`users/${UID}/wallet/main`]: {
      userId: UID, balanceTokens: 1_000_000, updatedAt: 0,
    },
  });
  await reserveTokens(fs, {
    uid: UID, amountTokens: 50_000, idempotencyKey: "k_reservation",
    inspectionId: "i", findingId: "f", aiLevel: "smart",
    description: "AI Analysis",
  });
  const cost = computeOperationCost(
    {openaiInputTokens: 1000, openaiInputPerKUsd: 0.004573},
    {rates: noOverhead, usdToMyrRate: 1, markupMultiplier: 2}
  );
  const usageRecord = buildUsageRecord({
    usageId: "k", userId: UID, inspectionId: "i", findingId: "f",
    operationType: "aiAnalysis",
    usage: {openaiInputTokens: 1000, openaiModel: "m"},
    cost, tokensCharged: cost.tokensCharged, usdToMyrRate: 1,
    pricingVersion: 0, now: 1,
  });
  const settle = () => settleReservation(fs, {
    uid: UID, reservationTransactionId: "k_reservation",
    actualTokens: cost.tokensCharged, idempotencyKey: "k_settlement",
    description: "AI Analysis", usageRecord,
  });
  await settle();
  await settle(); // replay (double tap / Functions retry)
  assert.equal(await getWalletBalance(fs, UID), 1_000_000 - 9_146);
  const record = store.get(`users/${UID}/usageRecords/k`) as Record<
    string, unknown
  >;
  assert.equal(record.tokensCharged, 9_146);
  assert.equal(record.markupMultiplier, 2);
  assert.equal(record.openaiInputTokens, 1000);
  const records = [...store.keys()].filter((k) =>
    k.startsWith(`users/${UID}/usageRecords/`));
  assert.equal(records.length, 1);
  assert.equal(await recordUsageOnce(fs, UID, usageRecord), false);
});

// ---- migration from Credits ----

test("a legacy Credits wallet migrates to Tokens at the same RM value, " +
  "once, with an auditable ledger entry; old Credits history is kept " +
  "untouched", async () => {
  const legacyTopUp = {
    id: "old_topup", userId: UID, type: "topup", direction: "credit",
    amountCredits: 1000, status: "completed", createdAt: 1, updatedAt: 1,
    idempotencyKey: "old_topup", description: "Top Up — RM10",
  };
  const {db: fs, store} = db({
    [`users/${UID}/wallet/main`]: {
      userId: UID, balanceCredits: 734, updatedAt: 0,
    },
    [`users/${UID}/walletTransactions/old_topup`]: legacyTopUp,
  });
  // Read before any write: already at its Token value.
  assert.equal(await getWalletBalance(fs, UID), 7_340_000);

  assert.equal(await migrateLegacyWallet(fs, UID, 100), true);
  assert.equal(await migrateLegacyWallet(fs, UID, 100), false); // once
  assert.equal(await getWalletBalance(fs, UID), 7_340_000);

  const wallet = store.get(`users/${UID}/wallet/main`) as Record<
    string, unknown
  >;
  assert.equal(wallet.balanceTokens, 7_340_000);
  assert.equal(wallet.balanceCredits, 734, "frozen for audit");
  const entry = store.get(
    `users/${UID}/walletTransactions/${LEGACY_MIGRATION_ENTRY_ID}`
  ) as Record<string, unknown>;
  assert.equal(entry.type, "legacyMigration");
  assert.equal(entry.amountTokens, 7_340_000);
  assert.equal(entry.legacyAmountCredits, 734);
  // Historical Credits entries are never rewritten or re-priced.
  assert.deepEqual(
    store.get(`users/${UID}/walletTransactions/old_topup`),
    legacyTopUp
  );
});

test("the first Token transaction on a legacy wallet migrates it in the " +
  "same transaction, never losing value", async () => {
  const {db: fs, store} = db({
    [`users/${UID}/wallet/main`]: {
      userId: UID, balanceCredits: 50, updatedAt: 0,
    },
  });
  await recordTopUp(fs, {
    uid: UID, amountTokens: 10_000_000, idempotencyKey: "t1",
    externalPaymentRef: "r", description: "Top Up — RM10",
  });
  assert.equal(await getWalletBalance(fs, UID), 500_000 + 10_000_000);
  assert.ok(store.get(
    `users/${UID}/walletTransactions/${LEGACY_MIGRATION_ENTRY_ID}`
  ));
});

test("a pending top-up intent created in Credits grants its RM value in " +
  "Tokens", () => {
  assert.equal(tokensForIntent({
    id: "x", userId: UID, purpose: "topup", amountMyr: 10,
    creditsAmount: 1000, status: "pending", createdAt: 0, updatedAt: 0,
  }), 10_000_000);
  assert.equal(tokensForIntent({
    id: "y", userId: UID, purpose: "topup", amountMyr: 10,
    tokensAmount: 10_000_000, status: "pending", createdAt: 0, updatedAt: 0,
  }), 10_000_000);
});

test("a pre-Token pricing/config keeps its Credits threshold's RM value " +
  "and its legacy rate", () => {
  const resolved = resolvePricingConfig({
    creditsPerMyr: 100,
    lowBalanceThresholdCredits: 500,
  });
  assert.equal(resolved.config.lowBalanceThresholdTokens, 5_000_000);
  assert.equal(resolved.config.legacyCreditsPerMyr, 100);
  assert.equal(DEFAULT_PRICING_CONFIG.lowBalanceThresholdTokens, 5_000_000);
});
