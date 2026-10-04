import assert from "node:assert/strict";
import {test, TestContext} from "node:test";
import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";
import {fakeFirestore} from "./fakes";
import {handleAnalyseFinding} from "./handle_analyse_finding";
import {defectCatalogue} from "../ai/defect_catalogue";
import {buildCatalogueShortlist} from "../ai/catalogue_shortlist";

/**
 * One finding = ONE paid provider request, with only a catalogue
 * shortlist in it (2026-10-04). Unrelated photos and uncertain answers
 * become needsReview — never a second, full-catalogue call — and are
 * charged like any other answered request.
 */

const UID = "uid_1";
const API_KEY = "sk-test-SECRET-KEY";
const NOTE = "holo wall tile PRIVATE-NOTE-MARKER";

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
 * Stubs OpenAI with [answer] and captures requests and console output.
 * @param {TestContext} t the running test.
 * @param {object} answer the model's JSON answer.
 * @return {{bodies: string[], lines: string[]}} what was sent and logged.
 */
function stub(
  t: TestContext,
  answer: Record<string, unknown>
): {bodies: string[]; lines: string[]} {
  const bodies: string[] = [];
  const lines: string[] = [];
  const originalFetch = global.fetch;
  global.fetch = (async (_url: unknown, init?: RequestInit) => {
    bodies.push(String(init?.body));
    return new Response(JSON.stringify({
      choices: [{message: {content: JSON.stringify(answer)}}],
      usage: {prompt_tokens: 2500, completion_tokens: 60},
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

const analyse = (firestore: Firestore, key: string, reanalysisAttempt = 0) =>
  handleAnalyseFinding({
    auth: {uid: UID},
    data: {inspectionId: "inspection_1", findingId: "finding_1",
      area: "Master Bathroom", isPlumbingArea: true, aiLevel: "smart",
      note: NOTE, idempotencyKey: key, reanalysisAttempt},
    firestore,
    storage: {} as unknown as Storage,
    apiKeys: {openai: API_KEY},
  });

/**
 * @param {string[]} lines captured console lines.
 * @return {Record<string, unknown>} the provider_usage payload.
 */
function usageLog(lines: string[]): Record<string, unknown> {
  const line = lines.find((l) => l.startsWith("provider_usage "));
  assert.ok(line);
  return JSON.parse(line.slice("provider_usage ".length));
}

test("1 + 8 + 9 + 11 + 12. a normal finding makes exactly one request " +
  "carrying only its shortlist; the answer is accepted and usage is " +
  "logged with the shortlist size", async (t) => {
  const {bodies, lines} = stub(t, {
    isRelevantInspectionImage: true,
    catalogueEntryId: "wall.wall_tile.04",
    defectTerm: "hollow",
    confidence: 0.9,
    needsReview: false,
  });
  const {db} = seeded();
  const result = await analyse(db, "key_normal");

  assert.equal(bodies.length, 1);
  assert.equal(result.classification.catalogueEntryId, "wall.wall_tile.04");
  assert.equal(result.classification.needsReview, false);

  const system = JSON.parse(bodies[0]).messages[0].content as string;
  const listed = defectCatalogue.entries.filter((e) =>
    system.includes(`${e.id} |`));
  const expected = buildCatalogueShortlist({note: NOTE,
    area: "Master Bathroom", isPlumbingArea: true}).entryIds;
  assert.equal(listed.length, expected.length);
  assert.ok(listed.length < defectCatalogue.entries.length);

  const log = usageLog(lines);
  assert.equal(log.shortlistSize, expected.length);
  assert.equal(log.totalCatalogueSize, defectCatalogue.entries.length);
  assert.equal(log.shortlistStrategy, "noteMatch");
  assert.equal(log.isRelevantInspectionImage, true);
  assert.equal(log.needsReview, false);
  assert.equal(log.inputTokens, 2500);
  assert.equal(log.totalTokens, 2560);
});

test("5 + 6 + 10. an unrelated image: needsReview with no entry, ONE " +
  "request, charged (no refund), and a replay calls nothing again",
async (t) => {
  const {bodies, lines} = stub(t, {
    isRelevantInspectionImage: false,
    catalogueEntryId: null,
    defectTerm: null,
    confidence: 0.96,
    shortReason: "Image does not appear related to home inspection.",
    candidateEntryIds: [],
    needsReview: true,
  });
  const {db, store} = seeded();
  const first = await analyse(db, "key_unrelated");

  assert.equal(bodies.length, 1);
  assert.equal(first.classification.needsReview, true);
  assert.equal(first.classification.catalogueEntryId, undefined);
  assert.ok(first.creditsCharged > 0, "the answered request is charged");
  const job = store.get(`users/${UID}/aiJobs/key_unrelated`)!;
  const classification = job.classification as Record<string, unknown>;
  assert.equal(classification.isRelevantInspectionImage, false);
  assert.equal(usageLog(lines).isRelevantInspectionImage, false);

  const replay = await analyse(db, "key_unrelated");
  assert.equal(bodies.length, 1, "a replay never calls the provider");
  assert.equal(replay.creditsCharged, first.creditsCharged);
});

test("7. a low-confidence answer becomes needsReview without any " +
  "second (full-catalogue) request", async (t) => {
  const {bodies} = stub(t, {
    isRelevantInspectionImage: true,
    catalogueEntryId: "wall.wall_tile.04",
    defectTerm: "hollow",
    confidence: 0.2,
    needsReview: false,
  });
  const {db} = seeded();
  const result = await analyse(db, "key_low");
  assert.equal(bodies.length, 1);
  assert.equal(result.classification.needsReview, true);
});

test("an answer outside the shortlist is needsReview, still one request",
  async (t) => {
    const outside = defectCatalogue.entries.find((e) =>
      e.mainElementName === "Door")!.id;
    const {bodies} = stub(t, {
      isRelevantInspectionImage: true,
      catalogueEntryId: outside,
      confidence: 0.95,
      needsReview: false,
    });
    const {db} = seeded();
    const result = await analyse(db, "key_outside");
    assert.equal(bodies.length, 1);
    assert.equal(result.classification.catalogueEntryId, undefined);
    assert.equal(result.classification.needsReview, true);
  });

test("13. no key, note text, prompt or image data is logged", async (t) => {
  const {bodies, lines} = stub(t, {
    isRelevantInspectionImage: true,
    catalogueEntryId: "wall.wall_tile.04",
    defectTerm: "hollow",
    confidence: 0.9,
    needsReview: false,
  });
  const {db} = seeded();
  await analyse(db, "key_safe");
  assert.ok(bodies[0].includes("PRIVATE-NOTE-MARKER"));
  const all = lines.join("\n");
  for (const secret of [API_KEY, "PRIVATE-NOTE-MARKER", "holo wall tile",
    "CONTROLLED DEFECT CATALOGUE", "EVIDENCE PRIORITY", "base64,",
    "wall.wall_tile.04 |"]) {
    assert.equal(all.includes(secret), false, `logged: ${secret}`);
  }
});

test("reanalysis: a fresh key is a genuinely new (charged) request; the " +
  "same key never calls the provider twice; logs carry the reasoning " +
  "fields and attempt number but no note", async (t) => {
  const {bodies, lines} = stub(t, {
    isRelevantInspectionImage: true,
    detectedElement: "Wall",
    detectedComponent: "Wall Tile",
    noteImageAgreement: "neutral",
    catalogueEntryId: "wall.wall_tile.04",
    defectTerm: "hollow",
    confidence: 0.85,
    needsReview: false,
  });
  const {db} = seeded();
  const first = await analyse(db, "key_first");
  await analyse(db, "key_first"); // a double tap / replay
  assert.equal(bodies.length, 1);

  const again = await analyse(db, "key_reanalyse_1", 1);
  assert.equal(bodies.length, 2, "intentional reanalysis is not blocked");
  assert.ok(again.creditsCharged > 0);
  assert.equal(first.classification.detectedComponent, "Wall Tile");
  assert.equal(again.classification.noteImageAgreement, "neutral");

  const usage = lines.filter((l) => l.startsWith("provider_usage "))
    .map((l) => JSON.parse(l.slice("provider_usage ".length)));
  assert.equal(usage.length, 2);
  assert.equal(usage[1].reanalysisAttempt, 1);
  assert.equal(usage[0].reanalysisAttempt, 0);
  assert.equal(usage[1].detectedComponent, "Wall Tile");
  assert.equal(usage[1].noteImageAgreement, "neutral");
  assert.equal(usage[1].normalizationStrategy, "alias");
  assert.equal(usage[1].confidence, 0.85);
  assert.equal(usage[1].candidateCount, 0);
  assert.equal(usage[1].needsReviewReason, undefined);
  assert.equal(lines.join("\n").includes("PRIVATE-NOTE-MARKER"), false);
});
