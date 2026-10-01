import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import {
  loadPricingConfig,
  loadPricingConfigWithSource,
  PricingConfig,
} from "./pricing_config";
import {estimateMaxCredits, housePassSurchargeCredits} from "./pricing";
import {getWalletBalance} from "./wallet";
import {findHousePassForInspection, hasRemainingAllowance} from "./house_pass";
import {AiLevel, EstimateResult, isAiLevel} from "./types";

export interface EstimateRequest {
  inspectionId: string;
  findingId: string;
  aiLevel: AiLevel;
}

/**
 * @param {unknown} data the raw callable payload.
 * @return {EstimateRequest} the validated request.
 */
export function parseEstimateRequest(data: unknown): EstimateRequest {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError("invalid-argument", "Malformed request.");
  }
  const d = data as Record<string, unknown>;
  if (typeof d.inspectionId !== "string" || d.inspectionId.length === 0) {
    throw new HttpsError("invalid-argument", "inspectionId is required.");
  }
  if (typeof d.findingId !== "string" || d.findingId.length === 0) {
    throw new HttpsError("invalid-argument", "findingId is required.");
  }
  if (!isAiLevel(d.aiLevel)) {
    throw new HttpsError(
      "invalid-argument",
      "aiLevel must be fast/smart/expert."
    );
  }
  return {
    inspectionId: d.inspectionId,
    findingId: d.findingId,
    aiLevel: d.aiLevel,
  };
}

/**
 * Verifies the caller owns both the inspection and the finding, the
 * same ownership-by-Storage-path-derivation principle
 * `ai/evidence.ts` already uses — never trusts a client-supplied
 * assertion of ownership.
 * @param {Firestore} firestore the Admin Firestore client.
 * @param {string} uid the caller.
 * @param {EstimateRequest} req the request.
 * @return {Promise<boolean>} whether the finding exists under this
 *   caller's own inspection.
 */
export async function isOwnedFinding(
  firestore: Firestore,
  uid: string,
  req: EstimateRequest
): Promise<boolean> {
  const snap = await firestore
    .collection("users")
    .doc(uid)
    .collection("inspections")
    .doc(req.inspectionId)
    .collection("findings")
    .doc(req.findingId)
    .get();
  return snap.exists;
}

/**
 * The full estimate computation, shared by the `estimateFindingAnalysis`
 * callable and `analyseFinding` (which re-derives the same eligibility
 * decision immediately before reserving/spending real Credits — see
 * docs/commercial_model.md, "Reservation before AI"). Assumes ownership
 * has already been verified by the caller.
 * @param {Firestore} firestore the Admin Firestore client.
 * @param {string} uid the caller.
 * @param {EstimateRequest} req the validated request.
 * @param {object} options an already-resolved config and a stage hook.
 * @return {Promise<EstimateResult>} the estimate.
 */
export async function computeEstimate(
  firestore: Firestore,
  uid: string,
  req: EstimateRequest,
  options: {
    config?: PricingConfig;
    /** Called as each stage completes, for safe diagnostic logging. */
    onStage?: (stage: string, detail?: Record<string, unknown>) => void;
  } = {}
): Promise<EstimateResult> {
  const config = options.config ?? await loadPricingConfig(firestore);
  const onStage = options.onStage ?? (() => undefined);
  const balance = await getWalletBalance(firestore, uid);
  onStage("wallet_balance_read");
  const maximumCredits = estimateMaxCredits(req.aiLevel, config);

  // Billing mode is decided here, never by the client (QA #23): the
  // inspection's House Pass record exists only once the backend has
  // confirmed payment, so an active pass means House Pass; anything
  // else means Flex Credits. The inspection document's client-written
  // `commercialMode` field is deliberately ignored — it was never
  // synced reliably, which left paid House Pass inspections billed as
  // Flex Credits.
  const pass = await findHousePassForInspection(
    firestore,
    uid,
    req.inspectionId
  );
  onStage("house_pass_lookup", {passStatus: pass?.status ?? "none"});
  if (!pass || pass.status !== "active") {
    const eligible = balance >= maximumCredits;
    return {
      aiLevel: req.aiLevel,
      estimatedCredits: maximumCredits,
      maximumCredits,
      currentBalance: balance,
      paymentMode: "flexCredits",
      includedInHousePass: false,
      surchargeCredits: 0,
      eligible,
      // A used-up pass is worth telling the inspector about even when
      // Flex Credits cover this analysis; a missing pass is not.
      reason: !eligible ?
        "insufficientCredits" :
        (pass ? "housePassAllowanceReached" : undefined),
    };
  }

  const surcharge = housePassSurchargeCredits(
    req.aiLevel,
    pass.includedAiLevel,
    config
  );
  const withinAllowance = hasRemainingAllowance(pass);
  const eligible = withinAllowance && (surcharge === 0 || balance >= surcharge);

  return {
    aiLevel: req.aiLevel,
    estimatedCredits: surcharge,
    maximumCredits: surcharge,
    currentBalance: balance,
    paymentMode: "housePass",
    includedInHousePass: surcharge === 0,
    surchargeCredits: surcharge,
    eligible,
    reason: !withinAllowance ?
      "housePassAllowanceReached" :
      (!eligible ? "insufficientCredits" : undefined),
  };
}

