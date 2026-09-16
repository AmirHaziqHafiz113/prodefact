import {
  AnalyzeInspectionInput,
  AnalyzeInspectionResult,
  FindingImages,
} from "./types";

/**
 * Contract every AI provider adapter implements. The callable
 * function depends only on this interface via the gateway — never on
 * a specific provider's request/response shape. Swapping the active
 * provider is an addition of one more class + one line in the
 * gateway's provider map, never a rework of the callable function or
 * Flutter.
 *
 * `images` is always passed, even to a text-only provider (which
 * simply ignores it, per its own `supportsImages: false`) — this keeps
 * every adapter's signature identical regardless of capability, so a
 * future multimodal provider (OpenAI/Gemini/Anthropic) is a drop-in
 * swap, not a contract change.
 */
export interface AiProvider {
  readonly id: string;
  /** Whether this provider actually looks at `images` at all. */
  readonly supportsImages: boolean;
  analyzeInspection(
    input: AnalyzeInspectionInput,
    images: FindingImages[]
  ): Promise<AnalyzeInspectionResult>;
}

/** Thrown by a provider adapter for any request/response failure. */
export class AiProviderError extends Error {
  /**
   * @param {string} message a human-readable description.
   * @param {unknown} cause the underlying error, if any.
   */
  constructor(message: string, public readonly cause?: unknown) {
    super(message);
    this.name = "AiProviderError";
  }
}
