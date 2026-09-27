import {
  ClassifyFindingInput,
  FindingImages,
  ProviderClassification,
} from "./types";

/**
 * Contract every AI provider adapter implements. The callable function
 * depends only on this interface via the gateway — never on a specific
 * provider's request/response shape. Swapping the active provider is
 * an addition of one more class + one line in the gateway's provider
 * map, never a rework of the callable function or Flutter.
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
  classifyFinding(
    input: ClassifyFindingInput,
    images: FindingImages
  ): Promise<ProviderClassification>;
}

/**
 * Why a provider call failed, as far as the backend can tell:
 * - `rateLimited`: 429 rate limiting; worth retrying shortly.
 * - `quotaExceeded`: 429 `insufficient_quota`; the provider account is
 *   out of credit, so retrying cannot help until billing is fixed.
 * - `unavailable`: 5xx, network failure, or timeout.
 * - `rejected`: any other non-2xx (bad request, auth, unknown model).
 */
export type AiProviderFailureKind =
  | "rateLimited"
  | "quotaExceeded"
  | "unavailable"
  | "rejected";

/** Safe, loggable facts about a provider failure: never keys or bodies. */
export interface AiProviderFailureDetail {
  kind?: AiProviderFailureKind;
  /** The HTTP status, when a response arrived. */
  status?: number;
  /** The provider's own error code/type (e.g. `insufficient_quota`). */
  providerCode?: string;
}

/** Thrown by a provider adapter for any request/response failure. */
export class AiProviderError extends Error {
  /**
   * @param {string} message a human-readable description.
   * @param {unknown} cause the underlying error, if any.
   * @param {AiProviderFailureDetail} detail safe, loggable facts.
   */
  constructor(
    message: string,
    public readonly cause?: unknown,
    public readonly detail: AiProviderFailureDetail = {}
  ) {
    super(message);
    this.name = "AiProviderError";
  }

  /** @return {boolean} whether a retry shortly after could succeed. */
  get retryable(): boolean {
    return this.detail.kind === "rateLimited" ||
      this.detail.kind === "unavailable" ||
      (this.detail.kind === undefined && this.message.includes("transient"));
  }
}
