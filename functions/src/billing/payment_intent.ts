import type {Firestore} from "firebase-admin/firestore";

/**
 * A payment intent — the backend-created, backend-authoritative record
 * of "the client asked to pay RM_X for _Y_", created *before* any
 * payment is attempted and confirmed only once a payment provider (or,
 * in sandbox/test mode, `SandboxPaymentService`) actually verifies
 * success. See docs/commercial_model.md ("Payment architecture") — the
 * client never gets to assert payment success on its own.
 */
export type PaymentPurpose = "topup" | "housePass";
export type PaymentIntentStatus = "pending" | "succeeded" | "failed";

export interface PaymentIntent {
  id: string;
  userId: string;
  purpose: PaymentPurpose;
  amountMyr: number;
  /** The Credits a `topup` intent will grant on success — irrelevant
   * for `housePass`, which never grants Credits. */
  creditsAmount?: number;
  /** The inspection a `housePass` intent is for — irrelevant for
   * `topup`. */
  inspectionId?: string;
  status: PaymentIntentStatus;
  createdAt: number;
  updatedAt: number;
}

/**
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the intent owner.
 * @param {string} id the intent's own document id.
 * @return {FirebaseFirestore.DocumentReference} the intent doc.
 */
function paymentIntentRef(db: Firestore, uid: string, id: string) {
  return db.collection("users").doc(uid).collection("paymentIntents").doc(
    id
  );
}

/**
 * Strips any key whose value is `undefined` from `obj` — Firestore
 * rejects `undefined` outright (`Cannot use "undefined" as a Firestore
 * value`), so an optional field that's genuinely absent (e.g. a
 * `topup` intent's `inspectionId`, or a `housePass` intent's
 * `creditsAmount`) must never be assigned into the object that gets
 * `.set()`, not merely left `undefined` on it. This is the one place
 * that guarantee is enforced, so every optional field on
 * [PaymentIntent] — present or future — gets it for free, rather than
 * relying on each caller to remember.
 * @param {T} obj the candidate document.
 * @return {T} `obj` with every `undefined`-valued key omitted.
 */
function omitUndefined<T extends object>(obj: T): T {
  const result = {} as T;
  for (const key of Object.keys(obj) as Array<keyof T>) {
    if (obj[key] !== undefined) {
      result[key] = obj[key];
    }
  }
  return result;
}

/**
 * Creates (or, on a retried call, returns the existing) payment intent
 * — idempotent via `idempotencyKey`, the same pattern `wallet.ts` uses,
 * so a duplicate-tapped "Top Up" button can never create two intents.
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the intent details.
 * @return {Promise<PaymentIntent>} the created (or pre-existing) intent.
 */
export async function createPaymentIntent(db: Firestore, params: {
  uid: string;
  idempotencyKey: string;
  purpose: PaymentPurpose;
  amountMyr: number;
  creditsAmount?: number;
  inspectionId?: string;
}): Promise<PaymentIntent> {
  const ref = paymentIntentRef(db, params.uid, params.idempotencyKey);
  const existing = await ref.get();
  if (existing.exists) {
    return existing.data() as PaymentIntent;
  }
  const now = Date.now();
  const candidate: PaymentIntent = {
    id: params.idempotencyKey,
    userId: params.uid,
    purpose: params.purpose,
    amountMyr: params.amountMyr,
    creditsAmount: params.creditsAmount,
    inspectionId: params.inspectionId,
    status: "pending",
    createdAt: now,
    updatedAt: now,
  };
  const intent = omitUndefined(candidate);
  await ref.set(intent);
  return intent;
}

/**
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the intent owner.
 * @param {string} id the intent id.
 * @return {Promise<PaymentIntent | null>} the intent, if it exists.
 */
export async function getPaymentIntent(
  db: Firestore,
  uid: string,
  id: string
): Promise<PaymentIntent | null> {
  const snap = await paymentIntentRef(db, uid, id).get();
  return snap.exists ? (snap.data() as PaymentIntent) : null;
}

/**
 * Marks an intent succeeded — a no-op if it's already marked succeeded
 * (idempotent against a replayed confirmation).
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the intent owner.
 * @param {string} id the intent id.
 * @return {Promise<void>} resolves once updated.
 */
export async function markPaymentIntentSucceeded(
  db: Firestore,
  uid: string,
  id: string
): Promise<void> {
  const ref = paymentIntentRef(db, uid, id);
  const snap = await ref.get();
  if (!snap.exists) {
    throw new Error(`Payment intent ${id} not found.`);
  }
  const intent = snap.data() as PaymentIntent;
  if (intent.status === "succeeded") return;
  await ref.set({...intent, status: "succeeded", updatedAt: Date.now()});
}
