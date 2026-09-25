import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import {loadPricingConfig} from "./pricing_config";
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
 * @return {Promise<EstimateResult>} the estimate.
 */
export async function computeEstimate(
  firestore: Firestore,
  uid: string,
  req: EstimateRequest
): Promise<EstimateResult> {
  const config = await loadPricingConfig(firestore);
  const balance = await getWalletBalance(firestore, uid);
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
  if (!auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const req = parseEstimateRequest(data);

  const owned = await isOwnedFinding(firestore, auth.uid, req);
  if (!owned) {
    throw new HttpsError(
      "permission-denied",
      "That finding does not belong to you."
    );
  }

  return computeEstimate(firestore, auth.uid, req);
}
