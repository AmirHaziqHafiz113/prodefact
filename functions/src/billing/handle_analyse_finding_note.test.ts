import assert from "node:assert/strict";
import {test, TestContext} from "node:test";
import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";
import {handleAnalyseFinding} from "./handle_analyse_finding";
import {fakeFirestore} from "./fakes";
import {defectCatalogue} from "../ai/defect_catalogue";

const noStorage = {} as unknown as Storage;

/**
 * @return {Firestore} a fake Firestore with a funded wallet.
 */
function seeded(): Firestore {
  const {db} = fakeFirestore({
    "users/uid_1/inspections/inspection_1/findings/finding_1": {},
    "users/uid_1/inspections/inspection_1": {},
    "users/uid_1/wallet/main": {
      userId: "uid_1", balanceTokens: 100_000_000, updatedAt: 0,
    },
  });
  return db as unknown as Firestore;
}

/**
 * @param {string} note the inspector's note.
 * @param {string} key the idempotency key.
 * @return {Record<string, unknown>} a callable payload.
 */
function payload(note: string, key: string) {
  return {
    inspectionId: "inspection_1", findingId: "finding_1", area: "Kitchen",
    isPlumbingArea: false, aiLevel: "smart", idempotencyKey: key, note,
  };
}

/**
 * @param {TestContext} t the test context.
 * @param {Function} respond the fake provider response.
 * @return {object} the captured request bodies.
 */
function stubProvider(t: TestContext, respond: () => Response) {
  const original = global.fetch;
  const bodies: string[] = [];
  global.fetch = (async (_url: unknown, init?: {body?: unknown}) => {
    bodies.push(String(init?.body ?? ""));
    return respond();
  }) as typeof fetch;
  t.after(() => {
    global.fetch = original;
  });
  return bodies;
}

const reply = (content: Record<string, unknown>) => new Response(
  JSON.stringify({
    choices: [{message: {content: JSON.stringify(content)}}],
    usage: {prompt_tokens: 1500, completion_tokens: 100},
  }), {status: 200});

test("the exact note reaches the provider prompt, with a prompt limited to " +
  "the locked component", async (t) => {
  const bodies = stubProvider(t, () => reply({
    catalogueEntryId: "wall.concrete_wall.03", confidence: 0.9,
    detectedElement: "Wall", detectedComponent: "Concrete Wall",
    noteImageAgreement: "supports", needsReview: false,
  }));
  const result = await handleAnalyseFinding({
    auth: {uid: "uid_1"}, data: payload("Wal por skim", "k1"),
    firestore: seeded(), storage: noStorage, apiKeys: {openai: "fake"},
  });
  assert.equal(result.classification?.catalogueEntryId,
    "wall.concrete_wall.03");
  assert.equal(bodies.length, 1);
  const body = bodies[0];
  assert.ok(body.includes("inspector note (PRIMARY, verbatim): Wal por skim"));
  assert.ok(body.includes("likely meaning: wall poor skim"));
  assert.ok(body.includes("note names component: Concrete Wall"));
  assert.ok(!/\\"door\.[a-z_]+\.\d+/.test(body) &&
    !body.includes("door.door_frame"), "no door ids offered to the model");
});

test("a provider answer outside the lock is discarded and the finding goes " +
  "to review with note-derived candidates", async (t) => {
  const doorId = defectCatalogue.entries.find(
    (e) => e.componentName === "Door Frame")!.id;
  stubProvider(t, () => reply({
    catalogueEntryId: doorId, confidence: 0.95, detectedElement: "Wall",
    detectedComponent: "Concrete Wall", noteImageAgreement: "supports",
    needsReview: false,
  }));
  const result = await handleAnalyseFinding({
    auth: {uid: "uid_1"}, data: payload("wall poor skim", "k2"),
    firestore: seeded(), storage: noStorage, apiKeys: {openai: "fake"},
  });
  const c = result.classification!;
  assert.equal(c.needsReview, true);
  assert.equal(c.catalogueEntryId, undefined);
  assert.ok((c.candidateEntryIds ?? []).every((id) =>
    defectCatalogue.getById(id)?.componentName === "Concrete Wall"));
});

test("when the AI fails, the error carries a NOTE-derived fallback — only " +
  "the locked component, nothing image-derived", async (t) => {
  stubProvider(t, () => new Response("server error", {status: 500}));
  await assert.rejects(
    () => handleAnalyseFinding({
      auth: {uid: "uid_1"}, data: payload("wall poor skim", "k3"),
      firestore: seeded(), storage: noStorage, apiKeys: {openai: "fake"},
    }),
    (error: unknown) => {
      assert.ok(error instanceof HttpsError);
      const details = error.details as {
        reason: string;
        noteFallback: {
          source: string; lockedComponentNames: string[];
          candidateEntryIds: string[]; likelyFromNoteCount: number;
        };
      };
      assert.equal(details.reason, "providerUnavailable");
      assert.equal(details.noteFallback.source, "note");
      assert.deepEqual(details.noteFallback.lockedComponentNames,
        ["Concrete Wall"]);
      assert.equal(details.noteFallback.candidateEntryIds[0],
        "wall.concrete_wall.03");
      assert.ok(details.noteFallback.candidateEntryIds.every((id) =>
        defectCatalogue.getById(id)?.componentName === "Concrete Wall"));
      return true;
    }
  );
});

test("an ambiguous note ('crack') has no note-derived fallback to attach",
  async (t) => {
    stubProvider(t, () => new Response("server error", {status: 500}));
    await assert.rejects(
      () => handleAnalyseFinding({
        auth: {uid: "uid_1"}, data: payload("crack", "k4"),
        firestore: seeded(), storage: noStorage, apiKeys: {openai: "fake"},
      }),
      (error: unknown) => {
        assert.ok(error instanceof HttpsError);
        assert.equal(
          (error.details as {noteFallback?: unknown}).noteFallback, undefined);
        return true;
      }
    );
  });
