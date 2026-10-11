import {tokensForRetailRm} from "./tokens";

/**
 * The auditable variable-cost model behind every Token charge. See
 * docs/token_billing.md.
 *
 * Customer price = variable infrastructure cost × `markupMultiplier`.
 * 2.0 is a 100% MARKUP over cost (RM1 cost → RM2 charge), which is a
 * 50% gross margin — never "100% gross margin".
 *
 * Costs come from three kinds of source, each labelled on the usage
 * record so an auditor can tell them apart:
 * - **measured** — observed for this operation (OpenAI tokens reported
 *   by the provider, bytes actually read from Storage, function wall
 *   time);
 * - **estimated** — deterministic per-operation figures (Firestore
 *   reads/writes of the job lifecycle, network bytes to the provider);
 * - **overhead** — one small fixed bucket for logging, monitoring,
 *   Secret Manager and similar platform micro-costs that would be noisy
 *   and fragile to meter one by one.
 */

/** Unit prices, in USD (Google publishes list prices in USD), converted
 * to RM with `usdToMyrRate`. Approximate public list prices — verify
 * against the project's billing region and override via
 * `pricing/config.infrastructureRates`. */
export interface InfrastructureRates {
  storageDownloadPerGbUsd: number;
  storageUploadPerGbUsd: number;
  storageRetainedPerGbMonthUsd: number;
  /** How many months of retention one operation's stored bytes are
   * charged for (a one-off charge; Drive holds the long-term copy). */
  storageRetentionMonthsCharged: number;
  firestoreReadsPer100kUsd: number;
  firestoreWritesPer100kUsd: number;
  firestoreDeletesPer100kUsd: number;
  functionInvocationsPerMillionUsd: number;
  functionVcpuSecondUsd: number;
  functionGibSecondUsd: number;
  functionVcpu: number;
  functionMemoryGib: number;
  networkEgressPerGbUsd: number;
  /** Image normalisation / thumbnail generation, per image. */
  imageProcessingPerImageUsd: number;
  /** PDF generation, per report (0 while reports render on-device). */
  pdfGenerationPerReportUsd: number;
  /** Logging, monitoring, Secret Manager and other platform overhead,
   * per operation. */
  overheadPerOperationUsd: number;
}

export const DEFAULT_INFRASTRUCTURE_RATES: InfrastructureRates = {
  storageDownloadPerGbUsd: 0.12,
  storageUploadPerGbUsd: 0,
  storageRetainedPerGbMonthUsd: 0.026,
  storageRetentionMonthsCharged: 1,
  firestoreReadsPer100kUsd: 0.06,
  firestoreWritesPer100kUsd: 0.18,
  firestoreDeletesPer100kUsd: 0.02,
  functionInvocationsPerMillionUsd: 0.4,
  functionVcpuSecondUsd: 0.000024,
  functionGibSecondUsd: 0.0000025,
  functionVcpu: 1,
  functionMemoryGib: 1,
  networkEgressPerGbUsd: 0.12,
  imageProcessingPerImageUsd: 0,
  pdfGenerationPerReportUsd: 0,
  overheadPerOperationUsd: 0.00002,
};

export type UsageOperationType =
  | "aiAnalysis"
  | "storage"
  | "pdfGeneration"
  | "other";

/** What one operation consumed. Absent numbers count as zero. */
export interface OperationUsage {
  openaiModel?: string;
  /** Provider-reported tokens; absent when the provider reported none. */
  openaiInputTokens?: number;
  openaiOutputTokens?: number;
  /** USD per 1,000 tokens, from the same config billing always used. */
  openaiInputPerKUsd?: number;
  openaiOutputPerKUsd?: number;
  storageUploadBytes?: number;
  storageDownloadBytes?: number;
  storageRetainedBytes?: number;
  firestoreReads?: number;
  firestoreWrites?: number;
  firestoreDeletes?: number;
  functionInvocations?: number;
  functionDurationMs?: number;
  networkBytes?: number;
  imagesProcessed?: number;
  pdfReports?: number;
  /** Which figures were measured vs estimated — stored for audit. */
  measurement?: Record<string, "measured" | "estimated" | "unavailable">;
}

export interface CostBreakdownRm {
  aiAnalysis: number;
  storage: number;
  processing: number;
  other: number;
}

export interface OperationCost {
  openaiCostRm: number;
  infrastructureCostRm: number;
  variableCostRm: number;
  markupMultiplier: number;
  retailCostRm: number;
  tokensCharged: number;
  /** Variable cost by user-facing category (RM). */
  costByCategoryRm: CostBreakdownRm;
  /** `tokensCharged` split by category; always sums exactly to it. */
  tokensByCategory: CostBreakdownRm;
}

