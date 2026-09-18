import assert from "node:assert/strict";
import {test} from "node:test";
import type {Firestore} from "firebase-admin/firestore";
import {fakeFirestore} from "./fakes";
import {createPaymentIntent, getPaymentIntent} from "./payment_intent";

/**
 * Regression coverage for the bug where an absent optional field
 * (`inspectionId` on a `topup` intent, `creditsAmount` on a
 * `housePass` intent) was assigned into the Firestore document as a
 * literal `undefined` instead of being omitted — which real Firestore
 * rejects outright (`Cannot use "undefined" as a Firestore value`).
 * `fakes.ts`'s `fakeFirestore` mirrors that rejection, so any
 * regression here fails loudly in-memory rather than only in a real
 * deployment.
 */

test("createPaymentIntent for a Top Up (no inspectionId) succeeds and " +
  "never persists an inspectionId field at all", async () => {
  const {db, store} = fakeFirestore();
  const firestore = db as unknown as Firestore;

  const intent = await createPaymentIntent(firestore, {
    uid: "uid_1",
    idempotencyKey: "topup_1",
    purpose: "topup",
    amountMyr: 30,
    creditsAmount: 3000,
    // inspectionId intentionally omitted — a Top Up is never
    // associated with an inspection.
  });

  assert.equal(intent.purpose, "topup");
  assert.equal(intent.creditsAmount, 3000);

  const stored = store.get("users/uid_1/paymentIntents/topup_1");
  assert.ok(stored, "the intent must have been persisted");
  assert.equal(Object.prototype.hasOwnProperty.call(stored, "inspectionId"),
    false, "inspectionId must be omitted, not written as undefined");

  const fetched = await getPaymentIntent(firestore, "uid_1", "topup_1");
  assert.equal(fetched?.inspectionId, undefined);
});

test("createPaymentIntent for a House Pass (no creditsAmount) still " +
  "persists its real inspectionId and omits creditsAmount", async () => {
  const {db, store} = fakeFirestore();
  const firestore = db as unknown as Firestore;

  const intent = await createPaymentIntent(firestore, {
    uid: "uid_1",
    idempotencyKey: "hp_1",
    purpose: "housePass",
    amountMyr: 30,
    inspectionId: "inspection_1",
    // creditsAmount intentionally omitted — House Pass never grants
    // Credits.
  });

  assert.equal(intent.purpose, "housePass");
  assert.equal(intent.inspectionId, "inspection_1");

  const stored = store.get("users/uid_1/paymentIntents/hp_1");
  assert.ok(stored);
  assert.equal(stored?.inspectionId, "inspection_1");
  assert.equal(Object.prototype.hasOwnProperty.call(stored, "creditsAmount"),
    false, "creditsAmount must be omitted, not written as undefined");
});

test("no persisted payment intent ever contains an undefined-valued " +
  "field, for either purpose", async () => {
  const {db, store} = fakeFirestore();
  const firestore = db as unknown as Firestore;

  await createPaymentIntent(firestore, {
    uid: "uid_1",
    idempotencyKey: "topup_1",
    purpose: "topup",
    amountMyr: 10,
    creditsAmount: 1000,
  });
  await createPaymentIntent(firestore, {
    uid: "uid_1",
    idempotencyKey: "hp_1",
    purpose: "housePass",
    amountMyr: 30,
    inspectionId: "inspection_1",
  });

  for (const [path, data] of store.entries()) {
    for (const [field, value] of Object.entries(data as object)) {
      assert.notEqual(value, undefined,
        `${path} must not have an undefined "${field}" field`);
    }
  }
});
