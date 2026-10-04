import assert from "node:assert/strict";
import {test} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import {fakeFirestore, fakeStorage} from "./billing/fakes";
import {
  CONFIRMATION_PHRASE,
  handleQaReset,
  resolveQaResetMode,
} from "./qa_reset";

const UID = "user_1";
const OTHER_UID = "user_2";

/**
 * @param {object} seed extra documents, keyed by full path.
 * @return {object} a Firestore fake seeded with one full inspection
 *   tree (section, finding + its evidence, an aiSuggestion), one
 *   aiJob, and one House Pass (+ one usage) for [UID], plus global/
 *   other-user documents that must survive a reset untouched.
 */
function seededFirestore(seed: Record<string, Record<string, unknown>> = {}) {
  return fakeFirestore({
    [`users/${UID}/inspections/insp_1`]: {id: "insp_1", status: "draft"},
    [`users/${UID}/inspections/insp_1/sections/sec_1`]: {id: "sec_1"},
    [`users/${UID}/inspections/insp_1/findings/f_1`]: {id: "f_1"},
    [`users/${UID}/inspections/insp_1/findings/f_1/evidence/e_1`]: {
      id: "e_1",
    },
    [`users/${UID}/inspections/insp_1/aiSuggestions/s_1`]: {id: "s_1"},
    [`users/${UID}/aiJobs/job_1`]: {id: "job_1"},
    [`users/${UID}/housePasses/pass_1`]: {id: "pass_1"},
    [`users/${UID}/housePasses/pass_1/usages/u_1`]: {id: "u_1"},
    // Must survive: wallet ledger, payment intents, another user.
    [`users/${UID}/wallet/main`]: {balance: 5000},
    [`users/${UID}/walletTransactions/tx_1`]: {amount: 100},
    [`users/${UID}/paymentIntents/pi_1`]: {status: "succeeded"},
    [`users/${OTHER_UID}/inspections/insp_other`]: {id: "insp_other"},
    [`users/${OTHER_UID}/wallet/main`]: {balance: 999},
    // Global/system documents, never user-scoped.
    "pricing/config": {version: 1},
    "defectCatalogue/wall_tile_01": {name: "Wall Tile"},
    ...seed,
  });
}

/**
 * @return {NodeJS.ProcessEnv} an environment with QA reset enabled.
 */
function enabledEnv(): NodeJS.ProcessEnv {
  return {QA_RESET_ENABLED: "true"};
}

test("resolveQaResetMode defaults to disabled, requires exactly " +
  "QA_RESET_ENABLED=true", () => {
  assert.equal(resolveQaResetMode({}), "disabled");
  assert.equal(resolveQaResetMode({QA_RESET_ENABLED: "false"}), "disabled");
  assert.equal(resolveQaResetMode({QA_RESET_ENABLED: "1"}), "disabled");
  assert.equal(resolveQaResetMode({QA_RESET_ENABLED: "TRUE"}), "enabled");
  assert.equal(resolveQaResetMode({QA_RESET_ENABLED: "true"}), "enabled");
});

test("rejects an unauthenticated caller", async () => {
  const {db} = seededFirestore();
  const {storage} = fakeStorage();
  await assert.rejects(
    () => handleQaReset({
      auth: null,
      data: {confirmation: CONFIRMATION_PHRASE},
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      firestore: db as any,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      storage: storage as any,
      env: enabledEnv(),
    }),
    (error: unknown) => (error as HttpsError).code === "unauthenticated"
  );
});

test("refuses to run outside dev/QA (QA_RESET_ENABLED not 'true')",
  async () => {
    const {db} = seededFirestore();
    const {storage} = fakeStorage();
    await assert.rejects(
      () => handleQaReset({
        auth: {uid: UID},
        data: {confirmation: CONFIRMATION_PHRASE},
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        firestore: db as any,
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        storage: storage as any,
        env: {},
      }),
      (error: unknown) => (error as HttpsError).code === "failed-precondition"
    );
  });

test("requires the exact confirmation phrase", async () => {
  const {db} = seededFirestore();
  const {storage} = fakeStorage();
  await assert.rejects(
    () => handleQaReset({
      auth: {uid: UID},
      data: {confirmation: "yes please"},
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      firestore: db as any,
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      storage: storage as any,
      env: enabledEnv(),
    }),
    (error: unknown) => (error as HttpsError).code === "invalid-argument"
  );
});

