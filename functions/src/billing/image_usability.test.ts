import assert from "node:assert/strict";
import {test, TestContext} from "node:test";
import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";
import {fakeFirestore} from "./fakes";
import {handleAnalyseFinding} from "./handle_analyse_finding";
import {validateAndNormalize} from "../ai/gateway";
import {buildSystemPrompt, promptCatalogueFor} from "../ai/prompt";

/**
 * Image usability (2026-10-04): the SAME classification request also
 * reports whether the photo was usable, with controlled quality issues.
 * No separate quality request; imperfect quality alone never rejects a
 * classification — the inspector's note stays the primary evidence.
 */

const UID = "uid_1";
const API_KEY = "sk-test-SECRET-KEY";
const NOTE = "holo wall tile PRIVATE-NOTE-MARKER";
const input = {
  inspectionId: "inspection_1",
  findingId: "finding_1",
  area: "Master Bathroom",
  isPlumbingArea: true,
  note: NOTE,
};

/**
 * @return {{db: Firestore, store: Map<string, Record<string, unknown>>}}
 *   a fake Firestore with one owned finding and Credits.
 */
function seeded() {
  const {db, store} = fakeFirestore({
    [`users/${UID}/inspections/inspection_1`]: {},
    [`users/${UID}/inspections/inspection_1/findings/finding_1`]: {},
    [`users/${UID}/wallet/main`]: {
      userId: UID,
      balanceCredits: 1000,
      updatedAt: 0,
    },
  });
  return {db: db as unknown as Firestore, store};
}

/**
 * @param {TestContext} t the running test.
 * @param {object} answer the model's JSON answer.
 * @return {{bodies: string[], lines: string[]}} requests and logs.
 */
function stub(t: TestContext, answer: Record<string, unknown>) {
  const bodies: string[] = [];
  const lines: string[] = [];
  const originalFetch = global.fetch;
  global.fetch = (async (_url: unknown, init?: RequestInit) => {
    bodies.push(String(init?.body));
    return new Response(JSON.stringify({
      choices: [{message: {content: JSON.stringify(answer)}}],
      usage: {prompt_tokens: 2400, completion_tokens: 70},
    }), {status: 200});
  }) as typeof fetch;
  const originals = {info: console.info, log: console.log,
    warn: console.warn, error: console.error};
  const capture = (...args: unknown[]) => {
    lines.push(args.map((a) =>
      typeof a === "string" ? a : JSON.stringify(a)).join(" "));
  };
  Object.assign(console, {info: capture, log: capture, warn: capture,
    error: capture});
  t.after(() => {
    global.fetch = originalFetch;
    Object.assign(console, originals);
  });
  return {bodies, lines};
}

const analyse = (firestore: Firestore, key: string) =>
  handleAnalyseFinding({
    auth: {uid: UID},
    data: {...input, aiLevel: "smart", idempotencyKey: key},
    firestore,
    storage: {} as unknown as Storage,
    apiKeys: {openai: API_KEY},
  });

test("11. a visually subtle defect still classifies from the note: the " +
  "photo confirms the tile, so it is usable", async (t) => {
  const {bodies} = stub(t, {
    isRelevantInspectionImage: true,
    imageUsable: true,
    qualityIssues: [],
    catalogueEntryId: "wall.wall_tile.04",
    defectTerm: "hollow",
    confidence: 0.82,
    needsReview: false,
  });
  const {db} = seeded();
  const r = await analyse(db, "key_subtle");
  assert.equal(bodies.length, 1);
  assert.equal(r.classification.catalogueEntryId, "wall.wall_tile.04");
  assert.equal(r.classification.needsReview, false);
  assert.equal(r.classification.imageUsable, true);
});

test("imperfect quality alone (blur noted, photo still usable) does not " +
  "reject a confident classification", () => {
  const r = validateAndNormalize(input, {
    findingId: "finding_1",
    isRelevantInspectionImage: true,
    imageUsable: true,
    qualityIssues: ["blur"],
    catalogueEntryId: "wall.wall_tile.04",
    defectTerm: "hollow",
    confidence: 0.8,
    needsReview: false,
  });
  assert.equal(r.needsReview, false);
  assert.deepEqual(r.qualityIssues, ["blur"]);
});

