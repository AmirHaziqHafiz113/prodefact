import {PaymentIntent} from "./payment_intent";
import {PaymentConfirmation, PaymentService} from "./payment_service";

/**
 * A fake "always succeeds" payment confirmation — for debug/test mode
 * ONLY. Never wired up unless `resolvePaymentsMode` (checked by the
 * caller, `handle_confirm_sandbox_payment.ts`, before this class is
 * even constructed) resolves to `"sandbox"`, which itself requires an
 * explicit `PAYMENTS_MODE=sandbox` environment variable a production
 * deployment must never set. This class performs no real verification
 * whatsoever — that is the entire point of it being sandbox-only.
 */
export class SandboxPaymentService implements PaymentService {
  readonly id = "sandbox";

  /**
   * @param {PaymentIntent} intent the intent to "confirm".
   * @return {Promise<PaymentConfirmation>} always a success.
   */
  async confirmPayment(intent: PaymentIntent): Promise<PaymentConfirmation> {
    return {success: true, providerRef: `sandbox:${intent.id}`};
  }
}
