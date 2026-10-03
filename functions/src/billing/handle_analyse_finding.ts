import {randomUUID} from "node:crypto";
import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";
import {AiProviderError} from "../ai/provider";
import {ClassificationResult, ClassifyFindingInput} from "../ai/types";
import {parseClassifyFindingInput} from "../ai/validation";
import {resolveFindingEvidence} from "../ai/evidence";
import {
  createProvider,
  SupportedProviderId,
  validateAndNormalize,
} from "../ai/gateway";
import {AiLevelConfig, loadPricingConfig} from "./pricing_config";
import {actualCreditsForUsage, providerCostForTokensUsd} from "./pricing";
import {
  getWalletBalance,
  InsufficientCreditsError,
  releaseReservation,
  reserveCredits,
  settleReservation,
} from "./wallet";
import {findHousePassForInspection, recordHousePassUsage} from "./house_pass";
import {
  computeEstimate,
  isOwnedFinding,
} from "./handle_estimate_finding_analysis";
import {
  AiLevel,
  AnalyseFindingResult,
  CommercialMode,
  isAiLevel,
} from "./types";

/**
 * `analyseFinding` — the priced AI-classification callable. Runs only
 * after the inspector has already seen and approved the estimate from
 * `estimateFindingAnalysis`; see docs/commercial_model.md
 * ("Reservation before AI") for the full reserve -> idempotent job ->
 * settle/release protocol this implements.
 *
 * Every request is keyed by the client's `idempotencyKey`, and the job
 * document at `users/{uid}/aiJobs/{idempotencyKey}` is the backend's
 * authoritative record of that analysis:
 *
 * 1. An invocation first *claims* the job in a transaction. Only the
 *    claimant may do any work, and the claim is a lease: another
 *    invocation of the same key is refused while the lease is live, so
 *    the AI provider can never run twice concurrently for one key.
 * 2. The claimant then advances the job through durable stages —
 *    `claimed` -> `priced` -> `reserved` -> `providerCompleted` ->
 *    `settled` — writing each one (with the data the next stage needs:
 *    the pricing decision, the reservation id, the provider's result,
 *    the exact charge) before starting the next.
 * 3. If an invocation dies part-way, the lease expires and a replay of
 *    the same key takes over and resumes from the last durable stage —
 *    it never re-prices after pricing, never calls the provider again
 *    once a result is stored, and never refunds after settling.
 * 4. The job ends as `succeeded` (stored result, returned to every later
 *    replay without charging) or `failed` (nothing charged).
 *
 * Every Credits ledger mutation is also keyed (`{key}_reservation`,
 * `{key}_settlement`, `{key}_release_failed`), settlement and the
 * failure-release are mutually exclusive, and House Pass allowance is
 * consumed once per key — so even a replay racing an unexpected crash
 * cannot reserve, charge, refund, or consume allowance twice.
 */

/**
 * How long one invocation owns a job before a replay may take it over.
 * Longer than this function's own `timeoutSeconds` (180, `index.ts`),
 * so a live invocation never loses its claim; shorter than the client's
 * replay window (4 minutes, `AiAnalysisAttempt.replaySafeAfter` in
 * Flutter), so a replay arriving after that window can take over.
 */
export const AI_JOB_LEASE_MS = 200_000;

const MAX_IDEMPOTENCY_KEY_LENGTH = 200;

export interface AnalyseFindingRequest {
  input: ClassifyFindingInput;
  aiLevel: AiLevel;
  idempotencyKey: string;
}

/**
 * @param {unknown} data the raw callable payload.
 * @return {AnalyseFindingRequest} the validated request.
 */
export function parseAnalyseFindingInput(
  data: unknown
): AnalyseFindingRequest {
  // Also validates `data` is a non-null object — safe to cast below.
  const input = parseClassifyFindingInput(data);
  const d = data as Record<string, unknown>;
  if (!isAiLevel(d.aiLevel)) {
    throw new HttpsError(
      "invalid-argument",
      "aiLevel must be fast/smart/expert."
    );
  }
  if (
    typeof d.idempotencyKey !== "string" ||
    d.idempotencyKey.trim().length === 0
  ) {
    throw new HttpsError("invalid-argument", "idempotencyKey is required.");
  }
  if (d.idempotencyKey.length > MAX_IDEMPOTENCY_KEY_LENGTH) {
    throw new HttpsError("invalid-argument", "idempotencyKey is too long.");
  }
  return {input, aiLevel: d.aiLevel, idempotencyKey: d.idempotencyKey};
}