const GB = 1_000_000_000;

/**
 * @param {number | undefined} v a possibly-absent count.
 * @return {number} it, or 0 when absent/invalid/negative.
 */
function n(v: number | undefined): number {
  return typeof v === "number" && Number.isFinite(v) && v > 0 ? v : 0;
}

/**
 * @param {number} value a cost.
 * @return {number} rounded to 9 decimals, so stored informational RM
 *   figures don't carry binary noise.
 */
function round9(value: number): number {
  return Math.round(value * 1e9) / 1e9;
}

/**
 * Splits [total] whole Tokens across categories in proportion to
 * [weights] using the largest-remainder method, so the parts are whole
 * numbers that always add back up to [total].
 * @param {number} total whole Tokens to split.
 * @param {CostBreakdownRm} weights the per-category weights.
 * @return {CostBreakdownRm} whole Tokens per category.
 */
export function splitTokens(
  total: number,
  weights: CostBreakdownRm
): CostBreakdownRm {
  const keys = ["aiAnalysis", "storage", "processing", "other"] as const;
  const sum = keys.reduce((s, k) => s + weights[k], 0);
  const result: CostBreakdownRm = {
    aiAnalysis: 0,
    storage: 0,
    processing: 0,
    other: 0,
  };
  if (total <= 0) return result;
  if (sum <= 0) {
    result.other = total;
    return result;
  }
  const exact = keys.map((k) => (weights[k] / sum) * total);
  const floors = exact.map((x) => Math.floor(x));
  let remaining = total - floors.reduce((s, x) => s + x, 0);
  const order = keys
    .map((k, i) => ({i, frac: exact[i] - floors[i]}))
    .sort((a, b) => b.frac - a.frac || a.i - b.i);
  for (const {i} of order) {
    if (remaining <= 0) break;
    floors[i] += 1;
    remaining -= 1;
  }
  keys.forEach((k, i) => (result[k] = floors[i]));
  return result;
}

/**
 * Prices one operation: variable cost (RM) from its usage, then the
 * retail price with the markup, then whole Tokens.
 * @param {OperationUsage} usage what the operation consumed.
 * @param {object} config the rates, FX rate and markup.
 * @return {OperationCost} the auditable cost and charge.
 */
export function computeOperationCost(
  usage: OperationUsage,
  config: {
    rates: InfrastructureRates;
    usdToMyrRate: number;
    markupMultiplier: number;
  }
): OperationCost {
  const r = config.rates;
  const fx = config.usdToMyrRate > 0 ? config.usdToMyrRate : 1;

  const openaiUsd =
    (n(usage.openaiInputTokens) / 1000) * n(usage.openaiInputPerKUsd) +
    (n(usage.openaiOutputTokens) / 1000) * n(usage.openaiOutputPerKUsd);

  const storageUsd =
    (n(usage.storageDownloadBytes) / GB) * r.storageDownloadPerGbUsd +
    (n(usage.storageUploadBytes) / GB) * r.storageUploadPerGbUsd +
    (n(usage.storageRetainedBytes) / GB) *
      r.storageRetainedPerGbMonthUsd * r.storageRetentionMonthsCharged;

  const seconds = n(usage.functionDurationMs) / 1000;
  const processingUsd =
    (n(usage.functionInvocations) / 1_000_000) *
      r.functionInvocationsPerMillionUsd +
    seconds * r.functionVcpu * r.functionVcpuSecondUsd +
    seconds * r.functionMemoryGib * r.functionGibSecondUsd +
    n(usage.imagesProcessed) * r.imageProcessingPerImageUsd +
    n(usage.pdfReports) * r.pdfGenerationPerReportUsd;

  const otherUsd =
    (n(usage.firestoreReads) / 100_000) * r.firestoreReadsPer100kUsd +
    (n(usage.firestoreWrites) / 100_000) * r.firestoreWritesPer100kUsd +
    (n(usage.firestoreDeletes) / 100_000) * r.firestoreDeletesPer100kUsd +
    (n(usage.networkBytes) / GB) * r.networkEgressPerGbUsd +
    r.overheadPerOperationUsd;

  const costByCategoryRm: CostBreakdownRm = {
    aiAnalysis: round9(openaiUsd * fx),
    storage: round9(storageUsd * fx),
    processing: round9(processingUsd * fx),
    other: round9(otherUsd * fx),
  };
  const openaiCostRm = costByCategoryRm.aiAnalysis;
  const infrastructureCostRm = round9(
    costByCategoryRm.storage + costByCategoryRm.processing +
      costByCategoryRm.other
  );
  const variableCostRm = round9(openaiCostRm + infrastructureCostRm);
  const retailCostRm = round9(variableCostRm * config.markupMultiplier);
  const tokensCharged = tokensForRetailRm(retailCostRm);
  return {
    openaiCostRm,
    infrastructureCostRm,
    variableCostRm,
    markupMultiplier: config.markupMultiplier,
    retailCostRm,
    tokensCharged,
    costByCategoryRm,
    tokensByCategory: splitTokens(tokensCharged, costByCategoryRm),
  };
}

