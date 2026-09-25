import assert from "node:assert/strict";
import {test, TestContext} from "node:test";
import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";
import {
  handleEstimateFindingAnalysis,
} from "./handle_estimate_finding_analysis";
import {handleAnalyseFinding} from "./handle_analyse_finding";
import {fakeFirestore} from "./fakes";
import {getWalletBalance} from "./wallet";

/**
 * QA #23: the billing mechanism is decided by the backend from the
 * inspection's House Pass record, never from a client-written field and
 * never by the inspector during field work.
 */

const UID = "uid_1";
const START_BALANCE = 1000;

/**
 * @param {object} options what to seed.
 * @return {object} the fake Firestore and its raw store.
 */
function seeded(options: {
  inspectionField?: string;
  passStatus?: string;
}) {
  const seed: Record<string, Record<string, unknown>> = {
    [`users/${UID}/inspections/inspection_1`]: options.inspectionField ?
      {commercialMode: options.inspectionField} :
      {},
    [`users/${UID}/inspections/inspection_1/findings/finding_1`]: {},
    [`users/${UID}/wallet/main`]: {
      userId: UID,
      balanceCredits: START_BALANCE,
      updatedAt: 0,
    },
  };
  if (options.passStatus) {
    seed[`users/${UID}/housePasses/hp_1`] = {
      id: "hp_1",
      inspectionId: "inspection_1",
      userId: UID,
      priceMyr: 30,
      currency: "MYR",
      status: options.passStatus,
      purchasedAt: 0,
      createdAt: 0,
      updatedAt: 0,
      allowanceConfigVersion: 0,
      includedAiLevel: "smart",
      allowanceUsed: options.passStatus === "active" ? 0 : 10,
      allowanceLimit: 10,
    };
  }
  const {db, store} = fakeFirestore(seed);
  return {firestore: db as unknown as Firestore, store};
}

const request = {
  inspectionId: "inspection_1",
  findingId: "finding_1",
  aiLevel: "smart",
};

/**
 * @param {TestContext} t the running test.
 */
function stubProvider(t: TestContext) {
  const original = global.fetch;
  global.fetch = (async () => new Response(
    JSON.stringify({
      choices: [{
        message: {
          content: JSON.stringify({
            catalogueEntryId: "wall.concrete_wall.05",
            confidence: 0.8,
            needsReview: false,
          }),
        },
      }],
      usage: {prompt_tokens: 1000, completion_tokens: 200},
    }),
    {status: 200}
  )) as typeof fetch;
  t.after(() => {
    global.fetch = original;
  });
}

test("an active House Pass is used automatically even though the " +
  "inspection document never said housePass", async (t) => {
  stubProvider(t);
  const {firestore, store} = seeded({passStatus: "active"});

  const estimate = await handleEstimateFindingAnalysis({
    auth: {uid: UID},
    data: request,
    firestore,
  });
  assert.equal(estimate.paymentMode, "housePass");
  assert.equal(estimate.includedInHousePass, true);

  const result = await handleAnalyseFinding({
    auth: {uid: UID},
    data: {...request, area: "Kitchen", isPlumbingArea: false,
      idempotencyKey: "key_a"},
    firestore,
    storage: {} as unknown as Storage,
    apiKeys: {openai: "test-key"},
  });
  assert.equal(result.paymentMode, "housePass");
  assert.equal(result.creditsCharged, 0);
  assert.equal(await getWalletBalance(firestore, UID), START_BALANCE);
  assert.equal(
    store.get(`users/${UID}/housePasses/hp_1`)?.allowanceUsed,
    1
  );
});

test("with no House Pass, Flex Credits are used even if the client " +
  "wrote commercialMode: housePass on the inspection", async (t) => {
  stubProvider(t);
  const {firestore} = seeded({inspectionField: "housePass"});

  const estimate = await handleEstimateFindingAnalysis({
    auth: {uid: UID},
    data: request,
    firestore,
  });
  assert.equal(estimate.paymentMode, "flexCredits");
  assert.equal(estimate.eligible, true);
  assert.equal(estimate.reason, undefined);

  const result = await handleAnalyseFinding({
    auth: {uid: UID},
    data: {...request, area: "Kitchen", isPlumbingArea: false,
      idempotencyKey: "key_a"},
    firestore,
    storage: {} as unknown as Storage,
    apiKeys: {openai: "test-key"},
  });
  assert.equal(result.paymentMode, "flexCredits");
  assert.ok(result.creditsCharged > 0);
  assert.equal(
    await getWalletBalance(firestore, UID),
    START_BALANCE - result.creditsCharged
  );
});

test("a House Pass whose allowance is used up falls back to Flex " +
  "Credits automatically, and says why", async () => {
  const {firestore} = seeded({passStatus: "allowanceReached"});

  const estimate = await handleEstimateFindingAnalysis({
    auth: {uid: UID},
    data: request,
    firestore,
  });
  assert.equal(estimate.paymentMode, "flexCredits");
  assert.equal(estimate.eligible, true);
  assert.equal(estimate.reason, "housePassAllowanceReached");
});
