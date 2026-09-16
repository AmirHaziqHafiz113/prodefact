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
  /** Count only — evidence bytes/paths are never sent to a provider. */
  evidenceCount: number;
}

/** One session's worth of input to analyze. */
export interface AnalyzeInspectionInput {
  inspectionId: string;
  propertyType: string;
  findings: FindingInput[];
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
