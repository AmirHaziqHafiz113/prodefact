import assert from "node:assert/strict";
import {test, TestContext} from "node:test";
import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";
import {fakeFirestore} from "./fakes";
import {
  handleAnalyseFinding,
  providerUsageRecord,
} from "./handle_analyse_finding";
import {DEFAULT_PRICING_CONFIG} from "./pricing_config";
import {providerCostForTokensUsd} from "./pricing";
import {AiLevel} from "./types";

/**
 * Per-finding AI usage and raw provider cost (2026-10-04). One photo =
 * one finding = one request, so each `provider_usage` log line (and the
 * same fields on the aiJobs record) is the exact cost of one image —
 * priced by the same config billing uses, never separate prices.
 */

const UID = "uid_1";
const API_KEY = "sk-test-SECRET-KEY";
const NOTE = "PRIVATE inspector note about unit A-12-3";

/**
 * @return {{db: Firestore, store: Map<string, Record<string, unknown>>}} a
 *   fake Firestore with one owned finding and Credits.
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
 * Stubs OpenAI with a fixed answer and optional usage, and captures
 * everything written to the console.
 * @param {TestContext} t the running test.
 * @param {object} [usage] the usage block to return, if any.
 * @return {{lines: string[], bodies: string[]}} captured console lines
 *   and request bodies.
 */
function stub(
  t: TestContext,
  usage?: {prompt_tokens: number; completion_tokens: number}
): {lines: string[]; bodies: string[]} {
  const lines: string[] = [];
  const bodies: string[] = [];
  const originalFetch = global.fetch;
  global.fetch = (async (_url: unknown, init?: RequestInit) => {
    bodies.push(String(init?.body));
    return new Response(JSON.stringify({
      choices: [{message: {content: JSON.stringify({
        catalogueEntryId: "wall.concrete_wall.05",
        confidence: 0.8,
        needsReview: false,
      })}}],
      ...(usage ? {usage} : {}),
    }), {status: 200});
  }) as typeof fetch;
  const originals = {
    info: console.info,
    log: console.log,
    warn: console.warn,
    error: console.error,
  };
  const capture = (...args: unknown[]) => {
    lines.push(args.map((a) =>
      typeof a === "string" ? a : JSON.stringify(a)).join(" "));
  };
  console.info = capture;
  console.log = capture;
  console.warn = capture;
  console.error = capture;
  t.after(() => {
    global.fetch = originalFetch;
    Object.assign(console, originals);
  });
  return {lines, bodies};
}

const analyse = (firestore: Firestore, level: AiLevel, key: string) =>
  handleAnalyseFinding({
    auth: {uid: UID},
    data: {inspectionId: "inspection_1", findingId: "finding_1",
      area: "Kitchen", isPlumbingArea: false, aiLevel: level,
      note: NOTE, idempotencyKey: key},
    firestore,
    storage: {} as unknown as Storage,
    apiKeys: {openai: API_KEY},
  });

/**
 * @param {string[]} lines captured console lines.
 * @return {Record<string, unknown>} the parsed provider_usage payload.
 */
function usageLog(lines: string[]): Record<string, unknown> {
  const line = lines.find((l) => l.startsWith("provider_usage "));
  assert.ok(line, "a provider_usage line is logged");
  return JSON.parse(line.slice("provider_usage ".length));
}

for (const level of ["fast", "smart"] as AiLevel[]) {
  test(`1-5. ${level}: OpenAI usage is captured, totalTokens is the sum, ` +
    `and providerCostUsd uses the ${level} pricing config`, async (t) => {
    const {lines} = stub(t, {prompt_tokens: 7000, completion_tokens: 150});
    const {db, store} = seeded();
    await analyse(db, level, `key_${level}`);

    const config = DEFAULT_PRICING_CONFIG.aiLevels[level];
    const expectedCost = providerCostForTokensUsd(7000, 150, config);
    const log = usageLog(lines);
    assert.equal(log.findingId, "finding_1");
    assert.equal(log.idempotencyKey, `key_${level}`);
    assert.equal(log.aiLevel, level);
    assert.equal(log.model, config.model);
    assert.equal(log.usageAvailable, true);
    assert.equal(log.inputTokens, 7000);
    assert.equal(log.outputTokens, 150);
    assert.equal(log.totalTokens, 7150);
    assert.equal(log.providerCostUsd, expectedCost);
    assert.equal(typeof log.providerDurationMs, "number");

    // The same facts are stored on the authoritative job record.
    const job = store.get(`users/${UID}/aiJobs/key_${level}`)!;
    assert.equal(job.inputTokens, 7000);
    assert.equal(job.outputTokens, 150);
    assert.equal(job.totalTokens, 7150);
    assert.equal(job.providerCostUsd, expectedCost);
    assert.equal(job.model, config.model);
    assert.equal(job.aiLevel, level);
    assert.equal(typeof job.providerDurationMs, "number");
  });
}

test("4 + 5. Fast and Smart are priced differently for the same usage",
  () => {
    const usage = {inputTokens: 7000, outputTokens: 150};
    const fast = providerUsageRecord({usage, providerDurationMs: 1,
      levelConfig: DEFAULT_PRICING_CONFIG.aiLevels.fast});
    const smart = providerUsageRecord({usage, providerDurationMs: 1,
      levelConfig: DEFAULT_PRICING_CONFIG.aiLevels.smart});
    assert.equal(fast.model, DEFAULT_PRICING_CONFIG.aiLevels.fast.model);
    assert.equal(smart.model, DEFAULT_PRICING_CONFIG.aiLevels.smart.model);
    assert.ok(fast.providerCostUsd! < smart.providerCostUsd!);
  });

test("6. missing provider usage logs usageAvailable: false, invents no " +
  "tokens, and the analysis and billing still complete", async (t) => {
  const {lines} = stub(t);
  const {db, store} = seeded();
  const result = await analyse(db, "smart", "key_no_usage");

  assert.equal(result.classification.catalogueEntryId,
    "wall.concrete_wall.05");
  const log = usageLog(lines);
  assert.equal(log.usageAvailable, false);
  for (const field of ["inputTokens", "outputTokens", "totalTokens",
    "providerCostUsd"]) {
    assert.equal(field in log, false, field);
  }
  const job = store.get(`users/${UID}/aiJobs/key_no_usage`)!;
  assert.equal(job.status, "succeeded");
  assert.equal(job.usageAvailable, false);
  assert.equal("inputTokens" in job, false);
});

test("7. no API key, note, prompt or image content is ever logged",
  async (t) => {
    const {lines, bodies} = stub(t,
      {prompt_tokens: 7000, completion_tokens: 150});
    const {db} = seeded();
    await analyse(db, "smart", "key_safe");

    // The request really carried the note, so its absence from the
    // logs is meaningful.
    assert.ok(bodies.some((b) => b.includes("PRIVATE inspector note")));
    const all = lines.join("\n");
    for (const secret of [API_KEY, "PRIVATE inspector note", "base64,",
      "CONTROLLED DEFECT CATALOGUE", "EVIDENCE PRIORITY"]) {
      assert.equal(all.includes(secret), false, `logged: ${secret}`);
    }
  });
