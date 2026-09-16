import {AiProvider, AiProviderError} from "./provider";
import {
  AnalyzeInspectionInput,
  AnalyzeInspectionResult,
  FindingImages,
  FindingInput,
} from "./types";

const DEEPSEEK_ENDPOINT = "https://api.deepseek.com/chat/completions";

// deepseek-flash is DeepSeek's current multimodal (text + image) chat
// model — see docs/ai_provider_architecture.md ("Active provider:
// DeepSeek") for the API reference this was verified against. It
// replaces the earlier text-only `deepseek-chat` integration now that
// evidence photos are resolved and sent alongside each finding's
// structured context.
const DEEPSEEK_MODEL = "deepseek-flash";

const REQUEST_TIMEOUT_MS = 45_000;
const MAX_RETRIES = 1;

/**
 * Builds the system prompt: the JSON contract, plus explicit
 * instructions to distinguish what's actually visible in a photo from
 * inference, and to say so rather than invent a defect when evidence
 * is unclear, irrelevant, or insufficient.
 * @return {string} the system prompt.
 */
function buildSystemPrompt(): string {
  const jsonShape = "{\"suggestions\": [{\"findingId\": string, " +
    "\"suggestedElement\": string, \"suggestedComponent\": string, " +
    "\"defectType\": string, \"recommendation\": string, " +
    "\"notes\": string}]}";
  return [
    "You are ProDefact's professional home inspection analysis",
    "engine. You can see photos as well as read the inspector's text.",
    "",
    "Analyze completed physical inspection findings, using both the",
    "inspector's own observations/notes AND any attached photos.",
    "",
    "You are advisory only. The human inspector is the final",
    "authority — never state or imply otherwise.",
    "",
    "When a photo is attached, clearly distinguish in your notes:",
    "what is directly visible in the photo, what is inference from",
    "context (not literally shown), and where the evidence is",
    "unclear, irrelevant, corrupted, or insufficient to support a",
    "conclusion. If a photo does not clearly show a defect, say so —",
    "never invent a defect the photo doesn't actually support. If a",
    "finding has no usable photo, rely on the inspector's text alone",
    "and note that no visual evidence was available.",
    "",
    "Use only the inspector's own observations, notes, area/element",
    "context, and attached photos. Do not invent facts not present",
    "in the input. If uncertain, give a conservative recommendation",
    "and say so in the notes.",
    "",
    "Respond with JSON only, shaped exactly as:",
    jsonShape,
    "",
    "Return exactly one suggestion per findingId given to you, using",
    "the same findingId values — never invent, omit, or duplicate a",
    "findingId.",
  ].join("\n");
}

type DeepSeekContentBlock =
  | {type: "text"; text: string}
  | {type: "image_url"; image_url: {url: string; detail: "auto"}};

/**
 * Builds one finding's multimodal user-message content: its
 * structured text context first, followed by any resolved photos —
 * see docs/ai_provider_architecture.md ("Vision request format").
 * @param {FindingInput} finding the finding's structured context.
 * @param {FindingImages | undefined} images that finding's resolved
 *   images, if any.
 * @return {DeepSeekContentBlock[]} the content blocks for this finding.
 */
function buildFindingContent(
  finding: FindingInput,
  images: FindingImages | undefined
): DeepSeekContentBlock[] {
  const lines = [
    `findingId: ${finding.findingId}`,
    `area: ${finding.area}${finding.isPlumbingArea ? " (plumbing area)" : ""}`,
    `element: ${finding.element}`,
  ];
  if (finding.component) lines.push(`component: ${finding.component}`);
  if (finding.description) {
    lines.push(`inspector description: ${finding.description}`);
  }
  if (finding.notes) lines.push(`inspector notes: ${finding.notes}`);

  const photoCount = images?.images.length ?? 0;
  const unavailable = images?.unavailableCount ?? 0;
  if (photoCount > 0) {
    lines.push(`attached photos: ${photoCount}`);
  } else if (finding.evidenceCount > 0) {
    lines.push(
      "attached photos: none usable for this finding " +
        "(missing, not yet synced, or unreadable) — rely on the " +
        "text above only"
    );
  } else {
    lines.push("attached photos: none");
  }
  if (unavailable > 0) {
    lines.push(`(${unavailable} additional photo(s) could not be processed)`);
  }

  const blocks: DeepSeekContentBlock[] = [
    {type: "text", text: lines.join("\n")},
  ];
  for (const image of images?.images ?? []) {
    blocks.push({
      type: "image_url",
      image_url: {
        url: `data:${image.mimeType};base64,${image.base64}`,
        detail: "auto",
      },
    });
  }
  return blocks;
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
 * DeepSeek request/response shape. Multimodal: sends each finding's
 * structured context plus any resolved evidence photos (already
 * downloaded/validated/normalized by `ai/evidence.ts` before this
 * class ever sees them).
 */
export class DeepSeekProvider implements AiProvider {
  readonly id = "deepseek";
  readonly supportsImages = true;

  /**
   * @param {string} apiKey the DeepSeek API key, from Secret Manager.
   */
  constructor(private readonly apiKey: string) {}

  /** @inheritdoc */
  async analyzeInspection(
    input: AnalyzeInspectionInput,
    images: FindingImages[]
  ): Promise<AnalyzeInspectionResult> {
    const imagesByFinding = new Map(images.map((i) => [i.findingId, i]));

    const requestBody = {
      model: DEEPSEEK_MODEL,
      temperature: 0.2,
      response_format: {type: "json_object"},
      messages: [
        {role: "system", content: buildSystemPrompt()},
        {
          role: "user",
          content: [
            {
              type: "text",
              text: `propertyType: ${input.propertyType}\n` +
                `inspectionId: ${input.inspectionId}\n` +
                "findings follow, each with any attached photos:",
            },
            ...input.findings.flatMap((finding) => {
              const findingImages = imagesByFinding.get(finding.findingId);
              return buildFindingContent(finding, findingImages);
            }),
          ],
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
