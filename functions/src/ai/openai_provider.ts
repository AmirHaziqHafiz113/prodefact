import {
  AiProvider,
  AiProviderError,
  AiProviderFailureKind,
} from "./provider";
import {fetchWithTimeout} from "./http_util";
import {
  buildFindingContent,
  buildSystemPrompt,
  parseClassificationPayload,
} from "./prompt";
import {
  ClassificationResult,
  ClassifyFindingInput,
  FindingImages,
  ProviderClassification,
  ProviderUsage,
} from "./types";

const OPENAI_ENDPOINT = "https://api.openai.com/v1/chat/completions";
const REQUEST_TIMEOUT_MS = 45_000;
/** Waits before each retry of a rate-limited/unavailable call. Bounded:
 * two retries fit well inside `analyseFinding`'s 180s budget even with
 * the 45s per-request timeout. */
const DEFAULT_RETRY_DELAYS_MS = [1_500, 4_000];

interface OpenAiErrorBody {
  error?: {code?: unknown; type?: unknown};
}

interface OpenAiChatResponse {
  choices?: Array<{ message?: { content?: string } }>;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
  };
}

/**
 * Real OpenAI Chat Completions adapter — the intended primary AI
 * provider for the commercial pricing model (see
 * docs/commercial_model.md, "Provider mapping"). The exact model id
 * used per request is passed in by the caller (see `gateway.ts`'s
 * `createProvider`), driven entirely by the AI-level -> model mapping
 * in `billing/pricing_config.ts` — this class never hardcodes which
 * model backs which customer-facing tier, so that mapping can change
 * without touching this file. Shares its system prompt/finding-content
 * builders with `DeepSeekProvider` — see `ai/prompt.ts` — so
 * classification behavior never quietly differs by provider.
 *
 * Model ids and per-model pricing in `pricing_config.ts` were verified
 * against OpenAI's live API documentation
 * (developers.openai.com/api/docs/models,
 * developers.openai.com/api/docs/pricing) at the time this adapter was
 * written — re-verify before relying on them for real billing, since
 * OpenAI's lineup changes; see docs/commercial_model.md.
 */
export class OpenAiProvider implements AiProvider {
  readonly id = "openai";
  readonly supportsImages = true;

  /**
   * @param {string} apiKey the OpenAI API key, from Secret Manager.
   * @param {string} model the exact model id to request (see
   *   `billing/pricing_config.ts` — server-configured, never
   *   hardcoded here).
   */
  constructor(
    private readonly apiKey: string,
    private readonly model: string,
    private readonly retryDelaysMs: number[] = DEFAULT_RETRY_DELAYS_MS,
    private readonly sleep: (ms: number) => Promise<void> = (ms) =>
      new Promise((resolve) => setTimeout(resolve, ms))
  ) {}

  /** @inheritdoc */
  async classifyFinding(
    input: ClassifyFindingInput,
    images: FindingImages
  ): Promise<ProviderClassification> {
    const requestBody = {
      model: this.model,
      // No `temperature` — the GPT-5.6 family are reasoning models that
      // reject any non-default sampling temperature outright (a 400
      // "Unsupported value" error, not a transient one), verified
      // against OpenAI's current API docs/community reports for this
      // pass. Never re-add a fixed temperature here without first
      // confirming the configured model actually supports it.
      response_format: {type: "json_object"},
      messages: [
        {role: "system", content: buildSystemPrompt()},
        {role: "user", content: buildFindingContent(input, images)},
      ],
    };

    // Retry only what a short wait can fix (rate limiting, 5xx, network,
    // timeout). An exhausted quota, a rejected request, or bad auth fails
    // at once: retrying those only delays the inspector's answer.
    for (let attempt = 0; ; attempt++) {
      try {
        return await this.callOnce(requestBody, input.findingId);
      } catch (error) {
        const retryable = error instanceof AiProviderError && error.retryable;
        if (!retryable || attempt >= this.retryDelaysMs.length) throw error;
        console.warn("ai_provider_retry", {
          provider: this.id,
          model: this.model,
          findingId: input.findingId,
          attempt: attempt + 1,
          ...(error as AiProviderError).detail,
        });
        await this.sleep(this.retryDelaysMs[attempt]);
      }
    }
  }

