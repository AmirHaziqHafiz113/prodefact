import assert from "node:assert/strict";
import {test, TestContext} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";
import {AI_JOB_LEASE_MS, handleAnalyseFinding} from "./handle_analyse_finding";
import {fakeFirestore} from "./fakes";
import {
  ConflictingLedgerEntryError,
  getWalletBalance,
  releaseReservation,
  reserveCredits,
  settleReservation,
} from "./wallet";
import {AiLevel} from "./types";

/**
 * Backend idempotency of `analyseFinding` per idempotencyKey: one
 * authoritative job per key, claimed atomically, advanced through
 * durable stages, and safely resumable by a replay after a crash —
 * without ever calling the provider twice, reserving or settling twice,
 * refunding a settled charge, or consuming House Pass allowance twice.
 */

const noStorage = {} as unknown as Storage;
const UID = "uid_1";
const START_BALANCE = 1000;
/** Any reservation amount works for the ledger-exclusivity test. */
const RESERVATION = 300;

type Doc = Record<string, unknown>;

/**
 * @param {object} [options] what to seed.
 * @return {object} the fake Firestore and its raw store.
 */
function seeded(options: {
  balance?: number;
  housePass?: {includedAiLevel: AiLevel; used?: number; limit?: number};
} = {}) {
  const seed: Record<string, Doc> = {
    [`users/${UID}/inspections/inspection_1`]: options.housePass ?
      {commercialMode: "housePass"} :
      {},
    [`users/${UID}/inspections/inspection_1/findings/finding_1`]: {},
    [`users/${UID}/inspections/inspection_1/findings/finding_2`]: {},
    [`users/${UID}/wallet/main`]: {
      userId: UID,
      balanceCredits: options.balance ?? START_BALANCE,
      updatedAt: 0,
    },
    "users/uid_2/inspections/inspection_9/findings/finding_9": {},
  };
  if (options.housePass) {
    seed[`users/${UID}/housePasses/hp_1`] = {
      id: "hp_1",
      inspectionId: "inspection_1",
      userId: UID,
      priceMyr: 30,
      currency: "MYR",
      status: "active",
      purchasedAt: 0,
      createdAt: 0,
      updatedAt: 0,
      allowanceConfigVersion: 0,
      includedAiLevel: options.housePass.includedAiLevel,
      allowanceUsed: options.housePass.used ?? 0,
      allowanceLimit: options.housePass.limit ?? 10,
    };
  }
  const {db, store} = fakeFirestore(seed);
  return {firestore: db as unknown as Firestore, store};
}

/**
 * @param {string} key the idempotency key.
 * @param {object} [overrides] payload overrides.
 * @return {Doc} a valid callable payload.
 */
function payload(key: string, overrides: Doc = {}): Doc {
  return {
    inspectionId: "inspection_1",
    findingId: "finding_1",
    area: "Kitchen",
    isPlumbingArea: false,
    aiLevel: "smart",
    idempotencyKey: key,
    ...overrides,
  };
}

/**
 * @param {Firestore} firestore the fake Firestore.
 * @param {Doc} data the callable payload.
 * @param {object} [options] caller and clock overrides.
 * @return {Promise<unknown>} the callable result.
 */
function analyse(
  firestore: Firestore,
  data: Doc,
  options: {uid?: string | null; now?: () => number} = {}
) {
  return handleAnalyseFinding({
    auth: options.uid === null ? null : {uid: options.uid ?? UID},
    data,
    firestore,
    storage: noStorage,
    apiKeys: {openai: "test-key"},
    now: options.now,
  });
}

/** @return {Response} a successful OpenAI classification response. */
function okResponse(): Response {
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
      usage: {prompt_tokens: 1000, completion_tokens: 200},
    }),
    {status: 200}
  );
}

/** @return {Response} a non-transient provider failure. */
function failResponse(): Response {
  return new Response("upstream exploded", {status: 400});
}

/**
 * Stubs the OpenAI HTTP call. Each call can be held open until the test
 * releases it, to observe state while a provider call is in flight.
 * @param {TestContext} t the running test.
 * @param {Function} [respond] the response for each 1-indexed call.
 * @return {object} the call counter and per-call release controls.
 */
