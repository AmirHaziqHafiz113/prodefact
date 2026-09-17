import assert from "node:assert/strict";
import {test, TestContext} from "node:test";
import {OpenAiProvider} from "./openai_provider";
import {AiProviderError} from "./provider";
import {ClassifyFindingInput, FindingImages} from "./types";

/** @return {ClassifyFindingInput} a minimal one-finding request. */
function sampleInput(): ClassifyFindingInput {
  return {
    inspectionId: "inspection_1",
    findingId: "finding_1",
    area: "Kitchen",
    isPlumbingArea: false,
  };
}

/** @return {FindingImages} no resolved images. */
function noImages(): FindingImages {
  return {findingId: "finding_1", images: [], unavailableCount: 0};
}

type FetchImpl =
  (...args: Parameters<typeof fetch>) => ReturnType<typeof fetch>;

/**
 * @param {TestContext} t the running test's context.
 * @param {FetchImpl} impl the fake fetch implementation.
 */
function stubFetch(t: TestContext, impl: FetchImpl): void {
  const original = global.fetch;
  global.fetch = impl as typeof fetch;
  t.after(() => {
    global.fetch = original;
  });
}

/**
 * @param {string} content the model's (already-stringified) JSON body.
 * @param {object} [usage] the model's reported token usage.
 * @return {Response} a fake successful OpenAI chat-completion response.
 */
function okResponse(
  content: string,
  usage?: {prompt_tokens: number; completion_tokens: number}
): Response {
  return new Response(
    JSON.stringify({choices: [{message: {content}}], usage}),
    {status: 200}
  );
}

test("a successful response is parsed into a classification, using the " +
  "configured model id", async (t) => {
  let requestedModel: unknown;
  stubFetch(t, async (_url, init) => {
    requestedModel = JSON.parse(String(init?.body)).model;
    return okResponse(JSON.stringify({
      catalogueEntryId: "wall.concrete_wall.05",
      confidence: 0.7,
      needsReview: false,
    }));
  });
  const provider = new OpenAiProvider("fake-key", "gpt-5.6-terra");
  const {result} = await provider.classifyFinding(sampleInput(), noImages());
  assert.equal(result.catalogueEntryId, "wall.concrete_wall.05");
  assert.equal(requestedModel, "gpt-5.6-terra");
});

test("never sends a `temperature` field — the GPT-5.6 family are " +
  "reasoning models that reject any non-default value with a hard " +
  "400 error (verified against current OpenAI docs/community reports)",
async (t) => {
  let requestBody: Record<string, unknown> = {};
  stubFetch(t, async (_url, init) => {
    requestBody = JSON.parse(String(init?.body));
    return okResponse(JSON.stringify({
      catalogueEntryId: "wall.concrete_wall.05",
      needsReview: false,
    }));
  });
  const provider = new OpenAiProvider("fake-key", "gpt-5.6-terra");
  await provider.classifyFinding(sampleInput(), noImages());
  assert.ok(!("temperature" in requestBody));
});

test("the provider's reported token usage is captured for billing",
  async (t) => {
    stubFetch(t, async () =>
      okResponse(
        JSON.stringify({
          catalogueEntryId: "wall.concrete_wall.05",
          needsReview: false,
        }),
        {prompt_tokens: 2000, completion_tokens: 120}
      ));
    const provider = new OpenAiProvider("fake-key", "gpt-5.6-luna");
    const {usage} = await provider.classifyFinding(
      sampleInput(),
      noImages()
    );
    assert.deepEqual(usage, {inputTokens: 2000, outputTokens: 120});
  });

test("a 400 response fails immediately, without retrying", async (t) => {
  let calls = 0;
  stubFetch(t, async () => {
    calls++;
    return new Response("bad request", {status: 400});
  });
  const provider = new OpenAiProvider("fake-key", "gpt-5.6-terra");
  await assert.rejects(
    () => provider.classifyFinding(sampleInput(), noImages()),
    AiProviderError
  );
  assert.equal(calls, 1);
});

