import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import {getPaymentIntent, markPaymentIntentSucceeded} from "./payment_intent";
import {resolvePaymentsMode} from "./payments_mode";
import {SandboxPaymentService} from "./sandbox_payment_service";
import {getWalletBalance, recordHousePassPurchase, recordTopUp} from "./wallet";
import {createActiveHousePass} from "./house_pass";
import {loadPricingConfig} from "./pricing_config";
import {myrToCredits} from "./pricing";

/**
 * `confirmSandboxPayment` — the ONLY path in this codebase that can
 * turn a `pending` payment intent into granted Credits or an active
 * House Pass, and only when `resolvePaymentsMode` resolves to
 * `"sandbox"` (an explicit `PAYMENTS_MODE=sandbox` environment
 * variable a real deployment must never set — see
 * `handle_confirm_sandbox_payment.test.ts`). A real payment provider
 * would instead be confirmed from its own verified webhook, never from
 * a client call like this one — see docs/commercial_model.md
 * ("Payment architecture").
 */

export interface ConfirmSandboxPaymentRequest {
  intentId: string;
}

/**
 * @param {unknown} data the raw callable payload.
 * @return {ConfirmSandboxPaymentRequest} the validated request.
 */
export function parseConfirmSandboxPaymentInput(
  data: unknown
): ConfirmSandboxPaymentRequest {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError("invalid-argument", "Malformed request.");
  }
  const d = data as Record<string, unknown>;
  if (typeof d.intentId !== "string" || d.intentId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "intentId is required.");
  }
  return {intentId: d.intentId};
}

/**
 * @param {object} params the request/dependencies.
 * @return {Promise<object>} the confirmed outcome.
 */
export async function handleConfirmSandboxPayment(params: {
  auth: {uid: string} | null | undefined;
  data: unknown;
  firestore: Firestore;
  env: NodeJS.ProcessEnv;
}): Promise<{
  purpose: "topup" | "housePass";
  newBalance: number;
  creditsAdded: number;
}> {
  const {auth, data, firestore, env} = params;
  if (!auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  if (resolvePaymentsMode(env) !== "sandbox") {
    throw new HttpsError(
      "failed-precondition",
      "Sandbox payment confirmation is not enabled in this environment."
    );
  }
  const uid = auth.uid;
  const {intentId} = parseConfirmSandboxPaymentInput(data);

  const intent = await getPaymentIntent(firestore, uid, intentId);
  if (!intent) {
    throw new HttpsError("not-found", "That payment intent does not exist.");
  }
  if (intent.status === "failed") {
    throw new HttpsError(
      "failed-precondition",
      "That payment already failed."
    );
  }

  if (intent.status === "pending") {
    const paymentService = new SandboxPaymentService();
    const confirmation = await paymentService.confirmPayment(intent);
    if (!confirmation.success) {
      throw new HttpsError("aborted", "Payment could not be confirmed.");
    }
    await markPaymentIntentSucceeded(firestore, uid, intentId);

    if (intent.purpose === "topup") {
      await recordTopUp(firestore, {
        uid,
        amountCredits: intent.creditsAmount ?? 0,
        idempotencyKey: intentId,
        externalPaymentRef: confirmation.providerRef,
        // Customer-facing wallet activity must never say "Sandbox" —
        // this same description is what a real user sees in their
        // activity feed even in a sandbox-mode QA/staging deployment.
        description: `Top Up — RM${intent.amountMyr}`,
      });
    } else {
      const config = await loadPricingConfig(firestore);
      const pass = await createActiveHousePass(firestore, {
        uid,
        inspectionId: intent.inspectionId ?? "",
        idempotencyKey: intentId,
        externalPaymentRef: confirmation.providerRef,
        config: config.housePass,
      });
      await recordHousePassPurchase(firestore, {
        uid,
        amountCredits: myrToCredits(intent.amountMyr, config),
        idempotencyKey: `${intentId}_ledger`,
        inspectionId: pass.inspectionId,
        externalPaymentRef: confirmation.providerRef,
        description: `House Pass purchase — RM${intent.amountMyr}`,
      });
    }
  }

  const newBalance = await getWalletBalance(firestore, uid);
  return {
    purpose: intent.purpose,
    newBalance,
    creditsAdded: intent.purpose === "topup" ? (intent.creditsAmount ?? 0) : 0,
  };
}
