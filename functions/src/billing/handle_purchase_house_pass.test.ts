import assert from "node:assert/strict";
import {test} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import {fakeFirestore} from "./fakes";
import {handlePurchaseHousePass} from "./handle_purchase_house_pass";
import {DEFAULT_PRICING_CONFIG} from "./pricing_config";

/**
 * @return {Firestore} a fake Firestore seeded with one owned
 *   inspection for `uid_1`, no `pricing/config` doc (so
 *   [DEFAULT_PRICING_CONFIG] — a `test`-environment House Pass config
 *   — applies).
 */
function seededFirestore(): Firestore {
  const {db} = fakeFirestore({
    "users/uid_1/inspections/inspection_1": {},
  });
  return db as unknown as Firestore;
}

test("purchaseHousePass rejects a production-facing deployment " +
  "(PAYMENTS_MODE unset — the real deploy default) selling a House " +
  "Pass against a still-`test` pricing/config allowance, instead of " +
  "silently letting the 200-finding test allowance become the de " +
  "facto production one", async () => {
  const firestore = seededFirestore();

  await assert.rejects(
    () =>
      handlePurchaseHousePass({
        auth: {uid: "uid_1"},
        data: {inspectionId: "inspection_1", idempotencyKey: "hp_1"},
        firestore,
        env: {},
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal((error as HttpsError).code, "failed-precondition");
      return true;
    }
  );
});

test("purchaseHousePass rejects the same test-config sale even when " +
  "PAYMENTS_MODE is explicitly \"production\"", async () => {
  const firestore = seededFirestore();

  await assert.rejects(
    () =>
      handlePurchaseHousePass({
        auth: {uid: "uid_1"},
        data: {inspectionId: "inspection_1", idempotencyKey: "hp_1"},
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

test("purchaseHousePass allows a test-config sale when this " +
  "deployment's own PAYMENTS_MODE is explicitly \"sandbox\" — the " +
  "same boundary confirmSandboxPayment itself relies on", async () => {
  const firestore = seededFirestore();

  const {intentId, priceMyr} = await handlePurchaseHousePass({
    auth: {uid: "uid_1"},
    data: {inspectionId: "inspection_1", idempotencyKey: "hp_1"},
    firestore,
    env: {PAYMENTS_MODE: "sandbox"},
  });

  assert.ok(intentId.length > 0);
  assert.equal(priceMyr, DEFAULT_PRICING_CONFIG.housePass.priceMyr);
});

test("purchaseHousePass allows a sale outside sandbox mode once " +
  "pricing/config.housePass.environment is explicitly " +
  "\"production\"", async () => {
  const {db} = fakeFirestore({
    "users/uid_1/inspections/inspection_1": {},
    "pricing/config": {
      ...DEFAULT_PRICING_CONFIG,
      housePass: {
        ...DEFAULT_PRICING_CONFIG.housePass,
        environment: "production",
        allowanceFindings: 15,
      },
    },
  });
  const firestore = db as unknown as Firestore;

  const {intentId, priceMyr} = await handlePurchaseHousePass({
    auth: {uid: "uid_1"},
    data: {inspectionId: "inspection_1", idempotencyKey: "hp_1"},
    firestore,
    env: {},
  });

  assert.ok(intentId.length > 0);
  assert.equal(priceMyr, DEFAULT_PRICING_CONFIG.housePass.priceMyr);
});
