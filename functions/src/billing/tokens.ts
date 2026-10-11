/**
 * ProDefact Tokens — the only customer-facing billing unit (replacing
 * "Credits"). See docs/token_billing.md.
 *
 * Denomination: 1,000,000 Tokens = RM1 retail value. Balances run into
 * the millions and hundreds of millions, so every balance and charge is
 * a whole number of Tokens, checked with `Number.isSafeInteger` (exact up
 * to ~9 × 10^15 Tokens ≈ RM9 billion). Costs in RM may be fractional,
 * but they are only ever informational; the integer Token amount is the
 * charge.
 */

/** 1,000,000 Tokens = RM1 retail. Fixed — not operator-configurable,
 * so a Token always means the same money. */
export const TOKENS_PER_MYR = 1_000_000;

/** Credits per RM before the Token switch (`pricing/config`'s old
 * `creditsPerMyr` default). Used only to convert legacy balances. */
export const LEGACY_CREDITS_PER_MYR = 100;

/** Thrown when a Token amount is not a safe, non-negative integer. */
export class InvalidTokenAmountError extends Error {
  /**
   * @param {string} field the offending field.
   * @param {unknown} value the offending value.
   */
  constructor(field: string, value: unknown) {
    super(`${field} must be a safe non-negative integer (got ${value}).`);
    this.name = "InvalidTokenAmountError";
  }
}

/**
 * @param {number} value a candidate Token amount.
 * @param {string} field its name, for the error.
 * @return {number} the value, if it is a safe non-negative integer.
 */
export function assertTokenAmount(value: number, field: string): number {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new InvalidTokenAmountError(field, value);
  }
  return value;
}

/**
 * Retail RM → whole Tokens, rounded UP (a customer charge is never
 * rounded down), after first snapping to a thousandth of a Token so
 * floating-point noise can't add a spurious Token: RM0.009146 is
 * exactly 9,146 Tokens, not 9,147.
 * @param {number} retailRm a retail amount in RM (>= 0).
 * @return {number} whole Tokens.
 */
export function tokensForRetailRm(retailRm: number): number {
  if (!Number.isFinite(retailRm) || retailRm <= 0) return 0;
  const milliTokens = Math.round(retailRm * TOKENS_PER_MYR * 1000);
  return assertTokenAmount(Math.ceil(milliTokens / 1000), "tokens");
}

/**
 * A top-up amount in RM → Tokens (RM10 → 10,000,000).
 * @param {number} amountMyr the RM paid.
 * @return {number} whole Tokens (rounded down — never mint Tokens the
 *   customer didn't pay for; whole-sen amounts are always exact).
 */
export function tokensForTopUpMyr(amountMyr: number): number {
  if (!Number.isFinite(amountMyr) || amountMyr <= 0) return 0;
  const milliTokens = Math.round(amountMyr * TOKENS_PER_MYR * 1000);
  return assertTokenAmount(Math.floor(milliTokens / 1000), "tokens");
}

/**
 * @param {number} legacyCreditsPerMyr the Credits-per-RM rate the legacy
 *   balance was sold at.
 * @return {number} how many Tokens one legacy Credit is worth, keeping
 *   its RM value (100 Credits/RM → 10,000 Tokens per Credit).
 */
export function tokensPerLegacyCredit(legacyCreditsPerMyr: number): number {
  const rate = legacyCreditsPerMyr > 0 ?
    legacyCreditsPerMyr :
    LEGACY_CREDITS_PER_MYR;
  return Math.round(TOKENS_PER_MYR / rate);
}

/**
 * A legacy Credits amount → Tokens of the same RM value.
 * @param {number} credits the legacy Credits.
 * @param {number} legacyCreditsPerMyr the legacy rate.
 * @return {number} whole Tokens.
 */
export function tokensForLegacyCredits(
  credits: number,
  legacyCreditsPerMyr: number
): number {
  if (!Number.isFinite(credits) || credits <= 0) return 0;
  const rate = legacyCreditsPerMyr > 0 ?
    legacyCreditsPerMyr :
    LEGACY_CREDITS_PER_MYR;
  // credits ÷ rate = RM; × 1,000,000 = Tokens. Divided last so a rate
  // that doesn't divide 1,000,000 evenly still converts exactly.
  return assertTokenAmount(
    Math.round((credits * TOKENS_PER_MYR) / rate),
    "legacyTokens"
  );
}