test("an unusable photo goes to the inspector (needsReview) with its " +
  "issues; only controlled issue values are kept", () => {
  const r = validateAndNormalize(input, {
    findingId: "finding_1",
    isRelevantInspectionImage: true,
    imageUsable: false,
    qualityIssues: ["Blur", "unclear", "bad vibes", "blur"],
    catalogueEntryId: "wall.wall_tile.04",
    defectTerm: "hollow",
    confidence: 0.9,
    needsReview: false,
  });
  assert.equal(r.imageUsable, false);
  assert.equal(r.needsReview, true);
  assert.deepEqual(r.qualityIssues, ["blur", "unclear"]);
});

test("12. an unrelated photo never gets a catalogue match and is marked " +
  "unusable/unrelated", () => {
  const r = validateAndNormalize(input, {
    findingId: "finding_1",
    isRelevantInspectionImage: false,
    catalogueEntryId: "wall.wall_tile.04",
    confidence: 0.9,
    needsReview: false,
  });
  assert.equal(r.catalogueEntryId, undefined);
  assert.equal(r.imageUsable, false);
  assert.deepEqual(r.qualityIssues, ["unrelated"]);
  assert.equal(r.needsReview, true);
});

test("8 + 9 + 10 + 15. a poor photo: ONE request, usability persisted on " +
  "the aiJob and returned to the app, logged without note/prompt/image",
async (t) => {
  const {bodies, lines} = stub(t, {
    isRelevantInspectionImage: true,
    imageUsable: false,
    qualityIssues: ["blur", "unclear"],
    catalogueEntryId: null,
    defectTerm: null,
    confidence: 0.3,
    shortReason: "The image appears relevant but is too unclear.",
    candidateEntryIds: [],
    needsReview: true,
  });
  const {db, store} = seeded();
  const r = await analyse(db, "key_poor");

  assert.equal(bodies.length, 1, "no separate quality request");
  assert.equal(r.classification.imageUsable, false);
  assert.deepEqual(r.classification.qualityIssues, ["blur", "unclear"]);
  assert.equal(r.classification.isRelevantInspectionImage, true);
  assert.ok(r.creditsCharged > 0, "an answered request is charged");

  const job = store.get(`users/${UID}/aiJobs/key_poor`)!;
  const classification = job.classification as Record<string, unknown>;
  assert.equal(classification.imageUsable, false);
  assert.deepEqual(classification.qualityIssues, ["blur", "unclear"]);
  assert.equal(classification.isRelevantInspectionImage, true);

  const usage = JSON.parse(lines.find((l) =>
    l.startsWith("provider_usage "))!.slice("provider_usage ".length));
  assert.equal(usage.imageUsable, false);
  assert.deepEqual(usage.qualityIssues, ["blur", "unclear"]);
  assert.equal(typeof usage.shortlistSize, "number");

  const all = lines.join("\n");
  for (const secret of [API_KEY, "PRIVATE-NOTE-MARKER", "holo wall tile",
    "IMAGE USABILITY", "CONTROLLED DEFECT CATALOGUE", "base64,"]) {
    assert.equal(all.includes(secret), false, `logged: ${secret}`);
  }

  // A replay returns the stored answer: still exactly one request.
  await analyse(db, "key_poor");
  assert.equal(bodies.length, 1);
});

test("the prompt asks for usability with the controlled vocabulary and " +
  "never grades angle, distance or framing", () => {
  const system = buildSystemPrompt(promptCatalogueFor(input));
  assert.match(system, /"imageUsable": boolean/);
  assert.match(system, /blur, too_dark,\noverexposed, subject_too_small/);
  assert.match(system, /does NOT make the photo unusable/);
  assert.match(system, /Never judge a photo by angle, distance or/);
});
