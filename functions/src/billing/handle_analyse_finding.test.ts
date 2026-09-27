import assert from "node:assert/strict";
import {test, TestContext} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";
import {handleAnalyseFinding} from "./handle_analyse_finding";
import {fakeFirestore} from "./fakes";
import {getWalletBalance} from "./wallet";
import {actualCreditsForUsage} from "./pricing";
import {DEFAULT_PRICING_CONFIG} from "./pricing_config";
import {AiLevel} from "./types";

const noStorage = {} as unknown as Storage;

/**
 * @param {number} balanceCredits the seeded wallet balance.
 * @param {Record<string, unknown>} [inspection] fields to seed on the
 *   inspection doc (e.g. `{commercialMode: "housePass"}`).
 * @param {Record<string, unknown>} [housePass] a House Pass doc to
 *   seed at `users/uid_1/housePasses/hp_1`, if provided.
 * @return {object} `{firestore, store}` — the fake Firestore (castable
 *   at each call site) and the raw underlying doc map, for asserting
 *   against documents the callable itself never returns.
 */
function seededFirestore(
  balanceCredits: number,
  inspection: Record<string, unknown> = {},
  housePass?: Record<string, unknown>
) {
  const seed: Record<string, Record<string, unknown>> = {
    "users/uid_1/inspections/inspection_1/findings/finding_1": {},
    "users/uid_1/inspections/inspection_1": inspection,
    "users/uid_1/wallet/main": {
      userId: "uid_1",
      balanceCredits,
      updatedAt: 0,
    },
  };
  if (housePass) {
    seed["users/uid_1/housePasses/hp_1"] = housePass;
  }
  const {db, store} = fakeFirestore(seed);
  return {firestore: db as unknown as Firestore, store};
}

/**
 * @param {string} status active/allowanceReached/etc.
 * @param {AiLevel} includedAiLevel the pass's included tier.
 * @param {number} allowanceUsed findings already consumed.
 * @param {number} allowanceLimit the fair-use allowance.
 * @return {Record<string, unknown>} a House Pass doc.
 */
function housePassDoc(
  status: string,
  includedAiLevel: AiLevel,
  allowanceUsed: number,
  allowanceLimit: number
) {
  return {
    id: "hp_1",
    inspectionId: "inspection_1",
    userId: "uid_1",
    priceMyr: 30,
    currency: "MYR",
    status,
    purchasedAt: 0,
    createdAt: 0,
    updatedAt: 0,
    allowanceConfigVersion: 0,
    includedAiLevel,
    allowanceUsed,
    allowanceLimit,
  };
}

/**
 * @param {AiLevel} aiLevel the requested AI tier.
 * @param {string} idempotencyKey this attempt's idempotency key.
 * @return {Record<string, unknown>} a valid callable payload.
 */
function payload(aiLevel: AiLevel, idempotencyKey: string) {
  return {
    inspectionId: "inspection_1",
    findingId: "finding_1",
    area: "Kitchen",
    isPlumbingArea: false,
    aiLevel,
    idempotencyKey,
  };
}

/**
 * @param {TestContext} t the running test's context.
 * @param {Function} respond produces the fake OpenAI response for each
 *   call (1-indexed) — `(calls: number) => Response | Promise<Response>`.
 * @return {Function} a `() => number` getter for how many times fetch
 *   was called.
 */
function stubOpenAi(
  t: TestContext,
  respond: (calls: number) => Response | Promise<Response>
): () => number {
  const original = global.fetch;
  let calls = 0;
  global.fetch = (async () => {
    calls++;
    return respond(calls);
  }) as typeof fetch;
  t.after(() => {
    global.fetch = original;
  });
  return () => calls;
}

/**
 * @param {object} [usage] optional token usage to report.
 * @return {Response} a fake successful OpenAI classification response.
 */
function okResponse(usage?: {
  prompt_tokens: number;
  completion_tokens: number;
}): Response {
  return new Response(
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
      usage,
    }),
    {status: 200}
  );
}

