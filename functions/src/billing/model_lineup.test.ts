import assert from "node:assert/strict";
import {test, TestContext} from "node:test";
import type {Firestore} from "firebase-admin/firestore";
import type {Storage} from "firebase-admin/storage";
import {fakeFirestore} from "./fakes";
import {DEFAULT_PRICING_CONFIG} from "./pricing_config";
import {estimateMaxCredits} from "./pricing";
import {
  handleEstimateFindingAnalysis,
} from "./handle_estimate_finding_analysis";
import {handleAnalyseFinding} from "./handle_analyse_finding";
import {createProvider} from "../ai/gateway";
import {AiLevel} from "./types";

/**
 * The OpenAI model lineup (2026-10-01): Fast gpt-6-luna, Smart
 * gpt-5.6-terra, Expert gpt-6.1-sol, at OpenAI's published prices, with
 * the customer markup and Credit conversion unchanged.
 */

const UID = "uid_1";

type Price = {model: string; inPerM: number; outPerM: number};

const LINEUP: Record<AiLevel, Price> =
  {
    fast: {model: "gpt-6-luna", inPerM: 0.1, outPerM: 0.5},
    smart: {model: "gpt-5.6-terra", inPerM: 2, outPerM: 12},
    expert: {model: "gpt-6.1-sol", inPerM: 2, outPerM: 10},
  };

/**
 * @param {number} a a value.
 * @param {number} b another value.
 * @return {boolean} whether they are equal within floating error.
 */
function near(a: number, b: number): boolean {
  return Math.abs(a - b) < 1e-12;
}

test("1-3. each level resolves to its exact OpenAI model id", () => {
  for (const level of ["fast", "smart", "expert"] as AiLevel[]) {
    const config = DEFAULT_PRICING_CONFIG.aiLevels[level];
    assert.equal(config.provider, "openai", level);
    assert.equal(config.model, LINEUP[level].model, level);
  }
});

test("4-6. provider prices match OpenAI's per-1M-token rates", () => {
  for (const level of ["fast", "smart", "expert"] as AiLevel[]) {
    const config = DEFAULT_PRICING_CONFIG.aiLevels[level];
    // Stored per 1,000 tokens, so per-1M price / 1000.
    assert.ok(
      near(config.providerCostPerKInputTokensUsd, LINEUP[level].inPerM / 1000),
      `${level} input`
    );
    assert.ok(
      near(
        config.providerCostPerKOutputTokensUsd,
        LINEUP[level].outPerM / 1000
      ),
      `${level} output`
    );
  }
});

test("9 + 10. markup and Credit conversion are unchanged", () => {
  assert.equal(DEFAULT_PRICING_CONFIG.markupMultiplier, 2.0);
  assert.equal(DEFAULT_PRICING_CONFIG.creditsPerMyr, 100);
});

test("8. Credit estimates follow the new prices through the unchanged " +
  "formula (provider cost × 2 × 100, rounded up)", () => {
  for (const level of ["fast", "smart", "expert"] as AiLevel[]) {
    const c = DEFAULT_PRICING_CONFIG.aiLevels[level];
    const costUsd =
      (c.estimatedInputTokens / 1e6) * LINEUP[level].inPerM +
      (c.estimatedOutputTokens / 1e6) * LINEUP[level].outPerM;
    const expected = Math.ceil(costUsd * 2 * 100 - 1e-9);
    assert.equal(estimateMaxCredits(level, DEFAULT_PRICING_CONFIG), expected,
      level);
  }
  // The concrete figures an inspector sees with the default config.
  assert.equal(estimateMaxCredits("fast", DEFAULT_PRICING_CONFIG), 1);
  assert.equal(estimateMaxCredits("smart", DEFAULT_PRICING_CONFIG), 2);
  assert.equal(estimateMaxCredits("expert", DEFAULT_PRICING_CONFIG), 2);
});

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
 * Captures the model each OpenAI request asks for.
 * @param {TestContext} t the running test.
 * @return {string[]} the requested models, in order.
 */
