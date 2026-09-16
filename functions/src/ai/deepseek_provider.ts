import {AiProvider, AiProviderError} from "./provider";
import {AnalyzeInspectionInput, AnalyzeInspectionResult} from "./types";

const DEEPSEEK_ENDPOINT = "https://api.deepseek.com/chat/completions";

// deepseek-chat (DeepSeek-V3) is a stable, text-only, JSON-mode
// capable model well suited to structured inspection analysis. It
// does not accept image input — see
// docs/ai_provider_architecture.md ("Image/evidence capability") for
// the resulting limitation and the path to a multimodal provider
// later.
const DEEPSEEK_MODEL = "deepseek-chat";

const REQUEST_TIMEOUT_MS = 30_000;
const MAX_RETRIES = 1;

/**
 * Builds the system prompt that constrains the model to advisory,
 * grounded, strictly-shaped JSON output.
 * @return {string} the system prompt.
 */
function buildSystemPrompt(): string {
  const jsonShape = "{\"suggestions\": [{\"findingId\": string, " +
    "\"suggestedElement\": string, \"suggestedComponent\": string, " +
    "\"defectType\": string, \"recommendation\": string, " +
    "\"notes\": string}]}";
  return [
    "You are ProDefact's professional home inspection analysis",
    "engine.",
    "",
    "Analyze completed physical inspection findings.",
    "",
    "You are advisory only. The human inspector is the final",
    "authority — never state or imply otherwise.",
    "",
    "Use only the inspector's own observations, notes, and",
    "area/element context provided below. Do not invent facts not",
    "present in the input. If uncertain, give a conservative",
    "recommendation and say so in the notes.",
    "",
    "Respond with JSON only, shaped exactly as:",
    jsonShape,
    "",
    "Return exactly one suggestion per findingId given to you, using",
    "the same findingId values — never invent, omit, or duplicate a",
    "findingId.",
  ].join("\n");
}

interface DeepSeekChatResponse {
  choices?: Array<{ message?: { content?: string } }>;
}

/**
 * Structurally validates the raw parsed JSON before it's trusted at
 * all.
 * @param {unknown} raw the parsed JSON body from the model.
 * @return {unknown[]} the raw suggestion entries, filtered to ones
 *   that at least have a string findingId — still untrusted beyond
 *   that; `gateway.validateAndNormalize` performs the real field-level
 *   validation before this data is used.
 */
function parseSuggestionsPayload(
  raw: unknown
): AnalyzeInspectionResult["suggestions"] {
  if (typeof raw !== "object" || raw === null) {
    throw new AiProviderError("DeepSeek response was not a JSON object.");
  }
  const suggestions = (raw as { suggestions?: unknown }).suggestions;
  if (!Array.isArray(suggestions)) {
    throw new AiProviderError("DeepSeek response had no suggestions array.");
  }
  const withFindingId = suggestions.filter(
    (s): s is Record<string, unknown> => {
      if (typeof s !== "object" || s === null) return false;
      return typeof (s as { findingId?: unknown }).findingId === "string";
    }
  );
  return withFindingId as unknown as AnalyzeInspectionResult["suggestions"];
}

/**
 * Fetches with a hard timeout via `AbortController`.
 * @param {string} url the request URL.
 * @param {RequestInit} init the fetch options.
 * @param {number} timeoutMs the timeout, in milliseconds.
 * @return {Promise<Response>} the fetch response.
 */
async function fetchWithTimeout(
  url: string,
  init: RequestInit,
  timeoutMs: number
): Promise<Response> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, {...init, signal: controller.signal});
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Real, production DeepSeek adapter — the only file that knows the
 * DeepSeek request/response shape.
 */
export class DeepSeekProvider implements AiProvider {
  readonly id = "deepseek";

  /**
   * @param {string} apiKey the DeepSeek API key, from Secret Manager.
   */
  constructor(private readonly apiKey: string) {}

  /** @inheritdoc */
  async analyzeInspection(
    input: AnalyzeInspectionInput
  ): Promise<AnalyzeInspectionResult> {
    const requestBody = {
      model: DEEPSEEK_MODEL,
      temperature: 0.2,
      response_format: {type: "json_object"},
      messages: [
        {role: "system", content: buildSystemPrompt()},
        {
          role: "user",
          content: JSON.stringify({
            propertyType: input.propertyType,
            inspectionId: input.inspectionId,
            findings: input.findings,
          }),
        },
      ],
    };

    let lastError: unknown;
    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      try {
        return await this.callOnce(requestBody);
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
   * @return {Promise<AnalyzeInspectionResult>} the validated result.
   */
  private async callOnce(
    requestBody: Record<string, unknown>
  ): Promise<AnalyzeInspectionResult> {
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

    return {
      providerId: this.id,
      suggestions: parseSuggestionsPayload(parsedContent),
    };
  }
}