/** The backend-owned lifecycle of one analysis job. */
type AiJobStatus = "in_progress" | "succeeded" | "failed";

/**
 * Durable progress of an `in_progress` job — the last step whose result
 * is safely stored, i.e. where a takeover resumes.
 */
type AiJobStage =
  | "claimed"
  | "priced"
  | "reserved"
  | "providerCompleted"
  | "settled";

/**
 * The authoritative record of one `analyseFinding` job, keyed by the
 * client's idempotency key. Jobs stored before this lifecycle existed
 * have only `status: "succeeded" | "failed"` plus the result fields,
 * which this schema still reads unchanged.
 */
interface AiJobRecord {
  id: string;
  userId: string;
  inspectionId: string;
  findingId: string;
  aiLevel: AiLevel;
  status: AiJobStatus;
  stage?: AiJobStage;
  /** The invocation currently allowed to advance this job. */
  claimId?: string;
  /** Epoch ms after which another invocation may take the job over. */
  leaseExpiresAt?: number;
  /** How many invocations have claimed this job (1 unless taken over). */
  claimCount?: number;
  paymentMode?: CommercialMode;
  /** Credits to hold; 0 for a House Pass analysis fully included. */
  reservationAmount?: number;
  /** The reservation ledger entry, when `reservationAmount > 0`. */
  reservationId?: string;
  /** The inspection's House Pass, when `paymentMode` is `housePass`. */
  housePassId?: string;
  classification?: ClassificationResult;
  /** The usage-based charge, fixed once the provider has answered. */
  actualCredits?: number;
  providerCompletedAt?: number;
  // Per-finding AI usage for analytics (never shown to inspectors).
  // Token fields are absent when the provider reported no usage.
  model?: string;
  usageAvailable?: boolean;
  inputTokens?: number;
  outputTokens?: number;
  totalTokens?: number;
  /** Raw provider cost from the same pricing config billing uses. */
  providerCostUsd?: number;
  providerDurationMs?: number;
  settledAt?: number;
  housePassUsageRecorded?: boolean;
  creditsCharged: number;
  failureReason?: string;
  createdAt: number;
  updatedAt: number;
}

/**
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the job owner.
 * @param {string} idempotencyKey the job's own document id.
 * @return {FirebaseFirestore.DocumentReference} the job doc.
 */
function aiJobRef(db: Firestore, uid: string, idempotencyKey: string) {
  return db.collection("users").doc(uid).collection("aiJobs").doc(
    idempotencyKey
  );
}

/**
 * Firestore rejects `undefined` field values anywhere in a document —
 * nested maps included — and a job record's optional fields are often
 * unset. Before 2026-10-02 only top-level fields were stripped, so a
 * stored classification with an unset field (every needsReview answer
 * has no `catalogueEntryId`; a model may omit `confidence`) made the
 * write throw: the job was never finalised, the app parked the finding
 * as queued, and its replay failed the same way.
 * @param {AiJobRecord} job a job record.
 * @return {AiJobRecord} the same record without undefined fields.
 */
function withoutUndefined(job: AiJobRecord): AiJobRecord {
  return stripUndefined(job) as unknown as AiJobRecord;
}

/**
 * @param {unknown} value any value.
 * @return {unknown} the value with undefined fields removed from it and
 *   from every nested plain object (arrays are kept as they are).
 */
function stripUndefined(value: unknown): unknown {
  if (
    value === null ||
    typeof value !== "object" ||
    Object.getPrototypeOf(value) !== Object.prototype
  ) {
    return value;
  }
  const result = {} as Record<string, unknown>;
  for (const [key, field] of Object.entries(value)) {
    if (field !== undefined) result[key] = stripUndefined(field);
  }
  return result;
}

/**
 * Raised when this invocation no longer owns the job it was advancing
 * (its lease was taken over). It must stop without touching the job.
 */
class LostJobClaimError extends Error {
  /** */
  constructor() {
    super("This invocation no longer owns the AI job.");
    this.name = "LostJobClaimError";
  }
}