function stubProvider(
  t: TestContext,
  respond: (call: number) => Response = () => okResponse()
) {
  const original = global.fetch;
  let calls = 0;
  const gates: Map<number, () => void> = new Map();
  const held = new Set<number>();
  global.fetch = (async () => {
    calls++;
    const call = calls;
    if (held.has(call)) {
      await new Promise<void>((resolve) => gates.set(call, resolve));
    }
    return respond(call);
  }) as typeof fetch;
  t.after(() => {
    global.fetch = original;
  });
  return {
    calls: () => calls,
    // Holds the given call open until `release` is called.
    hold: (call: number) => held.add(call),
    release: (call: number) => {
      const open = gates.get(call);
      if (open) open();
    },
    // Resolves once the given call has started.
    started: async (call: number) => {
      while (!gates.has(call)) await new Promise((r) => setImmediate(r));
    },
  };
}

/**
 * @param {Map<string, Doc>} store the raw fake store.
 * @param {string} key the idempotency key.
 * @return {Doc | undefined} the job document.
 */
function job(store: Map<string, Doc>, key: string): Doc | undefined {
  return store.get(`users/${UID}/aiJobs/${key}`);
}

/**
 * @param {Map<string, Doc>} store the raw fake store.
 * @param {string} id the ledger entry id.
 * @return {boolean} whether it exists.
 */
function hasLedger(store: Map<string, Doc>, id: string): boolean {
  return store.has(`users/${UID}/walletTransactions/${id}`);
}

/**
 * @param {Map<string, Doc>} store the raw fake store.
 * @return {string[]} every ledger entry id.
 */
function ledgerIds(store: Map<string, Doc>): string[] {
  const prefix = `users/${UID}/walletTransactions/`;
  return [...store.keys()]
    .filter((p) => p.startsWith(prefix))
    .map((p) => p.slice(prefix.length));
}

/**
 * @param {Map<string, Doc>} store the raw fake store.
 * @return {number} the House Pass's consumed allowance.
 */
function allowanceUsed(store: Map<string, Doc>): number {
  return store.get(`users/${UID}/housePasses/hp_1`)?.allowanceUsed as number;
}

/**
 * Rewinds a completed job to how it looked if its invocation had died
 * right after reaching [stage], with an expired lease — the durable
 * state a real crash leaves behind (ledger entries already written stay
 * exactly as they are).
 * @param {Map<string, Doc>} store the raw fake store.
 * @param {string} key the idempotency key.
 * @param {string} stage the last durable stage.
 */
function simulateCrashAfter(
  store: Map<string, Doc>,
  key: string,
  stage: string
) {
  const path = `users/${UID}/aiJobs/${key}`;
  const completed = store.get(path) as Doc;
  const crashed: Doc = {
    ...completed,
    status: "in_progress",
    stage,
    claimId: "dead-invocation",
    leaseExpiresAt: 0,
    creditsCharged: 0,
  };
  delete crashed.housePassUsageRecorded;
  store.set(path, crashed);
}

/**
 * @param {unknown} error a thrown value.
 * @param {string} code the expected HttpsError code.
 * @param {string} [reason] the expected `details.reason`.
 * @return {boolean} true, for `assert.rejects`.
 */
function isHttpsError(error: unknown, code: string, reason?: string) {
  assert.ok(error instanceof HttpsError, String(error));
  assert.equal(error.code, code);
  if (reason) {
    assert.equal((error.details as {reason?: string}).reason, reason);
  }
  return true;
}

/**
 * Starts two requests with the same key at once. Either may win the
 * claim; the loser must be refused as in progress while the winner's
 * provider call is still held open.
 * @param {Firestore} firestore the fake Firestore.
 * @param {object} provider the held provider stub.
 * @return {Promise<unknown>} the winner's result.
 */
