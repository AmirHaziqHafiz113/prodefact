import {AiProvider, AiProviderError} from "./provider";
import {AnalyzeInspectionInput, AnalyzeInspectionResult} from "./types";

/**
 * Clean adapter shell for a future Anthropic (Claude) integration.
 *
 * Not activated — no credentials exist for it, and none are
 * fabricated here. To enable this provider later:
 *   1. `firebase functions:secrets:set ANTHROPIC_API_KEY`
 *   2. bind it in index.ts the same way DEEPSEEK_API_KEY is bound
 *   3. implement `analyzeInspection` below against the Messages API,
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

  /** @param {string} apiKey the Anthropic API key, once configured. */
  constructor(private readonly apiKey: string) {
    void this.apiKey;
  }

  /** @inheritdoc */
  analyzeInspection(
    input: AnalyzeInspectionInput
  ): Promise<AnalyzeInspectionResult> {
    void input;
    throw new AiProviderError(
      "The Anthropic provider is not yet implemented/configured."
    );
  }
}
