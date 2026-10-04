import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";

/**
 * `qaReset` — a DEV/QA-ONLY callable that erases the *operational* data
 * the signed-in caller's own uid has accumulated (inspections and
 * everything nested under one: sections, findings, evidence metadata,
 * AI suggestions; plus the caller's own `aiJobs` and `housePasses`),
 * and the matching uploaded evidence files in Cloud Storage. It never
 * touches the Firebase Auth account, the wallet ledger
 * (`wallet`/`walletTransactions` — see `billing/wallet.ts`'s own
 * "authoritative, auditable" doc comment), `paymentIntents`, any other
 * user's data, or global/system documents (pricing config, the defect
 * catalogue) — none of those live under this uid's own
 * inspection-scoped subtree, so nothing elsewhere in this file needs to
 * special-case them.
 *
 * Disabled unless `resolveQaResetMode` resolves to `"enabled"` (an
 * explicit `QA_RESET_ENABLED=true` environment variable a real
 * deployment must never set — mirrors `billing/payments_mode.ts`'s
 * boundary) and the caller echoes back `CONFIRMATION_PHRASE` exactly,
 * so neither a misconfigured environment nor a client bug can trigger
 * this silently.
 *
 * Idempotent and partial-failure-safe: every delete is its own
 * try/catch, so one already-deleted or momentarily-unreachable
 * document never aborts the rest, and calling this twice in a row (or
 * retrying after a partial failure) is always safe — the second call
 * simply finds less to delete. Only counts are logged/returned, never
 * document ids or content.
 */

export const CONFIRMATION_PHRASE = "DELETE MY INSPECTION DATA";

export type QaResetMode = "enabled" | "disabled";

/**
 * @param {NodeJS.ProcessEnv} env the function's process environment.
 * @return {QaResetMode} whether `qaReset` is allowed to run at all.
 */
export function resolveQaResetMode(env: NodeJS.ProcessEnv): QaResetMode {
  return env.QA_RESET_ENABLED?.trim().toLowerCase() === "true" ?
    "enabled" :
    "disabled";
}

export interface QaResetRequest {
  confirmation: string;
}

/**
 * @param {unknown} data the raw callable payload.
 * @return {QaResetRequest} the validated request.
 */
export function parseQaResetInput(data: unknown): QaResetRequest {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError("invalid-argument", "Malformed request.");
  }
  const d = data as Record<string, unknown>;
  if (typeof d.confirmation !== "string") {
    throw new HttpsError("invalid-argument", "confirmation is required.");
  }
  return {confirmation: d.confirmation};
}

export interface QaResetCounts {
  inspections: number;
  sections: number;
  findings: number;
  evidence: number;
  aiSuggestions: number;
  aiJobs: number;
  housePasses: number;
  housePassUsages: number;
  storageFiles: number;
  errors: number;
}

/**
 * @return {QaResetCounts} a fresh all-zero tally.
 */
function emptyCounts(): QaResetCounts {
  return {
    inspections: 0,
    sections: 0,
    findings: 0,
    evidence: 0,
    aiSuggestions: 0,
    aiJobs: 0,
    housePasses: 0,
    housePassUsages: 0,
    storageFiles: 0,
    errors: 0,
  };
}

interface MinimalDocRef {
  delete: () => Promise<unknown>;
  collection: (name: string) => MinimalCollectionRef;
}

interface MinimalCollectionRef {
  listDocuments: () => Promise<MinimalDocRef[]>;
}

/**
 * Deletes every direct-child document of [collection], one at a time,
 * each in its own try/catch so one failure never blocks the rest.
 * @param {MinimalCollectionRef} collection the collection to clear.
 * @param {QaResetCounts} counts the running tally to update in place.
 * @param {string} key which count to increment per successful delete.
 */
async function deleteDirectChildren(
  collection: MinimalCollectionRef,
  counts: QaResetCounts,
  key: keyof Omit<QaResetCounts, "errors">
): Promise<void> {
  const refs = await collection.listDocuments();
  for (const ref of refs) {
    try {
      await ref.delete();
      counts[key]++;
    } catch {
      counts.errors++;
    }
  }
}

