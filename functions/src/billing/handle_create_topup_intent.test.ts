import assert from "node:assert/strict";
import {test} from "node:test";
import type {Firestore} from "firebase-admin/firestore";
import {fakeFirestore} from "./fakes";
import {handleCreateTopUpIntent} from "./handle_create_topup_intent";
import {myrToCredits} from "./pricing";
import {DEFAULT_PRICING_CONFIG} from "./pricing_config";

/**
 * Regression coverage for the deployed `createTopUpIntent` bug: a
 * normal Wallet Top Up (which is never associated with an inspection)
 * used to fail with "Cannot use \"undefined\" as a Firestore value
 * (found in field \"inspectionId\")" because the absent
 * `inspectionId` was assigned into the persisted document instead of
 * omitted. See `payment_intent.test.ts` for the lower-level coverage
 * of the fix itself.
 */
test("createTopUpIntent succeeds for a normal Top Up with no " +
  "inspectionId, and the persisted intent never contains one", async () => {
  const {db, store} = fakeFirestore();
  const firestore = db as unknown as Firestore;

  const {intentId, amountMyr, creditsAmount} = await handleCreateTopUpIntent({
    auth: {uid: "uid_1"},
    data: {amountMyr: 30, idempotencyKey: "topup_1"},
    firestore,
  });

  assert.ok(intentId.length > 0);
  assert.equal(amountMyr, 30);
  assert.equal(creditsAmount, myrToCredits(30, DEFAULT_PRICING_CONFIG));

  const stored = store.get(`users/uid_1/paymentIntents/${intentId}`);
  assert.ok(stored, "the intent must have been persisted");
  assert.equal(
    Object.prototype.hasOwnProperty.call(stored, "inspectionId"),
    false,
    "a Top Up intent must never persist an inspectionId field"
  );
});

test("a retried createTopUpIntent call (same idempotencyKey) returns " +
  "the same intent rather than creating a second one", async () => {
  const {db} = fakeFirestore();
  const firestore = db as unknown as Firestore;

  const first = await handleCreateTopUpIntent({
    auth: {uid: "uid_1"},
    data: {amountMyr: 15, idempotencyKey: "topup_retry"},
    firestore,
  });
  const second = await handleCreateTopUpIntent({
    auth: {uid: "uid_1"},
    data: {amountMyr: 15, idempotencyKey: "topup_retry"},
    firestore,
  });

  assert.equal(first.intentId, second.intentId);
  assert.equal(first.creditsAmount, second.creditsAmount);
});