async function raceDuplicateRequests(
  firestore: Firestore,
  provider: ReturnType<typeof stubProvider>
): Promise<unknown> {
  provider.hold(1);
  const settle = (p: Promise<unknown>) => p.then(
    (value) => ({ok: true as const, value}),
    (error: unknown) => ({ok: false as const, error})
  );
  const requests = [
    settle(analyse(firestore, payload("key_a"))),
    settle(analyse(firestore, payload("key_a"))),
  ];
  await provider.started(1);
  // The loser settles without the held provider call ever finishing.
  const loser = await Promise.race(requests);
  assert.equal(loser.ok, false, "the duplicate must not run");
  if (!loser.ok) {
    isHttpsError(loser.error, "unavailable", "analysisInProgress");
  }
  provider.release(1);
  const outcomes = await Promise.all(requests);
  const winners = outcomes.filter((o) => o.ok);
  assert.equal(winners.length, 1);
  return (winners[0] as {value: unknown}).value;
}

// ---- 1-5: the job lifecycle ----

test("1. the first request claims the job before the provider runs, " +
  "and ends it succeeded", async (t) => {
  const provider = stubProvider(t);
  provider.hold(1);
  const {firestore, store} = seeded();

  const pending = analyse(firestore, payload("key_a"));
  await provider.started(1);

  const inFlight = job(store, "key_a");
  assert.equal(inFlight?.status, "in_progress");
  assert.equal(inFlight?.stage, "reserved");
  assert.equal(typeof inFlight?.claimId, "string");
  assert.ok((inFlight?.leaseExpiresAt as number) > Date.now());
  assert.ok(hasLedger(store, "key_a_reservation"));

  provider.release(1);
  await pending;
  const done = job(store, "key_a");
  assert.equal(done?.status, "succeeded");
  assert.equal(done?.claimCount, 1);
  assert.ok(done?.classification);
});

test("2. two concurrent requests with the same key: one provider call, " +
  "one reservation, one settlement; the other is told it is in progress",
async (t) => {
  const provider = stubProvider(t);
  const {firestore, store} = seeded();

  const result = await raceDuplicateRequests(firestore, provider) as {
    creditsCharged: number;
  };

  assert.equal(provider.calls(), 1);
  assert.deepEqual(
    ledgerIds(store).filter((id) => !id.endsWith("_settlement_release")),
    ["key_a_reservation", "key_a_settlement"]
  );
  assert.equal(
    await getWalletBalance(firestore, UID),
    START_BALANCE - result.creditsCharged
  );
});

test("3 + 4. a completed replay returns the stored result without " +
  "calling the provider, reserving, or charging", async (t) => {
  const provider = stubProvider(t);
  const {firestore, store} = seeded();

  const original = await analyse(firestore, payload("key_a"));
  const balance = await getWalletBalance(firestore, UID);
  const ledger = ledgerIds(store).sort();

  const replay = await analyse(firestore, payload("key_a"));

  assert.deepEqual(replay, original);
  assert.equal(provider.calls(), 1);
  assert.equal(await getWalletBalance(firestore, UID), balance);
  assert.deepEqual(ledgerIds(store).sort(), ledger);
});

test("5. a replay while the job is in progress never calls the provider " +
  "again and moves no Credits", async (t) => {
  const provider = stubProvider(t);
  provider.hold(1);
  const {firestore, store} = seeded();

  const pending = analyse(firestore, payload("key_a"));
  await provider.started(1);
  const ledger = ledgerIds(store).sort();

  await assert.rejects(
    analyse(firestore, payload("key_a")),
    (error) => isHttpsError(error, "unavailable", "analysisInProgress")
  );
  assert.equal(provider.calls(), 1);
  assert.deepEqual(ledgerIds(store).sort(), ledger);

  provider.release(1);
  await pending;
});

// ---- 6-8: Credits ----