/**
 * The response for a replay that arrives while another invocation owns
 * the job. `unavailable` is an unknown-outcome code for the Flutter
 * client (`analyseFindingOutcomeUnknownForCode`), so it keeps the same
 * idempotency key and replays later instead of starting a new,
 * separately charged analysis.
 * @param {number} [retryAfterMs] when the current claim expires.
 * @return {HttpsError} the error to throw.
 */
function analysisInProgressError(retryAfterMs?: number): HttpsError {
  return new HttpsError(
    "unavailable",
    "This AI analysis is still being processed. Please check back " +
      "shortly. You will not be charged twice.",
    {reason: "analysisInProgress", retryAfterMs: retryAfterMs ?? null}
  );
}

/**
 * @param {AiJobRecord} job a stored job outcome.
 * @param {number} newBalance the caller's current wallet balance.
 * @return {AnalyseFindingResult} the callable's response shape.
 */
function toResult(
  job: AiJobRecord,
  newBalance: number
): AnalyseFindingResult {
  if (job.status !== "succeeded" || !job.classification || !job.paymentMode) {
    // A replay of a call that failed last time — the AI job is never
    // silently retried on the client's behalf; a genuine retry means
    // the app sends a new idempotencyKey.
    throw new HttpsError(
      "internal",
      "That AI analysis failed previously. Please retry."
    );
  }
  return {
    aiLevel: job.aiLevel,
    creditsCharged: job.creditsCharged,
    newBalance,
    paymentMode: job.paymentMode,
    classification: {
      findingId: job.classification.findingId,
      catalogueEntryId: job.classification.catalogueEntryId,
      defectTerm: job.classification.defectTerm,
      confidence: job.classification.confidence,
      shortReason: job.classification.shortReason,
      candidateEntryIds: job.classification.candidateEntryIds ?? [],
      needsReview: job.classification.needsReview,
    },
  };
}

type ClaimOutcome =
  | {kind: "claimed"; job: AiJobRecord}
  | {kind: "succeeded"; job: AiJobRecord}
  | {kind: "failed"; job: AiJobRecord}
  | {kind: "inProgress"; job: AiJobRecord};

/**
 * Atomically establishes which invocation may work on a job: creates it
 * if absent, takes it over if its previous owner's lease has expired,
 * and otherwise reports its settled or in-progress state untouched.
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the claim details.
 * @return {Promise<ClaimOutcome>} the claim result.
 */
export async function claimAiJob(
  db: Firestore,
  params: {
    uid: string;
    idempotencyKey: string;
    inspectionId: string;
    findingId: string;
    aiLevel: AiLevel;
    claimId: string;
    now: number;
  }
): Promise<ClaimOutcome> {
  const ref = aiJobRef(db, params.uid, params.idempotencyKey);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      const job: AiJobRecord = {
        id: params.idempotencyKey,
        userId: params.uid,
        inspectionId: params.inspectionId,
        findingId: params.findingId,
        aiLevel: params.aiLevel,
        status: "in_progress",
        stage: "claimed",
        claimId: params.claimId,
        leaseExpiresAt: params.now + AI_JOB_LEASE_MS,
        claimCount: 1,
        creditsCharged: 0,
        createdAt: params.now,
        updatedAt: params.now,
      };
      tx.set(ref, job);
      return {kind: "claimed", job};
    }

    const job = snap.data() as AiJobRecord;
    if (
      job.inspectionId !== params.inspectionId ||
      job.findingId !== params.findingId
    ) {
      throw new HttpsError(
        "invalid-argument",
        "That idempotencyKey belongs to a different analysis."
      );
    }
    if (job.status === "succeeded") return {kind: "succeeded", job};
    if (job.status === "failed") return {kind: "failed", job};
    if ((job.leaseExpiresAt ?? 0) > params.now) {
      return {kind: "inProgress", job};
    }

    // The previous owner's lease ran out: that invocation is over (its
    // own timeout is shorter than the lease). Resume from its last
    // durable stage.
    const taken = withoutUndefined({
      ...job,
      claimId: params.claimId,
      leaseExpiresAt: params.now + AI_JOB_LEASE_MS,
      claimCount: (job.claimCount ?? 1) + 1,
      updatedAt: params.now,
    });
    tx.set(ref, taken);
    return {kind: "claimed", job: taken};
  });
}

