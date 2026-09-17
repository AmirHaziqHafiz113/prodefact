import assert from "node:assert/strict";
import {test} from "node:test";
import type {Firestore} from "firebase-admin/firestore";
import {fakeFirestore} from "./fakes";
import {
  InsufficientCreditsError,
  getWalletBalance,
  recordAdjustment,
  recordHousePassPurchase,
  recordTopUp,
  releaseReservation,
  reserveCredits,
  settleReservation,
} from "./wallet";

/**
 * @param {number} balanceCredits the seeded starting balance.
 * @return {object} a fake wallet pre-seeded for `uid_1`.
 */
function seededWallet(balanceCredits: number) {
  const {db, store} = fakeFirestore({
    "users/uid_1/wallet/main": {
      userId: "uid_1",
      balanceCredits,
      updatedAt: 0,
    },
  });
  return {db: db as unknown as Firestore, store};
}

test("getWalletBalance returns 0 for a wallet that's never been " +
  "touched, rather than throwing", async () => {
  const {db} = fakeFirestore({});
  const balance = await getWalletBalance(db as unknown as Firestore, "uid_1");
  assert.equal(balance, 0);
});

test("recordTopUp credits the wallet and is retryable via " +
  "idempotencyKey without double-crediting", async () => {
  const {db} = seededWallet(0);
  const params = {
    uid: "uid_1",
    amountCredits: 1000,
    idempotencyKey: "topup_1",
    externalPaymentRef: "sandbox_ref_1",
    description: "RM10 top-up",
  };
  const first = await recordTopUp(db, params);
  const second = await recordTopUp(db, params); // simulated retry/replay

  assert.equal(first.id, second.id);
  assert.equal(await getWalletBalance(db, "uid_1"), 1000);
});

test("reserveCredits debits the wallet by the full reserved amount",
  async () => {
    const {db} = seededWallet(500);
    await reserveCredits(db, {
      uid: "uid_1",
      amountCredits: 200,
      idempotencyKey: "res_1",
      inspectionId: "inspection_1",
      findingId: "finding_1",
      aiLevel: "smart",
      description: "AI analysis (smart) — reserved",
    });
    assert.equal(await getWalletBalance(db, "uid_1"), 300);
  });

test("reserveCredits throws InsufficientCreditsError and never touches " +
  "the balance when the wallet can't cover the reservation", async () => {
  const {db} = seededWallet(50);
  await assert.rejects(
    () =>
      reserveCredits(db, {
        uid: "uid_1",
        amountCredits: 200,
        idempotencyKey: "res_1",
        inspectionId: "inspection_1",
        findingId: "finding_1",
        aiLevel: "smart",
        description: "AI analysis (smart) — reserved",
      }),
    InsufficientCreditsError
  );
  assert.equal(await getWalletBalance(db, "uid_1"), 50);
});

test("a repeated reserveCredits call with the same idempotencyKey " +
  "never debits the wallet twice (duplicate-tap protection)", async () => {
  const {db} = seededWallet(500);
  const params = {
    uid: "uid_1",
    amountCredits: 200,
    idempotencyKey: "res_1",
    inspectionId: "inspection_1",
    findingId: "finding_1",
    aiLevel: "smart" as const,
    description: "AI analysis (smart) — reserved",
  };
  await reserveCredits(db, params);
  await reserveCredits(db, params);
  await reserveCredits(db, params);
  assert.equal(await getWalletBalance(db, "uid_1"), 300);
});

test("settleReservation refunds the unused portion and leaves the " +
  "balance reduced by exactly the actual charge", async () => {
  const {db} = seededWallet(500);
  const reservation = await reserveCredits(db, {
    uid: "uid_1",
    amountCredits: 200,
    idempotencyKey: "res_1",
    inspectionId: "inspection_1",
    findingId: "finding_1",
    aiLevel: "smart",
    description: "reserved",
  });
  // Balance is now 300 (500 - 200 reserved).
  await settleReservation(db, {
    uid: "uid_1",
    reservationTransactionId: reservation.id,
    actualCredits: 120,
    idempotencyKey: "res_1_settle",
    description: "AI analysis (smart)",
  });
  // 500 - 120 actual == 380, i.e. the 80 unused Credits were returned.
  assert.equal(await getWalletBalance(db, "uid_1"), 380);
});

test("settleReservation never charges more than what was originally " +
  "reserved, even if actualCredits is (incorrectly) reported higher",
async () => {
  const {db} = seededWallet(500);
  const reservation = await reserveCredits(db, {
    uid: "uid_1",
    amountCredits: 200,
    idempotencyKey: "res_1",
    inspectionId: "inspection_1",
    findingId: "finding_1",
    aiLevel: "smart",
    description: "reserved",
  });
  await settleReservation(db, {
    uid: "uid_1",
    reservationTransactionId: reservation.id,
    actualCredits: 9999,
    idempotencyKey: "res_1_settle",
    description: "AI analysis (smart)",
  });
  // Clamped to the 200 that was actually reserved/approved.
  assert.equal(await getWalletBalance(db, "uid_1"), 300);
});

test("a repeated settleReservation call with the same idempotencyKey " +
  "never settles twice", async () => {
  const {db} = seededWallet(500);
  const reservation = await reserveCredits(db, {
    uid: "uid_1",
    amountCredits: 200,
    idempotencyKey: "res_1",
    inspectionId: "inspection_1",
    findingId: "finding_1",
    aiLevel: "smart",
    description: "reserved",
  });
  const settleParams = {
    uid: "uid_1",
    reservationTransactionId: reservation.id,
    actualCredits: 120,
    idempotencyKey: "res_1_settle",
    description: "AI analysis (smart)",
  };
  await settleReservation(db, settleParams);
  await settleReservation(db, settleParams);
  assert.equal(await getWalletBalance(db, "uid_1"), 380);
});

test("releaseReservation refunds the full reserved amount — a failed " +
  "AI job must never cost the inspector any Credits", async () => {
  const {db} = seededWallet(500);
  const reservation = await reserveCredits(db, {
    uid: "uid_1",
    amountCredits: 200,
    idempotencyKey: "res_1",
    inspectionId: "inspection_1",
    findingId: "finding_1",
    aiLevel: "smart",
    description: "reserved",
  });
  await releaseReservation(db, {
    uid: "uid_1",
    reservationTransactionId: reservation.id,
    idempotencyKey: "res_1_release",
    description: "AI analysis failed — reservation released",
  });
  assert.equal(await getWalletBalance(db, "uid_1"), 500);
});

test("recordHousePassPurchase never moves Credits — House Pass is a " +
  "separate fixed-price product", async () => {
  const {db} = seededWallet(0);
  await recordHousePassPurchase(db, {
    uid: "uid_1",
    amountCredits: 3000,
    idempotencyKey: "hp_1",
    inspectionId: "inspection_1",
    externalPaymentRef: "sandbox_ref_2",
    description: "House Pass purchase",
  });
  assert.equal(await getWalletBalance(db, "uid_1"), 0);
});

test("recordAdjustment can credit or debit and reflects the sign of " +
  "amountCredits", async () => {
  const {db} = seededWallet(100);
  await recordAdjustment(db, {
    uid: "uid_1",
    amountCredits: 50,
    idempotencyKey: "adj_1",
    description: "goodwill Credits",
  });
  assert.equal(await getWalletBalance(db, "uid_1"), 150);

  await recordAdjustment(db, {
    uid: "uid_1",
    amountCredits: -30,
    idempotencyKey: "adj_2",
    description: "correction",
  });
  assert.equal(await getWalletBalance(db, "uid_1"), 120);
});