/**
 * The Firestore operations of one `analyseFinding` job's lifecycle
 * (claim, pricing reads, reservation, stage advances, settlement, usage
 * record) — a deterministic estimate, not a meter.
 */
export const ANALYSE_FINDING_FIRESTORE_OPS = {
  reads: 16,
  writes: 12,
  deletes: 0,
};

/** Conservative per-analysis figures used to price the worst case
 * before the provider runs (the reservation). */
export const ANALYSE_FINDING_WORST_CASE = {
  storageDownloadBytes: 4 * 4_000_000,
  storageRetainedBytes: 4_000_000,
  networkBytes: 4 * 1_500_000,
  functionDurationMs: 120_000,
  imagesProcessed: 4,
};

/** One immutable entry in `users/{uid}/usageRecords/{usageId}` — the
 * cost audit trail behind a Token charge. `usageId` is the operation's
 * idempotency key, so one operation can only ever be recorded (and
 * charged) once. */
export interface UsageRecord {
  usageId: string;
  userId: string;
  inspectionId?: string;
  findingId?: string;
  operationType: UsageOperationType;
  openaiModel?: string;
  openaiInputTokens: number;
  openaiOutputTokens: number;
  openaiCostRm: number;
  storageUploadBytes: number;
  storageDownloadBytes: number;
  storageRetainedBytes: number;
  firestoreReads: number;
  firestoreWrites: number;
  firestoreDeletes: number;
  functionDurationMs: number;
  networkBytes: number;
  infrastructureCostRm: number;
  markupMultiplier: number;
  retailCostRm: number;
  /** What the customer was actually charged — may be below the
   * computed retail price (capped at what they approved) and is 0 for an
   * analysis fully included in a House Pass. */
  tokensCharged: number;
  /** The computed price before any cap/inclusion. */
  tokensComputed: number;
  tokensByCategory: CostBreakdownRm;
  measurement: Record<string, string>;
  usdToMyrRate: number;
  pricingVersion: number;
  createdAt: number;
}

/**
 * Builds the usage record for one priced operation.
 * @param {object} params the operation, its usage, cost and the charge.
 * @return {UsageRecord} the record (no undefined fields).
 */
export function buildUsageRecord(params: {
  usageId: string;
  userId: string;
  inspectionId?: string;
  findingId?: string;
  operationType: UsageOperationType;
  usage: OperationUsage;
  cost: OperationCost;
  tokensCharged: number;
  usdToMyrRate: number;
  pricingVersion: number;
  now: number;
}): UsageRecord {
  const u = params.usage;
  const record: UsageRecord = {
    usageId: params.usageId,
    userId: params.userId,
    operationType: params.operationType,
    openaiInputTokens: n(u.openaiInputTokens),
    openaiOutputTokens: n(u.openaiOutputTokens),
    openaiCostRm: params.cost.openaiCostRm,
    storageUploadBytes: n(u.storageUploadBytes),
    storageDownloadBytes: n(u.storageDownloadBytes),
    storageRetainedBytes: n(u.storageRetainedBytes),
    firestoreReads: n(u.firestoreReads),
    firestoreWrites: n(u.firestoreWrites),
    firestoreDeletes: n(u.firestoreDeletes),
    functionDurationMs: Math.round(n(u.functionDurationMs)),
    networkBytes: n(u.networkBytes),
    infrastructureCostRm: params.cost.infrastructureCostRm,
    markupMultiplier: params.cost.markupMultiplier,
    retailCostRm: params.cost.retailCostRm,
    tokensCharged: params.tokensCharged,
    tokensComputed: params.cost.tokensCharged,
    tokensByCategory: splitTokens(
      params.tokensCharged,
      params.cost.costByCategoryRm
    ),
    measurement: {...(u.measurement ?? {})},
    usdToMyrRate: params.usdToMyrRate,
    pricingVersion: params.pricingVersion,
    createdAt: params.now,
  };
  if (params.inspectionId) record.inspectionId = params.inspectionId;
  if (params.findingId) record.findingId = params.findingId;
  if (u.openaiModel) record.openaiModel = u.openaiModel;
  return record;
}
