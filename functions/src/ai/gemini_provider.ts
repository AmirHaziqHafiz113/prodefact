import {AiProvider, AiProviderError} from "./provider";
import {
  ClassificationResult,
  ClassifyFindingInput,
  FindingImages,
} from "./types";

/**
 * Clean adapter shell for a future Google Gemini integration.
 *
 * Not activated — no credentials exist for it, and none are
 * fabricated here. To enable this provider later:
 *   1. `firebase functions:secrets:set GEMINI_API_KEY`
 *   2. bind it in index.ts the same way DEEPSEEK_API_KEY is bound
 *   3. implement `classifyFinding` below against the Gemini API
 *      using a JSON-mode/`responseSchema` request, following the
 *      same structure as `DeepSeekProvider`
 *   4. set `AI_PROVIDER=gemini` (see gateway.ts)
 *
 * Gemini's multimodal models accept image input directly, which
 * would let this provider analyze evidence photos — see
 * docs/ai_provider_architecture.md.
 */
export class GeminiProvider implements AiProvider {
  readonly id = "gemini";
  // Set to true once a real multimodal implementation is added below —
  // Gemini's current models accept image input, so this would become
  // true rather than needing a separate capability class.
  readonly supportsImages = false;

  /** @param {string} apiKey the Gemini API key, once configured. */
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
      "The Gemini provider is not yet implemented/configured."
    );
  }
}