test("an unauthenticated request is rejected before anything is " +
  "touched", async () => {
  const {firestore} = seededFirestore(1000);
  await assert.rejects(
    () =>
      handleAnalyseFinding({
        auth: null,
        data: payload("smart", "job_1"),
        firestore,
        storage: noStorage,
        apiKeys: {openai: "fake-key"},
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal((error as HttpsError).code, "unauthenticated");
      return true;
    }
  );
});

test("insufficient Credits blocks the request before the AI provider " +
  "is ever called — no reservation, no charge", async (t) => {
  const calls = stubOpenAi(t, () => okResponse());
  const {firestore} = seededFirestore(0); // no balance at all

  await assert.rejects(
    () =>
      handleAnalyseFinding({
        auth: {uid: "uid_1"},
        data: payload("smart", "job_1"),
        firestore,
        storage: noStorage,
        apiKeys: {openai: "fake-key"},
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal((error as HttpsError).code, "failed-precondition");
      return true;
    }
  );
  assert.equal(calls(), 0);
  assert.equal(await getWalletBalance(firestore, "uid_1"), 0);
});

test("a successful Flex Credits analysis reserves the maximum, then " +
  "settles to the real usage-based charge and refunds the unused " +
  "portion", async (t) => {
  stubOpenAi(
    t,
    () => okResponse({prompt_tokens: 1500, completion_tokens: 100})
  );
  const {firestore} = seededFirestore(10_000);

  const result = await handleAnalyseFinding({
    auth: {uid: "uid_1"},
    data: payload("smart", "job_1"),
    firestore,
    storage: noStorage,
    apiKeys: {openai: "fake-key"},
  });

  const expectedCharge = actualCreditsForUsage(
    "smart",
    1500,
    100,
    DEFAULT_PRICING_CONFIG
  );
  assert.equal(result.creditsCharged, expectedCharge);
  assert.equal(result.newBalance, 10_000 - expectedCharge);
  assert.equal(
    result.classification.catalogueEntryId,
    "wall.concrete_wall.05"
  );
  const balance = await getWalletBalance(firestore, "uid_1");
  assert.equal(balance, 10_000 - expectedCharge);
});

test("a failed AI provider call releases the reservation in full — the " +
  "inspector is never charged for a failed analysis", async (t) => {
  stubOpenAi(t, () => new Response("server error", {status: 500}));
  const {firestore} = seededFirestore(10_000);

  await assert.rejects(
    () =>
      handleAnalyseFinding({
        auth: {uid: "uid_1"},
        data: payload("smart", "job_1"),
        firestore,
        storage: noStorage,
        apiKeys: {openai: "fake-key"},
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      // The job is already recorded as failed and refunded, so the code
      // must be one the app treats as definite. `deadline-exceeded`
      // made it park the finding as "Queued for AI" (QA #27).
      assert.equal((error as HttpsError).code, "internal");
      assert.equal(
        ((error as HttpsError).details as {reason: string}).reason,
        "providerUnavailable"
      );
      return true;
    }
  );
  assert.equal(await getWalletBalance(firestore, "uid_1"), 10_000);
});

test("a duplicate call with the same idempotencyKey never re-invokes " +
  "the AI provider and never charges twice (duplicate-tap protection)",
async (t) => {
  const calls = stubOpenAi(
    t,
    () => okResponse({prompt_tokens: 1500, completion_tokens: 100})
  );
  const {firestore} = seededFirestore(10_000);
  const request = {
    auth: {uid: "uid_1"},
    data: payload("smart", "job_1"),
    firestore,
    storage: noStorage,
    apiKeys: {openai: "fake-key"},
  };

  const first = await handleAnalyseFinding(request);
  const second = await handleAnalyseFinding(request);

  assert.equal(calls(), 1); // the provider was only ever invoked once
  assert.equal(first.creditsCharged, second.creditsCharged);
  assert.equal(second.newBalance, first.newBalance);
});

test("a House Pass finding fully within the included tier charges 0 " +
  "Credits and consumes one unit of the pass's allowance", async (t) => {
  stubOpenAi(
    t,
    () => okResponse({prompt_tokens: 1500, completion_tokens: 100})
  );
  const {firestore, store} = seededFirestore(
    10_000,
    {commercialMode: "housePass"},
    housePassDoc("active", "smart", 0, 5)
  );

  const result = await handleAnalyseFinding({
    auth: {uid: "uid_1"},
    data: payload("smart", "job_1"), // matches the pass's included level
    firestore,
    storage: noStorage,
    apiKeys: {openai: "fake-key"},
  });

  assert.equal(result.creditsCharged, 0);
  assert.equal(result.paymentMode, "housePass");
  // Wallet Credits are untouched — House Pass usage isn't a Credits
  // transaction at all.
  assert.equal(await getWalletBalance(firestore, "uid_1"), 10_000);

  const pass = store.get("users/uid_1/housePasses/hp_1") as {
    allowanceUsed: number;
  };
  assert.equal(pass.allowanceUsed, 1);
});

test("a House Pass finding above the included tier charges only the " +
  "surcharge in Credits", async (t) => {
  stubOpenAi(
    t,
    () => okResponse({prompt_tokens: 1500, completion_tokens: 100})
  );
  const {firestore} = seededFirestore(
    10_000,
    {commercialMode: "housePass"},
    housePassDoc("active", "smart", 0, 5)
  );

  const result = await handleAnalyseFinding({
    auth: {uid: "uid_1"},
    data: payload("expert", "job_1"), // above the pass's included "smart"
    firestore,
    storage: noStorage,
    apiKeys: {openai: "fake-key"},
  });

  assert.ok(result.creditsCharged > 0);
  assert.equal(result.newBalance, 10_000 - result.creditsCharged);
});

test("a House Pass with its allowance already reached falls back to " +
  "Flex Credits rather than blocking the analysis", async (t) => {
  stubOpenAi(
    t,
    () => okResponse({prompt_tokens: 1500, completion_tokens: 100})
  );
  const {firestore} = seededFirestore(
    10_000,
    {commercialMode: "housePass"},
    housePassDoc("allowanceReached", "smart", 5, 5)
  );

  const result = await handleAnalyseFinding({
    auth: {uid: "uid_1"},
    data: payload("smart", "job_1"),
    firestore,
    storage: noStorage,
    apiKeys: {openai: "fake-key"},
  });

  assert.equal(result.paymentMode, "flexCredits");
  assert.ok(result.creditsCharged > 0);
});

test("with no OpenAI key configured, the request fails clearly " +
  "instead of throwing deep inside the provider gateway", async () => {
  const {firestore} = seededFirestore(10_000);
  await assert.rejects(
    () =>
      handleAnalyseFinding({
        auth: {uid: "uid_1"},
        data: payload("smart", "job_1"),
        firestore,
        storage: noStorage,
        apiKeys: {}, // no openai key
      }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      assert.equal((error as HttpsError).code, "failed-precondition");
      return true;
    }
  );
});
