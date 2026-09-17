import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import {isHousePassSafeToSell, loadPricingConfig} from "./pricing_config";
import {createPaymentIntent} from "./payment_intent";
import {findHousePassForInspection} from "./house_pass";

/**
 * `purchaseHousePass` — creates a `pending` payment intent for one
 * inspection's House Pass (a fixed RM30 product, never Credits). Like
 * `createTopUpIntent`, this never itself activates the pass; only
 * `handle_confirm_sandbox_payment.ts` (or, later, a real provider's
 * webhook) can do that, once payment is actually confirmed.
 */

export interface PurchaseHousePassRequest {
  inspectionId: string;
  idempotencyKey: string;
}

/**
 * @param {unknown} data the raw callable payload.
 * @return {PurchaseHousePassRequest} the validated request.
 */
export function parsePurchaseHousePassInput(
  data: unknown
): PurchaseHousePassRequest {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError("invalid-argument", "Malformed request.");
  }
  const d = data as Record<string, unknown>;
  if (typeof d.inspectionId !== "string" || d.inspectionId.length === 0) {
    throw new HttpsError("invalid-argument", "inspectionId is required.");
  }
  if (
    typeof d.idempotencyKey !== "string" ||
    d.idempotencyKey.trim().length === 0
  ) {
    throw new HttpsError("invalid-argument", "idempotencyKey is required.");
  }
  return {inspectionId: d.inspectionId, idempotencyKey: d.idempotencyKey};
}

/**
 * @param {Firestore} firestore the Admin Firestore client.
 * @param {string} uid the caller.
 * @param {string} inspectionId the inspection to check.
 * @return {Promise<boolean>} whether the caller owns this inspection.
 */
async function isOwnedInspection(
  firestore: Firestore,
  uid: string,
  inspectionId: string
): Promise<boolean> {
  const snap = await firestore
    .collection("users")
    .doc(uid)
    .collection("inspections")
    .doc(inspectionId)
    .get();
  return snap.exists;
}

/**
 * @param {object} params the request/dependencies.
 * @return {Promise<object>} the created (or pre-existing) intent's
 *   client-facing summary.
 */
export async function handlePurchaseHousePass(params: {
  auth: {uid: string} | null | undefined;
  data: unknown;
  firestore: Firestore;
  env: NodeJS.ProcessEnv;
}): Promise<{intentId: string; priceMyr: number}> {
  const {auth, data, firestore, env} = params;
  if (!auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const uid = auth.uid;
  const req = parsePurchaseHousePassInput(data);

  const owned = await isOwnedInspection(firestore, uid, req.inspectionId);
  if (!owned) {
    throw new HttpsError(
      "permission-denied",
      "That inspection does not belong to you."
    );
  }

  const config = await loadPricingConfig(firestore);
  if (!config.housePass.enabled) {
    throw new HttpsError(
      "failed-precondition",
      "House Pass is not currently available."
    );
  }
  if (!isHousePassSafeToSell(config.housePass, env)) {
    throw new HttpsError(
      "failed-precondition",
      "House Pass is not yet configured for production. An operator " +
        "must set pricing/config.housePass.environment to " +
        "\"production\" with a real allowance before House Pass can " +
        "be sold outside sandbox mode."
    );
  }

  const existing = await findHousePassForInspection(
    firestore,
    uid,
    req.inspectionId
  );
  if (
    existing &&
    (existing.status === "active" || existing.status === "allowanceReached")
  ) {
    throw new HttpsError(
      "already-exists",
      "This inspection already has a House Pass."
    );
  }

  const intent = await createPaymentIntent(firestore, {
    uid,
    idempotencyKey: req.idempotencyKey,
    purpose: "housePass",
    amountMyr: config.housePass.priceMyr,
    inspectionId: req.inspectionId,
  });

  return {intentId: intent.id, priceMyr: intent.amountMyr};
}