/**
 * `estimateFindingAnalysis` — the price-check step before the
 * inspector ever sees an "Analyse" button they can tap. Never runs AI,
 * never reserves anything; purely informational. See
 * docs/commercial_model.md ("AI cost estimate").
 * @param {object} params the request/dependencies.
 * @return {Promise<EstimateResult>} the estimate.
 */
export async function handleEstimateFindingAnalysis(params: {
  auth: {uid: string} | null | undefined;
  data: unknown;
  firestore: Firestore;
}): Promise<EstimateResult> {
  const {auth, data, firestore} = params;
  // Safe, structured diagnostics for each stage (never keys, tokens,
  // full user data or images): a failed price check must always be
  // explainable from the logs.
  let stage = "request_accepted";
  const ids: Record<string, unknown> = {};
  const log = (name: string, detail: Record<string, unknown> = {}) =>
    console.info("estimate_finding_stage", {stage: name, ...ids, ...detail});
  try {
    log(stage, {uidPresent: Boolean(auth?.uid)});
    if (!auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    stage = "parse_request";
    const req = parseEstimateRequest(data);
    Object.assign(ids, {
      inspectionId: req.inspectionId,
      findingId: req.findingId,
      aiLevel: req.aiLevel,
    });

    stage = "ownership_check";
    const owned = await isOwnedFinding(firestore, auth.uid, req);
    log(stage, {owned});
    if (!owned) {
      throw new HttpsError(
        "permission-denied",
        "That finding does not belong to you.",
        {reason: "findingNotSynced"}
      );
    }

    stage = "pricing_config";
    const pricing = await loadPricingConfigWithSource(firestore);
    const level = pricing.config.aiLevels[req.aiLevel];
    log(stage, {
      source: pricing.source,
      version: pricing.config.version,
      hasFast: Boolean(pricing.config.aiLevels.fast),
      hasSmart: Boolean(pricing.config.aiLevels.smart),
      hasExpert: Boolean(pricing.config.aiLevels.expert),
      selectedLevel: req.aiLevel,
      selectedModel: level?.model ?? null,
      pricingFieldsValid: Boolean(level) &&
        Number.isFinite(level.providerCostPerKInputTokensUsd) &&
        Number.isFinite(level.providerCostPerKOutputTokensUsd) &&
        Number.isFinite(level.estimatedInputTokens) &&
        Number.isFinite(level.estimatedOutputTokens),
      issues: pricing.issues.length,
    });

    stage = "compute_estimate";
    const result = await computeEstimate(firestore, auth.uid, req, {
      config: pricing.config,
      onStage: (name, detail) => log(name, detail),
    });
    log("estimate_ready", {
      estimatedCredits: result.estimatedCredits,
      maximumCredits: result.maximumCredits,
      paymentMode: result.paymentMode,
      eligible: result.eligible,
    });
    return result;
  } catch (error) {
    console.error("estimate_finding_failed", {
      stage,
      ...ids,
      code: error instanceof HttpsError ? error.code : null,
      message: error instanceof Error ? error.message : "unknown error",
    });
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
      "internal",
      "Pricing is temporarily unavailable.",
      {reason: "pricingUnavailable"}
    );
  }
}