test("6 + 7. under a lease takeover (the first invocation presumed " +
  "dead), the same key still reserves once and settles once", async (t) => {
  const provider = stubProvider(t);
  provider.hold(1);
  const {firestore, store} = seeded();
  const t0 = Date.now();

  const stale = analyse(firestore, payload("key_a"), {now: () => t0});
  await provider.started(1);

  const takeover = await analyse(firestore, payload("key_a"), {
    now: () => t0 + AI_JOB_LEASE_MS + 1,
  }) as {creditsCharged: number};
  assert.equal(job(store, "key_a")?.claimCount, 2);

  // The original invocation wakes up after losing its claim: it must
  // not write anything.
  provider.release(1);
  await assert.rejects(
    stale,
    (error) => isHttpsError(error, "unavailable", "analysisInProgress")
  );

  const reservations = ledgerIds(store).filter((id) =>
    id.endsWith("_reservation"));
  const settlements = ledgerIds(store).filter((id) =>
    id.endsWith("_settlement"));
  assert.deepEqual(reservations, ["key_a_reservation"]);
  assert.deepEqual(settlements, ["key_a_settlement"]);
  assert.equal(
    await getWalletBalance(firestore, UID),
    START_BALANCE - takeover.creditsCharged
  );
  assert.equal(job(store, "key_a")?.status, "succeeded");
});

test("8. a failed provider call releases the reservation exactly once, " +
  "and a replay neither releases again nor charges", async (t) => {
  const provider = stubProvider(t, () => failResponse());
  const {firestore, store} = seeded();

  await assert.rejects(
    analyse(firestore, payload("key_a")),
    (error) => isHttpsError(error, "internal")
  );
  assert.equal(await getWalletBalance(firestore, UID), START_BALANCE);
  assert.ok(hasLedger(store, "key_a_release_failed"));
  assert.equal(job(store, "key_a")?.status, "failed");

  await assert.rejects(
    analyse(firestore, payload("key_a")),
    (error) => isHttpsError(error, "internal")
  );
  assert.equal(provider.calls(), 1);
  assert.equal(await getWalletBalance(firestore, UID), START_BALANCE);
  assert.equal(
    ledgerIds(store).filter((id) => id.includes("release_failed")).length,
    1
  );
});

// ---- 9-10: House Pass ----

test("9. concurrent requests with the same key consume House Pass " +
  "allowance once", async (t) => {
  const provider = stubProvider(t);
  const {firestore, store} = seeded({housePass: {includedAiLevel: "smart"}});

  await raceDuplicateRequests(firestore, provider);

  assert.equal(allowanceUsed(store), 1);
  assert.equal(provider.calls(), 1);
});

test("10. a House Pass replay consumes no more allowance; a different " +
  "finding with its own key consumes separately", async (t) => {
  stubProvider(t);
  const {firestore, store} = seeded({housePass: {includedAiLevel: "smart"}});

  await analyse(firestore, payload("key_a"));
  assert.equal(allowanceUsed(store), 1);
  assert.ok(store.has(`users/${UID}/housePasses/hp_1/usages/key_a`));

  await analyse(firestore, payload("key_a"));
  assert.equal(allowanceUsed(store), 1);

  await analyse(firestore, payload("key_b", {findingId: "finding_2"}));
  assert.equal(allowanceUsed(store), 2);
});

test("a failed House Pass analysis consumes no allowance", async (t) => {
  stubProvider(t, () => failResponse());
  const {firestore, store} = seeded({housePass: {includedAiLevel: "smart"}});

  await assert.rejects(analyse(firestore, payload("key_a")));

  assert.equal(allowanceUsed(store), 0);
  assert.equal(job(store, "key_a")?.status, "failed");
});

test("a replay after a crash between House Pass consumption and job " +
  "completion consumes nothing more", async (t) => {
  const provider = stubProvider(t);
  const {firestore, store} = seeded({housePass: {includedAiLevel: "smart"}});

  await analyse(firestore, payload("key_a"));
  // Allowance was consumed, then the invocation "died" before the job
  // was marked succeeded.
  simulateCrashAfter(store, "key_a", "settled");

  await analyse(firestore, payload("key_a"));

  assert.equal(allowanceUsed(store), 1);
  assert.equal(provider.calls(), 1);
  assert.equal(job(store, "key_a")?.status, "succeeded");
});

// ---- 11-13: crash after settlement ----

