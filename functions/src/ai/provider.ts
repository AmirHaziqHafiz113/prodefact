import {AnalyzeInspectionInput, AnalyzeInspectionResult} from "./types";

/**
 * Contract every AI provider adapter implements. The callable
 * function depends only on this interface via the gateway — never on
 * a specific provider's request/response shape. Swapping the active
 * provider is an addition of one more class + one line in the
 * gateway's provider map, never a rework of the callable function or
 * Flutter.
 */
export interface AiProvider {
  readonly id: string;
  analyzeInspection(
    input: AnalyzeInspectionInput
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
