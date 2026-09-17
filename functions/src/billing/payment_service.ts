import {PaymentIntent} from "./payment_intent";

/**
 * The seam a real Malaysia payment provider slots into later without
 * touching `handle_confirm_sandbox_payment.ts`'s ownership/idempotency
 * logic — see docs/commercial_model.md ("Payment architecture"). A real
 * implementation would call out to the provider's API/webhook payload
 * to independently verify the intent was actually paid; it would never
 * simply trust that it was asked to confirm one.
 */
export interface PaymentConfirmation {
  success: boolean;
  /** The provider's own reference for this payment — stored as the
   * ledger entry's `externalPaymentRef`. */
  providerRef: string;
}

export interface PaymentService {
  readonly id: string;
  confirmPayment(intent: PaymentIntent): Promise<PaymentConfirmation>;
}