for (const stage of ["providerCompleted", "settled"]) {
  test(`11 + 12. a replay after a crash at stage "${stage}" finishes from ` +
    "the stored result: no provider call, no refund, no second charge",
  async (t) => {
    const provider = stubProvider(t);
    const {firestore, store} = seeded();

    const original = await analyse(firestore, payload("key_a")) as {
      creditsCharged: number;
      classification: unknown;
    };
    const chargedBalance = await getWalletBalance(firestore, UID);
    assert.equal(chargedBalance, START_BALANCE - original.creditsCharged);
    simulateCrashAfter(store, "key_a", stage);

    const replay = await analyse(firestore, payload("key_a")) as {
      creditsCharged: number;
      classification: unknown;
    };

    assert.equal(provider.calls(), 1);
    assert.equal(await getWalletBalance(firestore, UID), chargedBalance);
    assert.equal(hasLedger(store, "key_a_release_failed"), false);
    assert.deepEqual(replay.classification, original.classification);
    assert.equal(replay.creditsCharged, original.creditsCharged);
    assert.equal(job(store, "key_a")?.status, "succeeded");
  });
}

test("a settled reservation can never also be refunded in full, and a " +
  "released one can never also be charged", async () => {
  const {firestore} = seeded();
  const reservation = await reserveCredits(firestore, {
    uid: UID,
    amountCredits: RESERVATION,
    idempotencyKey: "k_reservation",
    inspectionId: "inspection_1",
    findingId: "finding_1",
    aiLevel: "smart",
    description: "test",
  });
  await settleReservation(firestore, {
    uid: UID,
    reservationTransactionId: reservation.id,
    actualCredits: 10,
    idempotencyKey: "k_settlement",
    description: "test",
    exclusiveOf: "k_release_failed",
  });
  const settled = await getWalletBalance(firestore, UID);

  await assert.rejects(
    releaseReservation(firestore, {
      uid: UID,
      reservationTransactionId: reservation.id,
      idempotencyKey: "k_release_failed",
      description: "test",
      exclusiveOf: "k_settlement",
    }),
    ConflictingLedgerEntryError
  );
  assert.equal(await getWalletBalance(firestore, UID), settled);

  const other = await reserveCredits(firestore, {
    uid: UID,
    amountCredits: RESERVATION,
    idempotencyKey: "j_reservation",
    inspectionId: "inspection_1",
    findingId: "finding_2",
    aiLevel: "smart",
    description: "test",
  });
  await releaseReservation(firestore, {
    uid: UID,
    reservationTransactionId: other.id,
    idempotencyKey: "j_release_failed",
    description: "test",
    exclusiveOf: "j_settlement",
  });
  const released = await getWalletBalance(firestore, UID);
  await assert.rejects(
    settleReservation(firestore, {
      uid: UID,
      reservationTransactionId: other.id,
      actualCredits: 10,
      idempotencyKey: "j_settlement",
      description: "test",
      exclusiveOf: "j_release_failed",
    }),
    ConflictingLedgerEntryError
  );
  assert.equal(await getWalletBalance(firestore, UID), released);
});

test("13. an unexpected error after Credits were settled is reported as " +
  "not finalised, keeps the job reconcilable, and the same key finishes " +
  "it without charging again", async (t) => {
  const provider = stubProvider(t);
  provider.hold(1);
  // Smart on a Fast-included pass: a Credits surcharge is settled
  // before the House Pass step runs.
  const {firestore, store} = seeded({housePass: {includedAiLevel: "fast"}});
  const passPath = `users/${UID}/housePasses/hp_1`;

  const pending = analyse(firestore, payload("key_a"));
  await provider.started(1);
  // Make the post-settlement House Pass step fail unexpectedly.
  const pass = store.get(passPath) as Doc;
  store.delete(passPath);
  provider.release(1);

  await assert.rejects(
    pending,
    (error) => isHttpsError(error, "unavailable", "analysisNotFinalised")
  );
  assert.ok(hasLedger(store, "key_a_settlement"));
  const charged = await getWalletBalance(firestore, UID);
  assert.ok(charged < START_BALANCE);
  const stuck = job(store, "key_a");
  assert.equal(stuck?.status, "in_progress");
  assert.equal(stuck?.stage, "settled");
  assert.equal(stuck?.leaseExpiresAt, 0, "a replay may take over at once");

  store.set(passPath, pass);
  const replay = await analyse(firestore, payload("key_a")) as {
    creditsCharged: number;
  };

  assert.equal(provider.calls(), 1);
  assert.equal(await getWalletBalance(firestore, UID), charged);
  assert.equal(replay.creditsCharged, START_BALANCE - charged);
  assert.equal(allowanceUsed(store), 1);
  assert.equal(hasLedger(store, "key_a_release_failed"), false);
  assert.equal(job(store, "key_a")?.status, "succeeded");
});

