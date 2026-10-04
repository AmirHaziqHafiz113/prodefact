import {AiProvider, AiProviderError} from "./provider";
import {fetchWithTimeout} from "./http_util";
import {
  buildFindingContent,
  buildSystemPrompt,
  promptCatalogueFor,
  parseClassificationPayload,
} from "./prompt";
import {
  ClassificationResult,
  ClassifyFindingInput,
  FindingImages,
  ProviderClassification,
  ProviderUsage,
} from "./types";

const DEEPSEEK_ENDPOINT = "https://api.deepseek.com/chat/completions";

// deepseek-flash is DeepSeek's current multimodal (text + image) chat
// model — see docs/ai_provider_architecture.md ("Active provider:
// DeepSeek") for the API reference this was verified against.
const DEEPSEEK_MODEL = "deepseek-flash";

const REQUEST_TIMEOUT_MS = 45_000;
const MAX_RETRIES = 1;

interface DeepSeekChatResponse {
  choices?: Array<{ message?: { content?: string } }>;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
  };
}

/**
 * Real, production DeepSeek adapter — the only file that knows the
 * DeepSeek request/response shape. Multimodal: sends the finding's
 * structured context plus any resolved evidence photos (already
 * downloaded/validated/normalized by `ai/evidence.ts` before this
 * class ever sees them), and classifies against the controlled defect
 * catalogue rather than freely inventing a defect/recommendation. The
 * system prompt/finding content builders are shared with every other
 * multimodal provider — see `ai/prompt.ts`.
 */
export class DeepSeekProvider implements AiProvider {
  readonly id = "deepseek";
  readonly supportsImages = true;

  /**
   * @param {string} apiKey the DeepSeek API key, from Secret Manager.
   */
  constructor(private readonly apiKey: string) {}

  /** @inheritdoc */
  async classifyFinding(
    input: ClassifyFindingInput,
    images: FindingImages
  ): Promise<ProviderClassification> {
    const requestBody = {
      model: DEEPSEEK_MODEL,
      temperature: 0.2,
      response_format: {type: "json_object"},
      messages: [
        {
          role: "system",
          content: buildSystemPrompt(promptCatalogueFor(input)),
        },
        {role: "user", content: buildFindingContent(input, images)},
      ],
    };

    let lastError: unknown;
    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      try {
        return await this.callOnce(requestBody, input.findingId);
      } catch (error) {
        lastError = error;
        // Only retry a transient failure (timeout/network/5xx) —
        // never a validation failure, which would just fail
        // identically again.
        const transient = error instanceof AiProviderError &&
          error.message.includes("transient");
        if (!transient) {
          throw error;
        }
      }
    }
    throw lastError instanceof Error ?
      lastError :
      new AiProviderError("DeepSeek request failed.");
  }

  /**
   * Performs one DeepSeek chat-completion call and validates the
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
        DEEPSEEK_ENDPOINT,
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
      // Network error or our own abort/timeout — both transient.
      throw new AiProviderError(
        "DeepSeek request failed (transient).",
        error
      );
    }

    if (!response.ok) {
      const transient = response.status >= 500 || response.status === 429;
      const suffix = transient ? " (transient)." : ".";
      throw new AiProviderError(
        `DeepSeek request failed with status ${response.status}${suffix}`
      );
    }

    const data = (await response.json()) as DeepSeekChatResponse;
    const rawContent = data.choices?.[0]?.message?.content;
    if (!rawContent) {
      throw new AiProviderError("DeepSeek returned an empty response.");
    }

    let parsedContent: unknown;
    try {
      parsedContent = JSON.parse(rawContent);
    } catch (error) {
      throw new AiProviderError("DeepSeek returned invalid JSON.", error);
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