/**
 * Deletes one specific document, tallying success/failure.
 * @param {MinimalDocRef} ref the document to delete.
 * @param {QaResetCounts} counts the running tally to update in place.
 * @param {string} key which count to increment on success.
 */
async function deleteOneDoc(
  ref: MinimalDocRef,
  counts: QaResetCounts,
  key: keyof Omit<QaResetCounts, "errors">
): Promise<void> {
  try {
    await ref.delete();
    counts[key]++;
  } catch {
    counts.errors++;
  }
}

/**
 * Deletes one inspection's full nested tree — sections, every
 * finding's evidence metadata then the finding itself, aiSuggestions,
 * then the inspection document itself (whose `report` field, being a
 * plain field rather than a subcollection, is removed along with it).
 * @param {MinimalDocRef} inspectionRef the inspection document.
 * @param {QaResetCounts} counts the running tally to update in place.
 */
async function deleteInspectionTree(
  inspectionRef: MinimalDocRef,
  counts: QaResetCounts
): Promise<void> {
  await deleteDirectChildren(
    inspectionRef.collection("sections"),
    counts,
    "sections"
  );

  const findingRefs = await inspectionRef
    .collection("findings")
    .listDocuments();
  for (const findingRef of findingRefs) {
    await deleteDirectChildren(
      findingRef.collection("evidence"),
      counts,
      "evidence"
    );
    await deleteOneDoc(findingRef, counts, "findings");
  }

  await deleteDirectChildren(
    inspectionRef.collection("aiSuggestions"),
    counts,
    "aiSuggestions"
  );

  await deleteOneDoc(inspectionRef, counts, "inspections");
}

/**
 * Deletes one House Pass's `usages` subcollection, then the pass
 * itself.
 * @param {MinimalDocRef} passRef the House Pass document.
 * @param {QaResetCounts} counts the running tally to update in place.
 */
async function deleteHousePassTree(
  passRef: MinimalDocRef,
  counts: QaResetCounts
): Promise<void> {
  await deleteDirectChildren(
    passRef.collection("usages"),
    counts,
    "housePassUsages"
  );
  await deleteOneDoc(passRef, counts, "housePasses");
}

/**
 * @param {object} params the request/dependencies.
 * @return {Promise<QaResetCounts>} what was actually deleted, as
 *   counts only — never ids or content.
 */
export async function handleQaReset(params: {
  auth: {uid: string} | null | undefined;
  data: unknown;
  firestore: Firestore;
  storage: Storage;
  env: NodeJS.ProcessEnv;
}): Promise<QaResetCounts> {
  const {auth, data, firestore, storage, env} = params;
  if (!auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  if (resolveQaResetMode(env) !== "enabled") {
    throw new HttpsError(
      "failed-precondition",
      "QA reset is not enabled in this environment."
    );
  }
  const {confirmation} = parseQaResetInput(data);
  if (confirmation !== CONFIRMATION_PHRASE) {
    throw new HttpsError(
      "invalid-argument",
      `confirmation must be exactly "${CONFIRMATION_PHRASE}".`
    );
  }

  const uid = auth.uid;
  const counts = emptyCounts();

  const userRef = firestore.collection("users").doc(uid);

  const inspectionRefs = await userRef.collection("inspections")
    .listDocuments();
  for (const inspectionRef of inspectionRefs) {
    await deleteInspectionTree(inspectionRef, counts);
  }

  await deleteDirectChildren(userRef.collection("aiJobs"), counts, "aiJobs");

  const housePassRefs = await userRef.collection("housePasses")
    .listDocuments();
  for (const passRef of housePassRefs) {
    await deleteHousePassTree(passRef, counts);
  }

  // Scoped strictly by this uid's own inspection-evidence prefix —
  // never a bucket-wide wipe. Count files first since `deleteFiles`
  // itself reports no per-file count.
  try {
    const bucket = storage.bucket();
    const prefix = `users/${uid}/inspections/`;
    const [files] = await bucket.getFiles({prefix});
    await bucket.deleteFiles({prefix});
    counts.storageFiles += files.length;
  } catch {
    counts.errors++;
  }

  return counts;
}
