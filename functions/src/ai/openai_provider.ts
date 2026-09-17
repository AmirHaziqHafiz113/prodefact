import {AiProvider, AiProviderError} from "./provider";
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
const MAX_RETRIES = 1;

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
    private readonly model: string
  ) {}

  /** @inheritdoc */
  async classifyFinding(
    input: ClassifyFindingInput,
    images: FindingImages
  ): Promise<ProviderClassification> {
    const requestBody = {
      model: this.model,
      temperature: 0.2,
      response_format: {type: "json_object"},
      messages: [
        {role: "system", content: buildSystemPrompt()},
        {role: "user", content: buildFindingContent(input, images)},
      ],
    };

    let lastError: unknown;
    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      try {
        return await this.callOnce(requestBody, input.findingId);
      } catch (error) {
        lastError = error;
        const transient = error instanceof AiProviderError &&
          error.message.includes("transient");
        if (!transient) {
          throw error;
        }
      }
    }
    throw lastError instanceof Error ?
      lastError :
      new AiProviderError("OpenAI request failed.");
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
      throw new AiProviderError("OpenAI request failed (transient).", error);
    }

    if (!response.ok) {
      const transient = response.status >= 500 || response.status === 429;
      const suffix = transient ? " (transient)." : ".";
      throw new AiProviderError(
        `OpenAI request failed with status ${response.status}${suffix}`
      );
    }

    const data = (await response.json()) as OpenAiChatResponse;
    const rawContent = data.choices?.[0]?.message?.content;
    if (!rawContent) {
      throw new AiProviderError("OpenAI returned an empty response.");
    }

    let parsedContent: unknown;
    try {
      parsedContent = JSON.parse(rawContent);
    } catch (error) {
      throw new AiProviderError("OpenAI returned invalid JSON.", error);
    }

    const result: ClassificationResult = parseClassificationPayload(
      parsedContent,
      findingId
    );
    const usage: ProviderUsage | undefined =
      typeof data.usage?.prompt_tokens === "number" &&
      typeof data.usage?.completion_tokens === "number" ?
        {
          inputTokens: data.usage.prompt_tokens,
          outputTokens: data.usage.completion_tokens,
        } :
        undefined;
    return {result, usage};
  }
}
