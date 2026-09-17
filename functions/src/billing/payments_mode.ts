export type PaymentsMode = "sandbox" | "production";

/**
 * The single switch controlling whether `confirmSandboxPayment` is
 * allowed to run at all. Resolved only from this function's own
 * environment — never from client input, never inferable by the
 * client. Defaults to `"production"` (sandbox confirmation disabled)
 * unless `PAYMENTS_MODE` is explicitly the literal string `"sandbox"`.
 *
 * This is the boundary the spec requires be "impossible to accidentally
 * enable in release mode": a real deployment must never set
 * `PAYMENTS_MODE=sandbox`. See docs/commercial_model.md ("Sandbox vs
 * production") and `handle_confirm_sandbox_payment.test.ts`, which
 * proves this boundary holds.
 * @param {NodeJS.ProcessEnv} env the function's process environment.
 * @return {PaymentsMode} the active payments mode.
 */
export function resolvePaymentsMode(env: NodeJS.ProcessEnv): PaymentsMode {
  return env.PAYMENTS_MODE?.trim().toLowerCase() === "sandbox" ?
    "sandbox" :
    "production";
}