/**
 * Durably applies [patch] to a job this invocation still owns.
 * @param {Firestore} db the Admin Firestore client.
 * @param {FirebaseFirestore.DocumentReference} ref the job doc.
 * @param {string} claimId this invocation's claim.
 * @param {Partial<AiJobRecord>} patch the fields to change.
 * @return {Promise<AiJobRecord>} the updated job.
 */
async function advanceJob(
  db: Firestore,
  ref: FirebaseFirestore.DocumentReference,
  claimId: string,
  patch: Partial<AiJobRecord>
): Promise<AiJobRecord> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const job = snap.data() as AiJobRecord | undefined;
    if (!snap.exists || !job || job.status !== "in_progress" ||
      job.claimId !== claimId) {
      throw new LostJobClaimError();
    }
    const updated = withoutUndefined({...job, ...patch, updatedAt: Date.now()});
    tx.set(ref, updated);
    return updated;
  });
}

/**
 * After an unexpected error, lets a replay take over immediately rather
 * than waiting out the lease. Best effort: if this fails, the lease
 * still expires on its own.
 * @param {Firestore} db the Admin Firestore client.
 * @param {FirebaseFirestore.DocumentReference} ref the job doc.
 * @param {string} claimId this invocation's claim.
 */
async function releaseJobLease(
  db: Firestore,
  ref: FirebaseFirestore.DocumentReference,
  claimId: string
): Promise<void> {
  try {
    await advanceJob(db, ref, claimId, {leaseExpiresAt: 0});
  } catch {
    // The lease expires by itself.
  }
}

/**
 * @param {object} params the request/dependencies.
 * @return {Promise<AnalyseFindingResult>} the classification plus what
 *   it actually cost.
 */