test("a successful reset deletes inspections/sections/findings/" +
  "evidence/aiSuggestions/aiJobs/housePasses(+usages) for the caller " +
  "only, deletes only that caller's Storage files by uid+prefix, and " +
  "spares the wallet ledger, payment intents, global config/catalogue " +
  "and the other user's data entirely", async () => {
  const {db, store} = seededFirestore();
  const {storage, files} = fakeStorage(new Set([
    `users/${UID}/inspections/insp_1/findings/f_1/e_1.jpg`,
    `users/${UID}/inspections/insp_1/findings/f_1/e_2.jpg`,
    `users/${OTHER_UID}/inspections/insp_other/findings/f_x/e_x.jpg`,
  ]));

  const counts = await handleQaReset({
    auth: {uid: UID},
    data: {confirmation: CONFIRMATION_PHRASE},
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    firestore: db as any,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    storage: storage as any,
    env: enabledEnv(),
  });

  assert.equal(counts.errors, 0);
  assert.equal(counts.inspections, 1);
  assert.equal(counts.sections, 1);
  assert.equal(counts.findings, 1);
  assert.equal(counts.evidence, 1);
  assert.equal(counts.aiSuggestions, 1);
  assert.equal(counts.aiJobs, 1);
  assert.equal(counts.housePasses, 1);
  assert.equal(counts.housePassUsages, 1);
  assert.equal(counts.storageFiles, 2);

  // Deleted.
  for (const path of [
    `users/${UID}/inspections/insp_1`,
    `users/${UID}/inspections/insp_1/sections/sec_1`,
    `users/${UID}/inspections/insp_1/findings/f_1`,
    `users/${UID}/inspections/insp_1/findings/f_1/evidence/e_1`,
    `users/${UID}/inspections/insp_1/aiSuggestions/s_1`,
    `users/${UID}/aiJobs/job_1`,
    `users/${UID}/housePasses/pass_1`,
    `users/${UID}/housePasses/pass_1/usages/u_1`,
  ]) {
    assert.equal(store.has(path), false, `expected ${path} to be deleted`);
  }

  // Protected.
  for (const path of [
    `users/${UID}/wallet/main`,
    `users/${UID}/walletTransactions/tx_1`,
    `users/${UID}/paymentIntents/pi_1`,
    `users/${OTHER_UID}/inspections/insp_other`,
    `users/${OTHER_UID}/wallet/main`,
    "pricing/config",
    "defectCatalogue/wall_tile_01",
  ]) {
    assert.equal(store.has(path), true, `expected ${path} to survive`);
  }

  assert.deepEqual(
    Array.from(files),
    [`users/${OTHER_UID}/inspections/insp_other/findings/f_x/e_x.jpg`]
  );
});

test("repeated reset is safe (idempotent): the second run finds " +
  "nothing left and still succeeds with zero errors", async () => {
  const {db} = seededFirestore();
  const {storage} = fakeStorage(new Set([
    `users/${UID}/inspections/insp_1/findings/f_1/e_1.jpg`,
  ]));
  const run = () => handleQaReset({
    auth: {uid: UID},
    data: {confirmation: CONFIRMATION_PHRASE},
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    firestore: db as any,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    storage: storage as any,
    env: enabledEnv(),
  });

  const first = await run();
  assert.equal(first.errors, 0);
  assert.equal(first.inspections, 1);

  const second = await run();
  assert.equal(second.errors, 0);
  assert.equal(second.inspections, 0);
  assert.equal(second.storageFiles, 0);
});

test("one user can never delete another user's data: resetting " +
  `${OTHER_UID} leaves ${UID}'s inspection untouched`, async () => {
  const {db, store} = seededFirestore();
  const {storage} = fakeStorage();

  await handleQaReset({
    auth: {uid: OTHER_UID},
    data: {confirmation: CONFIRMATION_PHRASE},
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    firestore: db as any,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    storage: storage as any,
    env: enabledEnv(),
  });

  assert.equal(store.has(`users/${OTHER_UID}/inspections/insp_other`), false);
  assert.equal(store.has(`users/${UID}/inspections/insp_1`), true);
});
