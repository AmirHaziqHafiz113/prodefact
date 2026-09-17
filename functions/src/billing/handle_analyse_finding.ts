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
import {loadPricingConfig} from "./pricing_config";
import {actualCreditsForUsage} from "./pricing";
import {
  getWalletBalance,
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
 */

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

/**
 * The stored outcome of one `analyseFinding` attempt, keyed by the
 * client's own idempotency key — this is what makes a duplicate tap or
 * a Functions-level retry idempotent: a replay finds this doc and
 * returns it directly, without touching the wallet or the AI provider
 * a second time (see the module doc comment).
 */
interface AiJobRecord {
  id: string;
  userId: string;
  inspectionId: string;
  findingId: string;
  aiLevel: AiLevel;
  status: "succeeded" | "failed";
  paymentMode: CommercialMode;
  creditsCharged: number;
  classification?: ClassificationResult;
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
 * @param {AiJobRecord} job a stored job outcome.
 * @param {number} newBalance the caller's current wallet balance.
 * @return {AnalyseFindingResult} the callable's response shape.
 */
function toResult(
  job: AiJobRecord,
  newBalance: number
): AnalyseFindingResult {
  if (job.status !== "succeeded" || !job.classification) {
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
      confidence: job.classification.confidence,
      shortReason: job.classification.shortReason,
      candidateEntryIds: job.classification.candidateEntryIds ?? [],
      needsReview: job.classification.needsReview,
    },
  };
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
}): Promise<AnalyseFindingResult> {
  const {auth, data, firestore, storage, apiKeys} = params;
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

  const jobRef = aiJobRef(firestore, uid, idempotencyKey);
  const existingJob = await jobRef.get();
  if (existingJob.exists) {
    const balance = await getWalletBalance(firestore, uid);
    return toResult(existingJob.data() as AiJobRecord, balance);
  }

  // Re-price authoritatively, immediately before spending anything —
  // never trusts the estimate the client saw earlier, which may be
  // stale (see docs/commercial_model.md, "offline behavior").
  const estimate = await computeEstimate(firestore, uid, {
    inspectionId: input.inspectionId,
    findingId: input.findingId,
    aiLevel,
  });
  if (!estimate.eligible) {
    throw new HttpsError(
      "failed-precondition",
      estimate.reason === "insufficientCredits" ?
        "You don't have enough Credits for this analysis." :
        "This House Pass can't be used for this analysis right now."
    );
  }

  const config = await loadPricingConfig(firestore);
  const levelConfig = config.aiLevels[aiLevel];
  const apiKey = levelConfig.provider === "openai" ?
    apiKeys.openai :
    apiKeys.deepseek;
  if (!apiKey) {
    throw new HttpsError(
      "failed-precondition",
      "AI analysis is temporarily unavailable. Please try again later."
    );
  }
  const provider = createProvider(
    levelConfig.provider as SupportedProviderId,
    apiKey,
    levelConfig.model
  );

  const images = provider.supportsImages ?
    await resolveFindingEvidence({uid, input, firestore, storage}) :
    {findingId: input.findingId, images: [], unavailableCount: 0};

  // House Pass reserves only the surcharge (0 when the level is fully
  // included); Flex Credits always reserves the full worst-case amount.
  const reservationAmount = estimate.paymentMode === "housePass" ?
    estimate.surchargeCredits :
    estimate.maximumCredits;

  let reservationId: string | undefined;
  if (reservationAmount > 0) {
    const reservation = await reserveCredits(firestore, {
      uid,
      amountCredits: reservationAmount,
      idempotencyKey: `${idempotencyKey}_reservation`,
      inspectionId: input.inspectionId,
      findingId: input.findingId,
      aiLevel,
      description: `AI analysis (${aiLevel}) — reserved`,
    });
    reservationId = reservation.id;
  }

  let result: ClassificationResult;
  let usage: {inputTokens: number; outputTokens: number} | undefined;
  try {
    const classification = await provider.classifyFinding(input, images);
    result = classification.result;
    usage = classification.usage;
  } catch (error) {
    console.error("AI provider request failed", {
      provider: provider.id,
      message: error instanceof Error ? error.message : "unknown error",
    });
    if (reservationId) {
      await releaseReservation(firestore, {
        uid,
        reservationTransactionId: reservationId,
        idempotencyKey: `${idempotencyKey}_release_failed`,
        description: "AI analysis failed — reservation released",
      });
    }
    const now = Date.now();
    await jobRef.set({
      id: idempotencyKey,
      userId: uid,
      inspectionId: input.inspectionId,
      findingId: input.findingId,
      aiLevel,
      status: "failed",
      paymentMode: estimate.paymentMode,
      creditsCharged: 0,
      createdAt: now,
      updatedAt: now,
    } satisfies AiJobRecord);

    const isTimeout = error instanceof AiProviderError &&
      error.message.toLowerCase().includes("transient");
    throw new HttpsError(
      isTimeout ? "deadline-exceeded" : "internal",
      isTimeout ?
        "AI analysis timed out. You have not been charged. Please " +
          "retry or classify manually." :
        "AI analysis failed. You have not been charged. Please retry " +
          "or classify manually."
    );
  }

  const normalized = validateAndNormalize(input, result);

  const actualCredits = usage ?
    Math.min(
      actualCreditsForUsage(
        aiLevel,
        usage.inputTokens,
        usage.outputTokens,
        config
      ),
      reservationAmount
    ) :
    reservationAmount;

  if (reservationId) {
    await settleReservation(firestore, {
      uid,
      reservationTransactionId: reservationId,
      actualCredits,
      idempotencyKey: `${idempotencyKey}_settlement`,
      description: `AI analysis (${aiLevel})`,
    });
  }

  if (estimate.paymentMode === "housePass") {
    const pass = await findHousePassForInspection(
      firestore,
      uid,
      input.inspectionId
    );
    if (pass) {
      await recordHousePassUsage(firestore, uid, pass.id);
    }
  }

  const newBalance = await getWalletBalance(firestore, uid);
  const now = Date.now();
  const succeededJob: AiJobRecord = {
    id: idempotencyKey,
    userId: uid,
    inspectionId: input.inspectionId,
    findingId: input.findingId,
    aiLevel,
    status: "succeeded",
    paymentMode: estimate.paymentMode,
    creditsCharged: reservationId ? actualCredits : 0,
    classification: normalized,
    createdAt: now,
    updatedAt: now,
  };
  await jobRef.set(succeededJob);

  return toResult(succeededJob, newBalance);
}