export async function handleAnalyseFinding(params: {
  auth: {uid: string} | null | undefined;
  data: unknown;
  firestore: Firestore;
  storage: Storage;
  /** Provider API keys, keyed by `AiLevelConfig.provider` — never a
   * secret value hardcoded here; the caller (`index.ts`) supplies these
   * from Secret Manager. A provider with no key configured fails this
   * request with `failed-precondition` rather than throwing an opaque
   * error deep inside the gateway. */
  apiKeys: {openai?: string; deepseek?: string};
  /** Test seam; defaults to the wall clock. */
  now?: () => number;
}): Promise<AnalyseFindingResult> {
  const {auth, data, firestore, storage, apiKeys} = params;
  const now = params.now ?? Date.now;
  if (!auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const uid = auth.uid;
  const {input, aiLevel, idempotencyKey} = parseAnalyseFindingInput(data);

  const owned = await isOwnedFinding(firestore, uid, {
    inspectionId: input.inspectionId,
    findingId: input.findingId,
    aiLevel,
  });
  if (!owned) {
    throw new HttpsError(
      "permission-denied",
      "That finding does not belong to you."
    );
  }

  const config = await loadPricingConfig(firestore);
  const apiKeyFor = (level: AiLevel) =>
    config.aiLevels[level].provider === "openai" ?
      apiKeys.openai :
      apiKeys.deepseek;
  if (!apiKeyFor(aiLevel)) {
    throw new HttpsError(
      "failed-precondition",
      "AI analysis is temporarily unavailable. Please try again later."
    );
  }

  const claimId = randomUUID();
  const claim = await claimAiJob(firestore, {
    uid,
    idempotencyKey,
    inspectionId: input.inspectionId,
    findingId: input.findingId,
    aiLevel,
    claimId,
    now: now(),
  });
  switch (claim.kind) {
  case "succeeded":
    console.info("ai_job_replayed", {idempotencyKey, status: "succeeded"});
    return toResult(claim.job, await getWalletBalance(firestore, uid));
  case "failed":
    return toResult(claim.job, 0);
  case "inProgress":
    console.info("ai_job_in_progress", {idempotencyKey});
    throw analysisInProgressError(
      Math.max(0, (claim.job.leaseExpiresAt ?? 0) - now())
    );
  case "claimed":
    break;
  }
  console.info("ai_job_claimed", {
    idempotencyKey,
    stage: claim.job.stage,
    claimCount: claim.job.claimCount,
  });

  const jobRef = aiJobRef(firestore, uid, idempotencyKey);
  try {
    return await runClaimedJob({
      firestore,
      storage,
      uid,
      input,
      idempotencyKey,
      claimId,
      jobRef,
      job: claim.job,
      config,
      apiKey: apiKeyFor(claim.job.aiLevel),
    });
  } catch (error) {
    if (error instanceof LostJobClaimError) {
      throw analysisInProgressError();
    }
    if (error instanceof HttpsError) throw error;
    // Anything else happened after the claim, possibly after Credits
    // were reserved or settled. The job stays `in_progress` at its last
    // durable stage, so a replay of this same key reconciles it rather
    // than the client starting a new, separately charged analysis.
    console.error("ai_job_not_finalised", {
      idempotencyKey,
      message: error instanceof Error ? error.message : "unknown error",
    });
    await releaseJobLease(firestore, jobRef, claimId);
    throw new HttpsError(
      "unavailable",
      "AI analysis could not be finalised right now. Please retry. You " +
        "will not be charged twice.",
      {reason: "analysisNotFinalised"}
    );
  }
}

/**
 * The per-request usage facts logged and stored on the job. Cost comes
 * from the same pricing config (and `providerCostForTokensUsd`) as the
 * Credits charge, never from separate hard-coded prices. Without a
 * provider usage report nothing is invented: only `usageAvailable:
 * false` is recorded.
 * @param {object} params the provider's usage, the level's pricing, and
 *   the request duration.
 * @return {object} the fields to log and store.
 */
export function providerUsageRecord(params: {
  usage: {inputTokens: number; outputTokens: number} | undefined;
  levelConfig: AiLevelConfig;
  providerDurationMs: number;
}): {
  model: string;
  usageAvailable: boolean;
  inputTokens?: number;
  outputTokens?: number;
  totalTokens?: number;
  providerCostUsd?: number;
  providerDurationMs: number;
} {
  const {usage, levelConfig, providerDurationMs} = params;
  if (!usage) {
    return {model: levelConfig.model, usageAvailable: false,
      providerDurationMs};
  }
  return {
    model: levelConfig.model,
    usageAvailable: true,
    inputTokens: usage.inputTokens,
    outputTokens: usage.outputTokens,
    totalTokens: usage.inputTokens + usage.outputTokens,
    providerCostUsd: providerCostForTokensUsd(
      usage.inputTokens,
      usage.outputTokens,
      levelConfig
    ),
    providerDurationMs,
  };
}

/**
 * The response for a provider failure. The job is already recorded as
 * failed and its Credits released, so the outcome is definite: every
 * code used here is one the app treats as final (it shows "failed" with
 * Retry at once). `deadline-exceeded` is deliberately never used — the
 * app reads that as "outcome unknown" (its own call timing out) and
 * would park the finding as queued for minutes before re-checking.
 * @param {unknown} error the provider error.
 * @return {HttpsError} the error to throw to the app.
 */
function providerFailureError(error: unknown): HttpsError {
  const kind = error instanceof AiProviderError ?
    error.detail.kind ??
      (error.message.includes("transient") ? "unavailable" : "rejected") :
    "rejected";
  switch (kind) {
  case "quotaExceeded":
    return new HttpsError(
      "resource-exhausted",
      "AI analysis is unavailable right now. You have not been charged. " +
        "Please try again later or classify manually.",
      {reason: "providerQuotaExceeded", retryable: false}
    );
  case "rateLimited":
    return new HttpsError(
      "resource-exhausted",
      "AI is busy right now. You have not been charged. Please retry " +
        "in a moment or classify manually.",
      {reason: "providerRateLimited", retryable: true}
    );
  case "unavailable":
    return new HttpsError(
      "internal",
      "AI analysis timed out. You have not been charged. Please retry " +
        "or classify manually.",
      {reason: "providerUnavailable", retryable: true}
    );
  default:
    return new HttpsError(
      "internal",
      "AI analysis failed. You have not been charged. Please retry or " +
        "classify manually.",
      {reason: "providerRejected", retryable: true}
    );
  }
}

/**
 * Advances a claimed job from its current durable stage to a final
 * state. Each stage is written before the next begins, so a takeover
 * after a crash resumes exactly where this left off.
 * @param {object} params the claimed job and its dependencies.
 * @return {Promise<AnalyseFindingResult>} the final result.
 */
async function runClaimedJob(params: {
  firestore: Firestore;
  storage: Storage;
  uid: string;
  input: ClassifyFindingInput;
  idempotencyKey: string;
  claimId: string;
  jobRef: FirebaseFirestore.DocumentReference;
  job: AiJobRecord;
  config: Awaited<ReturnType<typeof loadPricingConfig>>;
  apiKey: string | undefined;
}): Promise<AnalyseFindingResult> {
  const {firestore, storage, uid, input, idempotencyKey, claimId, jobRef} =
    params;
  let job = params.job;
  const aiLevel = job.aiLevel;
  const levelConfig = params.config.aiLevels[aiLevel];
  const advance = (patch: Partial<AiJobRecord>) =>
    advanceJob(firestore, jobRef, claimId, patch);
  const failDefinitively = async (reason: string) => {
    job = await advance({
      status: "failed",
      creditsCharged: 0,
      failureReason: reason,
      leaseExpiresAt: 0,
    });
    console.info("ai_job_failed", {idempotencyKey, reason});
  };
  const ineligibleError = (reason?: string) =>
    new HttpsError(
      "failed-precondition",
      reason === "housePass" ?
        "This House Pass can't be used for this analysis right now." :
        "You don't have enough Credits for this analysis."
    );

  if (job.stage === "claimed") {
    // Re-price authoritatively, immediately before spending anything —
    // never trusts the estimate the client saw earlier, which may be
    // stale (see docs/commercial_model.md, "offline behavior"). Only
    // ever done once per job: after this the pricing decision is stored.
    const estimate = await computeEstimate(firestore, uid, {
      inspectionId: input.inspectionId,
      findingId: input.findingId,
      aiLevel,
    });
    if (!estimate.eligible) {
      await failDefinitively("ineligible");
      throw ineligibleError(
        estimate.reason === "insufficientCredits" ? undefined : "housePass"
      );
    }
    // House Pass reserves only the surcharge (0 when the level is fully
    // included); Flex Credits always reserves the full worst-case amount.
    const reservationAmount = estimate.paymentMode === "housePass" ?
      estimate.surchargeCredits :
      estimate.maximumCredits;
    const pass = estimate.paymentMode === "housePass" ?
      await findHousePassForInspection(firestore, uid, input.inspectionId) :
      null;
    job = await advance({
      stage: "priced",
      paymentMode: estimate.paymentMode,
      reservationAmount,
      housePassId: pass?.id,
    });
  }

  if (job.stage === "priced") {
    const reservationAmount = job.reservationAmount ?? 0;
    let reservationId: string | undefined;
    if (reservationAmount > 0) {
      try {
        const reservation = await reserveCredits(firestore, {
          uid,
          amountCredits: reservationAmount,
          idempotencyKey: `${idempotencyKey}_reservation`,
          inspectionId: input.inspectionId,
          findingId: input.findingId,
          aiLevel,
          description: `AI Analysis — ${levelConfig.label}`,
        });
        reservationId = reservation.id;
      } catch (error) {
        if (error instanceof InsufficientCreditsError) {
          // Nothing was reserved: the balance changed since pricing.
          await failDefinitively("insufficientCredits");
          throw ineligibleError();
        }
        throw error;
      }
      console.info("credit_reserved", {idempotencyKey, reservationAmount});
    }
    job = await advance({stage: "reserved", reservationId});
  }

  if (job.stage === "reserved") {
    if (!params.apiKey) {
      throw new Error(`No API key configured for ${levelConfig.provider}.`);
    }
    const provider = createProvider(
      levelConfig.provider as SupportedProviderId,
      params.apiKey,
      levelConfig.model
    );
    const images = provider.supportsImages ?
      await resolveFindingEvidence({uid, input, firestore, storage}) :
      {findingId: input.findingId, images: [], unavailableCount: 0};

    let result: ClassificationResult;
    let usage: {inputTokens: number; outputTokens: number} | undefined;
    const providerStartedAt = Date.now();
    let providerDurationMs = 0;
    try {
      // Safe facts only (no note text, image bytes or keys), so Fast,
      // Smart and Expert runs can be compared in the logs.
      console.info("provider_started", {
        idempotencyKey,
        provider: provider.id,
        model: levelConfig.model,
        aiLevel,
        images: images.images.length,
        unavailableImages: images.unavailableCount,
        hasNote: Boolean(input.note),
      });
      const classification = await provider.classifyFinding(input, images);
      result = classification.result;
      usage = classification.usage;
      providerDurationMs = Date.now() - providerStartedAt;
      console.info("provider_completed", {
        idempotencyKey,
        model: levelConfig.model,
        aiLevel,
        ms: providerDurationMs,
        needsReview: result.needsReview,
        hasEntry: Boolean(result.catalogueEntryId),
        hasTerm: Boolean(result.defectTerm),
      });
    } catch (error) {
      // A definite provider failure: no result exists, so nothing is
      // charged. The release refuses to apply if this reservation was
      // somehow already settled.
      const detail = error instanceof AiProviderError ? error.detail : {};
      console.error("AI provider request failed", {
        provider: provider.id,
        model: levelConfig.model,
        idempotencyKey,
        findingId: input.findingId,
        kind: detail.kind ?? null,
        status: detail.status ?? null,
        providerCode: detail.providerCode ?? null,
        message: error instanceof Error ? error.message : "unknown error",
      });
      if (job.reservationId) {
        await releaseReservation(firestore, {
          uid,
          reservationTransactionId: job.reservationId,
          idempotencyKey: `${idempotencyKey}_release_failed`,
          description: "AI Analysis — Credits returned (analysis failed)",
          exclusiveOf: `${idempotencyKey}_settlement`,
        });
        console.info("credit_released", {idempotencyKey});
      }
      await failDefinitively(`provider_${detail.kind ?? "failed"}`);
      throw providerFailureError(error);
    }

    const usageRecord = providerUsageRecord({
      usage,
      levelConfig,
      providerDurationMs,
    });
    // One photo = one finding = one request, so this is the exact AI
    // usage and raw provider cost of one image. Safe IDs and numbers
    // only — never the prompt, note, image, key or any personal data.
    console.info("provider_usage", {
      idempotencyKey,
      findingId: input.findingId,
      aiLevel,
      ...usageRecord,
    });

    const normalized = validateAndNormalize(input, result);
    const reservationAmount = job.reservationAmount ?? 0;
    const actualCredits = usage ?
      Math.min(
        actualCreditsForUsage(
          aiLevel,
          usage.inputTokens,
          usage.outputTokens,
          params.config
        ),
        reservationAmount
      ) :
      reservationAmount;
    // The provider's answer and the exact charge are stored before any
    // money moves: from here on a replay never calls the provider again
    // and never refunds.
    job = await advance({
      stage: "providerCompleted",
      classification: normalized,
      actualCredits,
      providerCompletedAt: Date.now(),
      ...usageRecord,
    });
  }

  if (job.stage === "providerCompleted") {
    if (job.reservationId) {
      await settleReservation(firestore, {
        uid,
        reservationTransactionId: job.reservationId,
        actualCredits: job.actualCredits ?? 0,
        idempotencyKey: `${idempotencyKey}_settlement`,
        description: `AI Analysis — ${levelConfig.label}`,
        exclusiveOf: `${idempotencyKey}_release_failed`,
      });
      console.info("credit_settled", {
        idempotencyKey,
        actualCredits: job.actualCredits,
      });
    }
    job = await advance({stage: "settled", settledAt: Date.now()});
  }

  if (job.stage === "settled") {
    let housePassUsageRecorded = false;
    if (job.paymentMode === "housePass" && job.housePassId) {
      await recordHousePassUsage(
        firestore,
        uid,
        job.housePassId,
        idempotencyKey
      );
      housePassUsageRecorded = true;
    }
    job = await advance({
      status: "succeeded",
      housePassUsageRecorded,
      creditsCharged: job.reservationId ? job.actualCredits ?? 0 : 0,
      leaseExpiresAt: 0,
    });
    console.info("ai_job_completed", {
      idempotencyKey,
      creditsCharged: job.creditsCharged,
    });
  }

  return toResult(job, await getWalletBalance(firestore, uid));
}
