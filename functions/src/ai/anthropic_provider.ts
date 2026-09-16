import {AiProvider, AiProviderError} from "./provider";
import {
  ClassificationResult,
  ClassifyFindingInput,
  FindingImages,
} from "./types";

/**
 * Clean adapter shell for a future Anthropic (Claude) integration.
 *
 * Not activated — no credentials exist for it, and none are
 * fabricated here. To enable this provider later:
 *   1. `firebase functions:secrets:set ANTHROPIC_API_KEY`
 *   2. bind it in index.ts the same way DEEPSEEK_API_KEY is bound
 *   3. implement `classifyFinding` below against the Messages API,
 *      requesting structured JSON output (e.g. via tool use or a
 *      strict prompt contract), following the same structure as
 *      `DeepSeekProvider`
 *   4. set `AI_PROVIDER=anthropic` (see gateway.ts)
 *
 * Current Claude models also accept image input, which would let
 * this provider analyze evidence photos — see
 * docs/ai_provider_architecture.md.
 */
export class AnthropicProvider implements AiProvider {
  readonly id = "anthropic";
  // Set to true once a real multimodal implementation is added below —
  // Anthropic's current models accept image input, so this would become
  // true rather than needing a separate capability class.
  readonly supportsImages = false;

  /** @param {string} apiKey the Anthropic API key, once configured. */
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
      "The Anthropic provider is not yet implemented/configured."
    );
  }
}
