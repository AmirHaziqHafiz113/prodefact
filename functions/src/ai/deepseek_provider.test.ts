import assert from "node:assert/strict";
import {test, TestContext} from "node:test";
import {DeepSeekProvider} from "./deepseek_provider";
import {AiProviderError} from "./provider";
import {AnalyzeInspectionInput} from "./types";

/** @return {AnalyzeInspectionInput} a minimal one-finding request. */
function sampleInput(): AnalyzeInspectionInput {
  return {
    inspectionId: "inspection_1",
    propertyType: "highRise",
    findings: [
      {
        findingId: "finding_1",
        area: "Kitchen",
        isPlumbingArea: false,
        element: "Wall",
        evidenceCount: 0,
      },
    ],
  };
}

type FetchImpl =
  (...args: Parameters<typeof fetch>) => ReturnType<typeof fetch>;

/**
 * Installs a fake `global.fetch` for the duration of one test, restoring
 * the original afterwards via `t.after` — so a failure partway through a
 * test never leaks a stub into a later, unrelated one.
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
 * @param {unknown} content the model's (already-stringified) JSON body.
 * @return {Response} a fake successful DeepSeek chat-completion response.
 */
function okResponse(content: string): Response {
  return new Response(
    JSON.stringify({choices: [{message: {content}}]}),
    {status: 200}
  );
}

test("a successful response is parsed into suggestions", async (t) => {
  stubFetch(t, async () =>
    okResponse(JSON.stringify({
      suggestions: [{findingId: "finding_1", defectType: "Peeling paint"}],
    })));
  const provider = new DeepSeekProvider("fake-key");
  const result = await provider.analyzeInspection(sampleInput(), []);
  assert.equal(result.suggestions.length, 1);
  assert.equal(result.suggestions[0].defectType, "Peeling paint");
});

test("a 400 response fails immediately, without retrying", async (t) => {
  let calls = 0;
  stubFetch(t, async () => {
    calls++;
    return new Response("bad request", {status: 400});
  });
  const provider = new DeepSeekProvider("fake-key");
  await assert.rejects(
    () => provider.analyzeInspection(sampleInput(), []),
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
  const provider = new DeepSeekProvider("fake-key");
  await assert.rejects(
    () => provider.analyzeInspection(sampleInput(), []),
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
      suggestions: [{findingId: "finding_1", defectType: "Cracked tile"}],
    }));
  });
  const provider = new DeepSeekProvider("fake-key");
  const result = await provider.analyzeInspection(sampleInput(), []);
  assert.equal(calls, 2);
  assert.equal(result.suggestions[0].defectType, "Cracked tile");
});

test("a network/abort failure is treated as transient and retried", async (
  t
) => {
  let calls = 0;
  stubFetch(t, async () => {
    calls++;
    if (calls === 1) throw new Error("network down");
    return okResponse(JSON.stringify({
      suggestions: [{findingId: "finding_1", defectType: "Loose fixture"}],
    }));
  });
  const provider = new DeepSeekProvider("fake-key");
  const result = await provider.analyzeInspection(sampleInput(), []);
  assert.equal(calls, 2);
  assert.equal(result.suggestions[0].defectType, "Loose fixture");
});

test("malformed (non-JSON) model output fails clearly instead of " +
  "throwing an unrelated parse error", async (t) => {
  stubFetch(t, async () => okResponse("not valid json {{{"));
  const provider = new DeepSeekProvider("fake-key");
  await assert.rejects(
    () => provider.analyzeInspection(sampleInput(), []),
    AiProviderError
  );
});

test("an empty model response body fails clearly", async (t) => {
  stubFetch(t, async () =>
    new Response(JSON.stringify({choices: []}), {status: 200}));
  const provider = new DeepSeekProvider("fake-key");
  await assert.rejects(
    () => provider.analyzeInspection(sampleInput(), []),
    AiProviderError
  );
});
