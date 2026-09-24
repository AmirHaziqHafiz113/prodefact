import type {Firestore} from "firebase-admin/firestore";
import {HousePass, HousePassStatus} from "./types";
import {HousePassConfig} from "./pricing_config";

/**
 * House Pass domain logic — a fixed-price (RM30) product associated
 * with exactly one inspection, backend-authoritative throughout (see
 * docs/commercial_model.md, "House Pass"). Flutter never activates or
 * trusts its own copy of a pass's state.
 */

/**
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the pass owner.
 * @return {FirebaseFirestore.CollectionReference} the owner's House
 *   Pass subcollection.
 */
function housePassCollection(db: Firestore, uid: string) {
  return db.collection("users").doc(uid).collection("housePasses");
}

/**
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the pass owner.
 * @param {string} inspectionId the associated inspection.
 * @return {Promise<HousePass | null>} the pass for this inspection, if
 *   one exists (there is at most one per inspection — a new
 *   inspection always needs its own pass, never inherited).
 */
export async function findHousePassForInspection(
  db: Firestore,
  uid: string,
  inspectionId: string
): Promise<HousePass | null> {
  const snap = await housePassCollection(db, uid)
    .where("inspectionId", "==", inspectionId)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0].data() as HousePass;
}

/**
 * Creates (or, on a retried call, returns the existing) House Pass for
 * one inspection, immediately `active` — this is called only after
 * payment has already been confirmed (sandbox or a real gateway's
 * webhook; see `handle_purchase_house_pass.ts`), never speculatively.
 * @param {Firestore} db the Admin Firestore client.
 * @param {object} params the purchase details.
 * @return {Promise<HousePass>} the created (or pre-existing) pass.
 */
export async function createActiveHousePass(
  db: Firestore,
  params: {
    uid: string;
    inspectionId: string;
    idempotencyKey: string;
    externalPaymentRef: string;
    config: HousePassConfig;
  }
): Promise<HousePass> {
  const ref = housePassCollection(db, params.uid).doc(params.idempotencyKey);
  return db.runTransaction(async (tx) => {
    const existing = await tx.get(ref);
    if (existing.exists) return existing.data() as HousePass;

    const now = Date.now();
    const pass: HousePass = {
      id: params.idempotencyKey,
      inspectionId: params.inspectionId,
      userId: params.uid,
      priceMyr: params.config.priceMyr,
      currency: "MYR",
      status: "active",
      purchasedAt: now,
      createdAt: now,
      updatedAt: now,
      paymentRef: params.externalPaymentRef,
      allowanceConfigVersion: params.config.version,
      includedAiLevel: params.config.includedAiLevel,
      allowanceUsed: 0,
      allowanceLimit: params.config.allowanceFindings,
    };
    tx.set(ref, pass);
    return pass;
  });
}

/**
 * @param {HousePass} pass a House Pass.
 * @return {boolean} whether it currently has allowance remaining.
 */
export function hasRemainingAllowance(pass: HousePass): boolean {
  return (
    pass.status === "active" && pass.allowanceUsed < pass.allowanceLimit
  );
}

/**
 * Atomically consumes one unit of a House Pass's allowance for one AI
 * analysis — called only once that analysis actually completes, so a
 * failed analysis never consumes allowance. Flips the pass to
 * `allowanceReached` (not `expired`/`cancelled`) the moment the limit
 * is hit, so the UI can offer "Continue with Flex Credits" immediately
 * — see docs/commercial_model.md ("If allowance is exhausted").
 *
 * Idempotent per [usageKey] (the analysis job's idempotency key): the
 * first call records a usage document under the pass and increments
 * the count in the same transaction; any replay finds that document and
 * returns the pass unchanged, so one analysis can never consume
 * allowance twice.
 * @param {Firestore} db the Admin Firestore client.
 * @param {string} uid the pass owner.
 * @param {string} passId the pass to update.
 * @param {string} usageKey the consuming analysis's idempotency key.
 * @return {Promise<HousePass>} the pass after this usage.
 */
export async function recordHousePassUsage(
  db: Firestore,
  uid: string,
  passId: string,
  usageKey: string
): Promise<HousePass> {
  const ref = housePassCollection(db, uid).doc(passId);
  const usageRef = ref.collection("usages").doc(usageKey);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) throw new Error(`House Pass ${passId} not found.`);
    const pass = snap.data() as HousePass;
    const existingUsage = await tx.get(usageRef);
    if (existingUsage.exists) return pass;

    const now = Date.now();
    const allowanceUsed = pass.allowanceUsed + 1;
    const status: HousePassStatus =
      allowanceUsed >= pass.allowanceLimit ? "allowanceReached" : "active";
    const updated: HousePass = {
      ...pass,
      allowanceUsed,
      status,
      updatedAt: now,
    };
    tx.set(ref, updated);
    tx.set(usageRef, {id: usageKey, passId, userId: uid, createdAt: now});
    return updated;
  });
}
