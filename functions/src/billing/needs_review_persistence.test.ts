import assert from "node:assert/strict";
import {test, TestContext} from "node:test";
import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";
import {fakeFirestore} from "./fakes";
import {handleAnalyseFinding} from "./handle_analyse_finding";
import {AiLevel} from "./types";

/**
 * Queue P0 (2026-10-02): a stored classification with an unset field —
 * every needsReview answer has no catalogueEntryId, and a model may
 * omit confidence or reason — used to make the job write throw (real
 * Firestore rejects nested `undefined`). The job was never finalised,
 * the app parked the finding as "Queued for AI", and the replay failed
 * the same way. Every level, Fast included, must now finish.
 */

const UID = "uid_1";

/**
 * @return {Firestore} a fake Firestore with one owned finding and Credits.
 */
function seeded(): Firestore {
  const {db} = fakeFirestore({
    [`users/${UID}/inspections/inspection_1`]: {},
    [`users/${UID}/inspections/inspection_1/findings/finding_1`]: {},
    [`users/${UID}/wallet/main`]: {
      userId: UID,
      balanceCredits: 1000,
      updatedAt: 0,
    },
  });
  return db as unknown as Firestore;
}

/**
 * @param {TestContext} t the running test.
 * @param {object} answer the model's JSON answer.
 * @return {{calls: number}} how many provider calls were made.
 */
function stubOpenAi(
  t: TestContext,
  answer: Record<string, unknown>
): {calls: number} {
  const counter = {calls: 0};
  const original = global.fetch;
  global.fetch = (async () => {
    counter.calls++;
    return new Response(JSON.stringify({
      choices: [{message: {content: JSON.stringify(answer)}}],
      usage: {prompt_tokens: 100, completion_tokens: 20},
    }), {status: 200});
  }) as typeof fetch;
  t.after(() => {
    global.fetch = original;
  });
  return counter;
}

const call = (firestore: Firestore, level: AiLevel, key: string) =>
  handleAnalyseFinding({
    auth: {uid: UID},
    data: {inspectionId: "inspection_1", findingId: "finding_1",
      area: "Kitchen", isPlumbingArea: false, aiLevel: level,
      idempotencyKey: key},
    firestore,
    storage: {} as unknown as Storage,
    apiKeys: {openai: "test-key"},
  });

for (const level of ["fast", "smart", "expert"] as AiLevel[]) {
  test(`35. ${level}: a needsReview answer with no id, confidence or ` +
    "reason is stored and settled, and its replay returns it", async (t) => {
    const provider = stubOpenAi(t, {needsReview: true});
    const firestore = seeded();

    const first = await call(firestore, level, `key_${level}`);
    assert.equal(first.classification.needsReview, true);
    assert.equal(first.classification.catalogueEntryId, undefined);

    const replay = await call(firestore, level, `key_${level}`);
    assert.deepEqual(replay.classification, first.classification);
    assert.equal(provider.calls, 1, "a replay never calls the provider");
    assert.equal(replay.creditsCharged, first.creditsCharged);
  });

  test(`35. ${level}: unreadable model output still finishes as ` +
    "needsReview", async (t) => {
    const original = global.fetch;
    global.fetch = (async () => new Response(JSON.stringify({
      choices: [{message: {content: "not json"}}],
    }), {status: 200})) as typeof fetch;
    t.after(() => {
      global.fetch = original;
    });
    const result = await call(seeded(), level, `key_bad_${level}`);
    assert.equal(result.classification.needsReview, true);
  });
}
