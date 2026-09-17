import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import {loadPricingConfig} from "./pricing_config";
import {myrToCredits} from "./pricing";
import {createPaymentIntent} from "./payment_intent";

/**
 * `createTopUpIntent` — the first step of Top Up: creates a
 * backend-owned, `pending` payment intent for a chosen RM amount before
 * any payment is attempted. Never itself grants Credits — see
 * `handle_confirm_sandbox_payment.ts` for the only path that can.
 */

const MIN_TOPUP_MYR = 1;
const MAX_TOPUP_MYR = 1000;

export interface CreateTopUpIntentRequest {
  amountMyr: number;
  idempotencyKey: string;
}

/**
 * @param {unknown} data the raw callable payload.
 * @return {CreateTopUpIntentRequest} the validated request.
 */
export function parseCreateTopUpIntentInput(
  data: unknown
): CreateTopUpIntentRequest {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError("invalid-argument", "Malformed request.");
  }
  const d = data as Record<string, unknown>;
  if (
    typeof d.amountMyr !== "number" ||
    !Number.isFinite(d.amountMyr) ||
    d.amountMyr < MIN_TOPUP_MYR ||
    d.amountMyr > MAX_TOPUP_MYR
  ) {
    throw new HttpsError(
      "invalid-argument",
      `amountMyr must be between RM${MIN_TOPUP_MYR} and RM${MAX_TOPUP_MYR}.`
    );
  }
  if (
    typeof d.idempotencyKey !== "string" ||
    d.idempotencyKey.trim().length === 0
  ) {
    throw new HttpsError("invalid-argument", "idempotencyKey is required.");
  }
  return {amountMyr: d.amountMyr, idempotencyKey: d.idempotencyKey};
}

/**
 * @param {object} params the request/dependencies.
 * @return {Promise<object>} the created (or pre-existing) intent's
 *   client-facing summary.
 */
export async function handleCreateTopUpIntent(params: {
  auth: {uid: string} | null | undefined;
  data: unknown;
  firestore: Firestore;
}): Promise<{intentId: string; amountMyr: number; creditsAmount: number}> {
  const {auth, data, firestore} = params;
  if (!auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const req = parseCreateTopUpIntentInput(data);
  const config = await loadPricingConfig(firestore);
  const creditsAmount = myrToCredits(req.amountMyr, config);

  const intent = await createPaymentIntent(firestore, {
    uid: auth.uid,
    idempotencyKey: req.idempotencyKey,
    purpose: "topup",
    amountMyr: req.amountMyr,
    creditsAmount,
  });

  return {
    intentId: intent.id,
    amountMyr: intent.amountMyr,
    creditsAmount: intent.creditsAmount ?? creditsAmount,
  };
}
