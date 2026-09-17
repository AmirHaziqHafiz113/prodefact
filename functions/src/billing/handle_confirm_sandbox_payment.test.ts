import assert from "node:assert/strict";
import {test} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import {fakeFirestore} from "./fakes";
import {handleCreateTopUpIntent} from "./handle_create_topup_intent";
import {handlePurchaseHousePass} from "./handle_purchase_house_pass";
import {handleConfirmSandboxPayment} from "./handle_confirm_sandbox_payment";
import {getWalletBalance} from "./wallet";
import {myrToCredits} from "./pricing";
import {DEFAULT_PRICING_CONFIG} from "./pricing_config";

/**
 * @return {Firestore} a fake Firestore seeded with `uid_1`'s wallet and
 *   one owned inspection, castable at each call site.
 */
function seededFirestore(): Firestore {
  const {db} = fakeFirestore({
    "users/uid_1/wallet/main": {
      userId: "uid_1",
      balanceCredits: 0,
      updatedAt: 0,
    },
    "users/uid_1/inspections/inspection_1": {},
  });
  return db as unknown as Firestore;
}

test("confirmSandboxPayment refuses to run at all when PAYMENTS_MODE " +
  "isn't set — the default (production) environment — proving a real " +
  "deployment can never accidentally expose a fake-payment-success " +
  "path", async () => {
  const firestore = seededFirestore();
  const {intentId} = await handleCreateTopUpIntent({
    auth: {uid: "uid_1"},
    data: {amountMyr: 10, idempotencyKey: "topup_1"},
    firestore,
  });

  await assert.rejects(
    () =>
      handleConfirmSandboxPayment({
        auth: {uid: "uid_1"},
        data: {intentId},
        firestore,
        env: {}, // PAYMENTS_MODE unset — the real deploy default
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal((error as HttpsError).code, "failed-precondition");
      return true;
    }
  );
  assert.equal(await getWalletBalance(firestore, "uid_1"), 0);
});

test("confirmSandboxPayment refuses to run when PAYMENTS_MODE is set " +
  "to anything other than the literal \"sandbox\" (e.g. a typo'd or " +
  "explicit \"production\" value)", async () => {
  const firestore = seededFirestore();
  const {intentId} = await handleCreateTopUpIntent({
    auth: {uid: "uid_1"},
    data: {amountMyr: 10, idempotencyKey: "topup_1"},
    firestore,
  });

  await assert.rejects(
    () =>
      handleConfirmSandboxPayment({
        auth: {uid: "uid_1"},
        data: {intentId},
        firestore,
        env: {PAYMENTS_MODE: "production"},
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal((error as HttpsError).code, "failed-precondition");
      return true;
    }
  );
});

test("a full sandbox top-up: createTopUpIntent then " +
  "confirmSandboxPayment grants exactly the configured Credits, and a " +
  "replayed confirmation never double-credits", async () => {
  const firestore = seededFirestore();
  const {intentId, creditsAmount} = await handleCreateTopUpIntent({
    auth: {uid: "uid_1"},
    data: {amountMyr: 30, idempotencyKey: "topup_1"},
    firestore,
  });
  assert.equal(creditsAmount, myrToCredits(30, DEFAULT_PRICING_CONFIG));

  const sandboxEnv = {PAYMENTS_MODE: "sandbox"};
  const first = await handleConfirmSandboxPayment({
    auth: {uid: "uid_1"},
    data: {intentId},
    firestore,
    env: sandboxEnv,
  });
  const second = await handleConfirmSandboxPayment({
    auth: {uid: "uid_1"},
    data: {intentId},
    firestore,
    env: sandboxEnv,
  });

  assert.equal(first.creditsAdded, creditsAmount);
  assert.equal(second.creditsAdded, creditsAmount);
  assert.equal(first.newBalance, creditsAmount);
  assert.equal(second.newBalance, creditsAmount); // not doubled
  assert.equal(await getWalletBalance(firestore, "uid_1"), creditsAmount);
});

test("a full sandbox House Pass purchase activates the pass without " +
  "moving any Credits", async () => {
  const firestore = seededFirestore();
  const {intentId, priceMyr} = await handlePurchaseHousePass({
    auth: {uid: "uid_1"},
    data: {inspectionId: "inspection_1", idempotencyKey: "hp_intent_1"},
    firestore,
  });
  assert.equal(priceMyr, DEFAULT_PRICING_CONFIG.housePass.priceMyr);

  const result = await handleConfirmSandboxPayment({
    auth: {uid: "uid_1"},
    data: {intentId},
    firestore,
    env: {PAYMENTS_MODE: "sandbox"},
  });

  assert.equal(result.purpose, "housePass");
  assert.equal(result.creditsAdded, 0);
  assert.equal(await getWalletBalance(firestore, "uid_1"), 0);
});

test("purchaseHousePass rejects a duplicate purchase for an inspection " +
  "that already has an active House Pass", async () => {
  const firestore = seededFirestore();
  const {intentId} = await handlePurchaseHousePass({
    auth: {uid: "uid_1"},
    data: {inspectionId: "inspection_1", idempotencyKey: "hp_intent_1"},
    firestore,
  });
  await handleConfirmSandboxPayment({
    auth: {uid: "uid_1"},
    data: {intentId},
    firestore,
    env: {PAYMENTS_MODE: "sandbox"},
  });

  await assert.rejects(
    () =>
      handlePurchaseHousePass({
        auth: {uid: "uid_1"},
        data: {
          inspectionId: "inspection_1",
          idempotencyKey: "hp_intent_2",
        },
        firestore,
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal((error as HttpsError).code, "already-exists");
      return true;
    }
  );
});

test("confirmSandboxPayment rejects an intentId that doesn't belong to " +
  "the caller", async () => {
  const firestore = seededFirestore();
  await assert.rejects(
    () =>
      handleConfirmSandboxPayment({
        auth: {uid: "uid_1"},
        data: {intentId: "does_not_exist"},
        firestore,
        env: {PAYMENTS_MODE: "sandbox"},
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal((error as HttpsError).code, "not-found");
      return true;
    }
  );
});
