/**
 * Provider-neutral shapes shared by every AI provider adapter and the
 * gateway. Nothing provider-specific (DeepSeek/OpenAI/Gemini/Anthropic
 * request/response shapes) belongs here — only what the callable
 * function and Flutter agree on.
 */

/** One finding's redacted context — no account/user data, ever. */
export interface FindingInput {
  findingId: string;
  area: string;
  isPlumbingArea: boolean;
  element: string;
  component?: string;
  description?: string;
  notes?: string;
  /** Total evidence count, independent of how many are analyzable. */
  evidenceCount: number;
  /**
   * Ids only — never a Storage path, a URL, or bytes. The callable
   * resolves each id to an actual image itself, server-side, deriving
   * the Storage location from the authenticated caller's own uid and
   * this finding's ids (see `ai/evidence.ts`) — a client-supplied path
   * is never trusted or even accepted. Missing/unsynced/corrupted
   * evidence is skipped rather than failing the request (see
   * `docs/ai_provider_architecture.md`, "Multimodal evidence
   * resolution").
   */
  evidenceIds?: string[];
}

/** One session's worth of input to analyze. */
export interface AnalyzeInspectionInput {
  inspectionId: string;
  propertyType: string;
  findings: FindingInput[];
}

/** One evidence image, already downloaded, validated, and normalized
 * (see `ai/evidence.ts`) — ready to hand to a multimodal provider. */
export interface ResolvedImage {
  evidenceId: string;
  /** Always a normalized, re-encoded format — see `ai/evidence.ts`. */
  mimeType: "image/jpeg";
  base64: string;
}

/** The (possibly empty) set of successfully resolved images for one
 * finding, alongside how many were requested but could not be used —
 * partial evidence never fails the whole finding/request. */
export interface FindingImages {
  findingId: string;
  images: ResolvedImage[];
  /** Requested evidence ids that could not be resolved/decoded. */
  unavailableCount: number;
}

/** One finding's worth of structured AI output. */
export interface FindingSuggestion {
  findingId: string;
  suggestedElement?: string;
  suggestedComponent?: string;
  defectType?: string;
  recommendation?: string;
  notes?: string;
}

/** The result of one analysis run. */
export interface AnalyzeInspectionResult {
  providerId: string;
  suggestions: FindingSuggestion[];
}