function captureModels(t: TestContext): string[] {
  const models: string[] = [];
  const original = global.fetch;
  global.fetch = (async (_url: unknown, init?: RequestInit) => {
    models.push(JSON.parse(String(init?.body)).model);
    return new Response(JSON.stringify({
      choices: [{
        message: {
          content: JSON.stringify({
            catalogueEntryId: "wall.concrete_wall.05",
            confidence: 0.8,
            needsReview: false,
          }),
        },
      }],
      usage: {prompt_tokens: 100, completion_tokens: 20},
    }), {status: 200});
  }) as typeof fetch;
  t.after(() => {
    global.fetch = original;
  });
  return models;
}

test("7. estimateFindingAnalysis and analyseFinding resolve the same " +
  "model and price for every level", async (t) => {
  const models = captureModels(t);
  for (const level of ["fast", "smart", "expert"] as AiLevel[]) {
    const firestore = seeded();
    const estimate = await handleEstimateFindingAnalysis({
      auth: {uid: UID},
      data: {inspectionId: "inspection_1", findingId: "finding_1",
        aiLevel: level},
      firestore,
    });
    assert.equal(
      estimate.maximumCredits,
      estimateMaxCredits(level, DEFAULT_PRICING_CONFIG),
      level
    );

    const result = await handleAnalyseFinding({
      auth: {uid: UID},
      data: {inspectionId: "inspection_1", findingId: "finding_1",
        area: "Kitchen", isPlumbingArea: false, aiLevel: level,
        idempotencyKey: `key_${level}`},
      firestore,
      storage: {} as unknown as Storage,
      apiKeys: {openai: "test-key"},
    });
    assert.equal(result.aiLevel, level);
    assert.ok(result.creditsCharged <= estimate.maximumCredits, level);
  }
  assert.deepEqual(models, ["gpt-6-luna", "gpt-5.6-terra", "gpt-6.1-sol"]);
});

test("11 + 12. the adapter sends the selected model with an image, as " +
  "JSON-mode Chat Completions, with no temperature or reasoning field",
async (t) => {
  for (const level of ["fast", "smart", "expert"] as AiLevel[]) {
    let body: Record<string, unknown> = {};
    const original = global.fetch;
    global.fetch = (async (url: unknown, init?: RequestInit) => {
      assert.equal(url, "https://api.openai.com/v1/chat/completions");
      body = JSON.parse(String(init?.body));
      return new Response(JSON.stringify({
        choices: [{message: {content: JSON.stringify({needsReview: true})}}],
      }), {status: 200});
    }) as typeof fetch;
    t.after(() => {
      global.fetch = original;
    });

    const config = DEFAULT_PRICING_CONFIG.aiLevels[level];
    const provider = createProvider("openai", "test-key", config.model);
    assert.equal(provider.supportsImages, true);
    await provider.classifyFinding(
      {inspectionId: "i1", findingId: "f1", area: "Kitchen",
        isPlumbingArea: false, note: "tile holo"},
      {findingId: "f1", unavailableCount: 0, images: [
        {evidenceId: "e1", mimeType: "image/jpeg", base64: "AAAA"},
      ]}
    );
    global.fetch = original;

    assert.equal(body.model, LINEUP[level].model);
    assert.deepEqual(body.response_format, {type: "json_object"});
    assert.equal("temperature" in body, false);
    assert.equal("reasoning_effort" in body, false);
    assert.equal("reasoning" in body, false);
    const messages = body.messages as Array<{content: unknown}>;
    const userContent = messages[1].content as Array<Record<string, unknown>>;
    const image = userContent.find((b) => b.type === "image_url") as {
      image_url: {url: string};
    };
    assert.ok(image.image_url.url.startsWith("data:image/jpeg;base64,"));
  }
});
