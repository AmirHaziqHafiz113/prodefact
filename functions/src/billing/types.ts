/**
 * Provider-neutral commercial/billing shapes shared across the billing
 * module and the callables that use it. See docs/commercial_model.md
 * for the full design this implements.
 *
 * "Credits" are the only unit Flutter ever sees or reasons about — a
 * customer-facing abstraction over real money, configured server-side
 * (see `pricing_config.ts`). Flutter never computes a price itself.
 */

/** The three customer-facing AI quality tiers — never a raw model
 * name in front of a normal user (see docs, "AI tiers"). */
export type AiLevel = "fast" | "smart" | "expert";

/**
 * @param {unknown} value the value to check.
 * @return {boolean} whether `value` is a valid customer-facing AI level.
 */
export function isAiLevel(value: unknown): value is AiLevel {
  return value === "fast" || value === "smart" || value === "expert";
}

/** Which commercial mode an inspection is running under — persisted
 * once chosen (see `InspectionSession.commercialMode` on the Flutter
 * side) and never re-derived from the wallet later. */
export type CommercialMode = "flexCredits" | "housePass";

/**
 * @param {unknown} value the value to check.
 * @return {boolean} whether `value` is a valid commercial mode.
 */
export function isCommercialMode(value: unknown): value is CommercialMode {
  return value === "flexCredits" || value === "housePass";
}

/**
 * A single, immutable entry in a user's Credits ledger — the
 * authoritative history behind the cached wallet balance. See
 * `wallet.ts`.
 */
export type WalletTransactionType =
  | "topup"
  | "reservation"
  | "usage"
  | "reservationRelease"
  | "refund"
  | "adjustment"
  | "housePassPurchase";

export type WalletTransactionStatus =
  | "pending"
  | "completed"
  | "failed"
  | "cancelled";

/** `credit` increases the wallet balance; `debit` decreases it. A
 * `reservation` is a `debit` (credits are held), its matching
 * `reservationRelease`/settlement adjustment is a `credit` for any
 * unused portion. */
export type LedgerDirection = "credit" | "debit";

export interface WalletTransaction {
  id: string;
  userId: string;
  type: WalletTransactionType;
  direction: LedgerDirection;
  amountCredits: number;
  status: WalletTransactionStatus;
  createdAt: number;
  updatedAt: number;
  inspectionId?: string;
  findingId?: string;
  aiLevel?: AiLevel;
  /** The reservation transaction this usage/release/refund settles,
   * if any — lets the full lifecycle of one AI job's credits be
   * traced from a single id. */
  relatedTransactionId?: string;
  /** External payment reference (sandbox or a real gateway's own
   * order/intent id) — set only for `topup`/`housePassPurchase`. */
  externalPaymentRef?: string;
  /** The idempotency key the caller supplied — also used as this
   * transaction's own document id, so a retried call can never create
   * a second transaction for the same logical action. */
  idempotencyKey: string;
  description: string;
}

export const WALLET_DOC_ID = "main";

export interface WalletBalance {
  userId: string;
  balanceCredits: number;
  updatedAt: number;
}

export type HousePassStatus =
  | "paymentRequired"
  | "paymentPending"
  | "active"
  | "allowanceReached"
  | "expired"
  | "cancelled";

export interface HousePass {
  id: string;
  inspectionId: string;
  userId: string;
  priceMyr: number;
  currency: "MYR";
  status: HousePassStatus;
  purchasedAt?: number;
  createdAt: number;
  updatedAt: number;
  paymentRef?: string;
  /** Which pricing config version's `housePass` block this pass was
   * purchased/activated under — lets a later config change never
   * silently alter an already-sold pass's allowance. */
  allowanceConfigVersion: number;
  includedAiLevel: AiLevel;
  /** How much of the included allowance has been consumed so far, in
   * the same unit the configured `maxUsagePolicy` uses (see
   * `pricing_config.ts`). */
  allowanceUsed: number;
  allowanceLimit: number;
}

export interface EstimateResult {
  aiLevel: AiLevel;
  estimatedCredits: number;
  maximumCredits: number;
  currentBalance: number;
  paymentMode: CommercialMode;
  includedInHousePass: boolean;
  /** Credits required on top of an active House Pass's included tier
   * (e.g. choosing Expert when the pass only includes Smart) — 0 when
   * the level is fully included or the mode is `flexCredits`. */
  surchargeCredits: number;
  eligible: boolean;
  reason?: string;
}

export interface AnalyseFindingResult {
  aiLevel: AiLevel;
  creditsCharged: number;
  newBalance: number;
  paymentMode: CommercialMode;
  classification: {
    findingId: string;
    catalogueEntryId?: string;
    /** The ONE concrete defect within a multi-defect entry's wording. */
    defectTerm?: string;
    /** False for a photo unrelated to home inspection. */
    isRelevantInspectionImage?: boolean;
    /** False when the photo prevented useful interpretation. */
    imageUsable?: boolean;
    /** Controlled image-quality values (see gateway.ts). */
    qualityIssues?: string[];
    /** What the model saw in the photo (bounded; never in reports). */
    detectedElement?: string;
    detectedComponent?: string;
    /** supports | neutral | contradicts | unclear. */
    noteImageAgreement?: string;
    /** Why the inspector must review (controlled; see gateway.ts). */
    needsReviewReason?: string;
    confidence?: number;
    shortReason?: string;
    candidateEntryIds: string[];
    needsReview: boolean;
  };
}
