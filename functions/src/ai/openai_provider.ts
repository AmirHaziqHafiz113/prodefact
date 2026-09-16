import {AiProvider, AiProviderError} from "./provider";
import {
  ClassificationResult,
  ClassifyFindingInput,
  FindingImages,
} from "./types";

/**
 * Clean adapter shell for a future OpenAI/ChatGPT integration.
 *
 * Not activated — no credentials exist for it, and none are
 * fabricated here. To enable this provider later:
 *   1. `firebase functions:secrets:set OPENAI_API_KEY`
 *   2. bind it in index.ts the same way DEEPSEEK_API_KEY is bound
 *   3. implement `classifyFinding` below against the Chat
 *      Completions (or Responses) API using
 *      `response_format: {type: "json_object"}` or a JSON schema,
 *      following the same structure as `DeepSeekProvider` (timeout,
 *      bounded retry on transient errors, strict validation before
 *      returning)
 *   4. set `AI_PROVIDER=openai` (see gateway.ts)
 *
 * OpenAI's multimodal models (e.g. a GPT-4o-class model) can also
 * accept image input, which would let this provider (unlike the
 * current text-only DeepSeek adapter) analyze evidence photos
 * directly — see docs/ai_provider_architecture.md.
 */
export class OpenAiProvider implements AiProvider {
  readonly id = "openai";
  // Set to true once a real multimodal implementation is added below —
  // OpenAI's current models accept image input, so this would become
  // true rather than needing a separate capability class.
  readonly supportsImages = false;

  /** @param {string} apiKey the OpenAI API key, once configured. */
  constructor(private readonly apiKey: string) {
    void this.apiKey;
  }

  /** @inheritdoc */
  classifyFinding(
    input: ClassifyFindingInput,
    images: FindingImages
  ): Promise<ClassificationResult> {
    void input;
    void images;
    throw new AiProviderError(
      "The OpenAI provider is not yet implemented/configured."
    );
  }
}