test("a 500 response is retried once, then still fails if it keeps " +
  "failing", async (t) => {
  let calls = 0;
  stubFetch(t, async () => {
    calls++;
    return new Response("server error", {status: 500});
  });
  const provider = new OpenAiProvider("fake-key", "gpt-5.6-terra");
  await assert.rejects(
    () => provider.classifyFinding(sampleInput(), noImages()),
    AiProviderError
  );
  assert.equal(calls, 2);
});

test("a 429 (rate limit) response is retried once and can succeed on " +
  "the retry", async (t) => {
  let calls = 0;
  stubFetch(t, async () => {
    calls++;
    if (calls === 1) return new Response("rate limited", {status: 429});
    return okResponse(JSON.stringify({
      catalogueEntryId: "floor.floor_tiles.03",
      needsReview: false,
    }));
  });
  const provider = new OpenAiProvider("fake-key", "gpt-5.6-terra");
  const {result} = await provider.classifyFinding(sampleInput(), noImages());
  assert.equal(calls, 2);
  assert.equal(result.catalogueEntryId, "floor.floor_tiles.03");
});

test("a network/abort failure is treated as transient and retried", async (
  t
) => {
  let calls = 0;
  stubFetch(t, async () => {
    calls++;
    if (calls === 1) throw new Error("network down");
    return okResponse(JSON.stringify({
      catalogueEntryId: "door.door_hinge.03",
      needsReview: false,
    }));
  });
  const provider = new OpenAiProvider("fake-key", "gpt-5.6-terra");
  const {result} = await provider.classifyFinding(sampleInput(), noImages());
  assert.equal(calls, 2);
  assert.equal(result.catalogueEntryId, "door.door_hinge.03");
});

test("malformed (non-JSON) model output fails clearly instead of " +
  "throwing an unrelated parse error", async (t) => {
  stubFetch(t, async () => okResponse("not valid json {{{"));
  const provider = new OpenAiProvider("fake-key", "gpt-5.6-terra");
  await assert.rejects(
    () => provider.classifyFinding(sampleInput(), noImages()),
    AiProviderError
  );
});

test("an empty model response body fails clearly", async (t) => {
  stubFetch(t, async () =>
    new Response(JSON.stringify({choices: []}), {status: 200}));
  const provider = new OpenAiProvider("fake-key", "gpt-5.6-terra");
  await assert.rejects(
    () => provider.classifyFinding(sampleInput(), noImages()),
    AiProviderError
  );
});

test("a needsReview response with no catalogueEntryId is parsed " +
  "correctly", async (t) => {
  stubFetch(t, async () =>
    okResponse(JSON.stringify({
      needsReview: true,
      candidateEntryIds: ["door.door_hinge.01", "door.door_hinge.02"],
    })));
  const provider = new OpenAiProvider("fake-key", "gpt-5.6-terra");
  const {result} = await provider.classifyFinding(sampleInput(), noImages());
  assert.equal(result.catalogueEntryId, undefined);
  assert.equal(result.needsReview, true);
  assert.deepEqual(result.candidateEntryIds, [
    "door.door_hinge.01",
    "door.door_hinge.02",
  ]);
});

test("sends the shared system prompt (same controlled catalogue " +
  "contract as every other provider)", async (t) => {
  let systemPrompt: unknown;
  stubFetch(t, async (_url, init) => {
    const body = JSON.parse(String(init?.body));
    systemPrompt = body.messages[0].content;
    return okResponse(JSON.stringify({needsReview: true}));
  });
  const provider = new OpenAiProvider("fake-key", "gpt-5.6-terra");
  await provider.classifyFinding(sampleInput(), noImages());
  assert.ok(String(systemPrompt).includes("CONTROLLED DEFECT CATALOGUE"));
  assert.ok(
    String(systemPrompt).includes("NEVER allowed to invent a main element")
  );
});