// ---- 14-16: independence and access control ----

test("14. different idempotency keys are independent analyses", async (t) => {
  const provider = stubProvider(t);
  const {firestore, store} = seeded();

  const a = await analyse(firestore, payload("key_a")) as {
    creditsCharged: number;
  };
  const b = await analyse(firestore, payload("key_b")) as {
    creditsCharged: number;
  };

  assert.equal(provider.calls(), 2);
  assert.equal(job(store, "key_a")?.status, "succeeded");
  assert.equal(job(store, "key_b")?.status, "succeeded");
  assert.equal(
    await getWalletBalance(firestore, UID),
    START_BALANCE - a.creditsCharged - b.creditsCharged
  );
});

test("a key already used for another finding is refused, never " +
  "applied to the wrong finding", async (t) => {
  const provider = stubProvider(t);
  const {firestore} = seeded();

  await analyse(firestore, payload("key_a"));
  await assert.rejects(
    analyse(firestore, payload("key_a", {findingId: "finding_2"})),
    (error) => isHttpsError(error, "invalid-argument")
  );
  assert.equal(provider.calls(), 1);
});

test("15. an unauthenticated caller is rejected before any job exists",
  async (t) => {
    const provider = stubProvider(t);
    const {firestore, store} = seeded();

    await assert.rejects(
      analyse(firestore, payload("key_a"), {uid: null}),
      (error) => isHttpsError(error, "unauthenticated")
    );
    assert.equal(job(store, "key_a"), undefined);
    assert.equal(provider.calls(), 0);
  });

test("16. a caller who does not own the finding is rejected before any " +
  "job exists", async (t) => {
  const provider = stubProvider(t);
  const {firestore, store} = seeded();

  await assert.rejects(
    analyse(
      firestore,
      payload("key_a", {inspectionId: "inspection_9", findingId: "finding_9"})
    ),
    (error) => isHttpsError(error, "permission-denied")
  );
  assert.equal(job(store, "key_a"), undefined);
  assert.equal(provider.calls(), 0);
});

test("an insufficient balance fails the job definitively without " +
  "reserving or calling the provider", async (t) => {
  const provider = stubProvider(t);
  const {firestore, store} = seeded({balance: 0});

  await assert.rejects(
    analyse(firestore, payload("key_a")),
    (error) => isHttpsError(error, "failed-precondition")
  );
  assert.equal(provider.calls(), 0);
  assert.deepEqual(ledgerIds(store), []);
  assert.equal(job(store, "key_a")?.status, "failed");
});

test("QA #27/#29: an exhausted provider quota fails the job definitively " +
  "(resource-exhausted, not deadline-exceeded), refunds, and replays " +
  "report the same failure without calling the provider again",
async (t) => {
  let calls = 0;
  const original = global.fetch;
  global.fetch = (async () => {
    calls++;
    return new Response(
      JSON.stringify({error: {code: "insufficient_quota"}}),
      {status: 429}
    );
  }) as typeof fetch;
  t.after(() => {
    global.fetch = original;
  });
  const {firestore, store} = seeded();

  await assert.rejects(
    analyse(firestore, payload("key_q")),
    (error) => {
      isHttpsError(error, "resource-exhausted", "providerQuotaExceeded");
      return true;
    }
  );
  assert.equal(calls, 1, "a quota failure is never retried");
  assert.equal(await getWalletBalance(firestore, UID), START_BALANCE);
  assert.equal(job(store, "key_q")?.status, "failed");
  assert.equal(job(store, "key_q")?.failureReason, "provider_quotaExceeded");

  await assert.rejects(
    analyse(firestore, payload("key_q")),
    (error) => isHttpsError(error, "internal")
  );
  assert.equal(calls, 1);
});