  /**
   * Performs one OpenAI chat-completion call and validates the
   * response shape.
   * @param {Record<string, unknown>} requestBody the request body.
   * @param {string} findingId the finding this request is for.
   * @return {Promise<ProviderClassification>} the validated result.
   */
  private async callOnce(
    requestBody: Record<string, unknown>,
    findingId: string
  ): Promise<ProviderClassification> {
    let response: Response;
    try {
      response = await fetchWithTimeout(
        OPENAI_ENDPOINT,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${this.apiKey}`,
          },
          body: JSON.stringify(requestBody),
        },
        REQUEST_TIMEOUT_MS
      );
    } catch (error) {
      throw new AiProviderError(
        "OpenAI request failed (transient).",
        error,
        {kind: "unavailable"}
      );
    }

    if (!response.ok) {
      throw await this.failureFor(response, findingId);
    }

    const data = (await response.json()) as OpenAiChatResponse;
    const usage = usageOf(data);
    const rawContent = data.choices?.[0]?.message?.content;

    // The model answered but not in the agreed shape: that is a finding
    // for the inspector to classify (needsReview), not an AI failure.
    let result: ClassificationResult;
    try {
      if (!rawContent) throw new Error("empty content");
      result = parseClassificationPayload(JSON.parse(rawContent), findingId);
    } catch {
      console.warn("ai_provider_unreadable_output", {
        provider: this.id,
        model: this.model,
        findingId,
        hasContent: Boolean(rawContent),
      });
      result = {
        findingId,
        needsReview: true,
        candidateEntryIds: [],
        shortReason: "AI could not produce a clear classification.",
      };
    }
    return {result, usage};
  }

  /**
   * Classifies a non-2xx response from its status and OpenAI's own
   * error code, and logs the safe facts (never the body or the key).
   * @param {Response} response the failed response.
   * @param {string} findingId the finding this request is for.
   * @return {Promise<AiProviderError>} the error to throw.
   */
  private async failureFor(
    response: Response,
    findingId: string
  ): Promise<AiProviderError> {
    let providerCode: string | undefined;
    try {
      const body = (await response.json()) as OpenAiErrorBody;
      const code = body.error?.code ?? body.error?.type;
      if (typeof code === "string") providerCode = code.slice(0, 64);
    } catch {
      // A non-JSON error body: the status alone classifies it.
    }
    const status = response.status;
    const kind: AiProviderFailureKind =
      status === 429 && providerCode === "insufficient_quota" ?
        "quotaExceeded" :
        status === 429 ?
          "rateLimited" :
          status >= 500 ?
            "unavailable" :
            "rejected";
    console.error("ai_provider_http_error", {
      provider: this.id,
      model: this.model,
      findingId,
      status,
      providerCode: providerCode ?? null,
      kind,
    });
    const suffix = kind === "rateLimited" || kind === "unavailable" ?
      " (transient)." :
      ".";
    return new AiProviderError(
      `OpenAI request failed with status ${status}` +
        (providerCode ? ` [${providerCode}]` : "") +
        suffix,
      undefined,
      {kind, status, providerCode}
    );
  }
}

/**
 * @param {OpenAiChatResponse} data a chat completion response.
 * @return {ProviderUsage | undefined} its token usage, if reported.
 */
function usageOf(data: OpenAiChatResponse): ProviderUsage | undefined {
  return typeof data.usage?.prompt_tokens === "number" &&
    typeof data.usage?.completion_tokens === "number" ?
    {
      inputTokens: data.usage.prompt_tokens,
      outputTokens: data.usage.completion_tokens,
    } :
    undefined;
}
