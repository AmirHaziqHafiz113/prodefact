import {AiProvider, AiProviderError} from "./provider";
import {defectCatalogue} from "./defect_catalogue";
import {
  ClassificationResult,
  ClassifyFindingInput,
  FindingImages,
} from "./types";

const DEEPSEEK_ENDPOINT = "https://api.deepseek.com/chat/completions";

// deepseek-flash is DeepSeek's current multimodal (text + image) chat
// model — see docs/ai_provider_architecture.md ("Active provider:
// DeepSeek") for the API reference this was verified against.
const DEEPSEEK_MODEL = "deepseek-flash";

const REQUEST_TIMEOUT_MS = 45_000;
const MAX_RETRIES = 1;

/**
 * Builds the compact catalogue listing embedded in the system prompt —
 * id, main element, component, and defect description only. The
 * corrective action is deliberately never sent to the model: it's
 * resolved server-side from whichever id the model returns, so a
 * hallucinated or altered corrective action can never reach the
 * inspector. Sending the *entire* catalogue every request (rather than
 * a deterministic subset keyed off the area name) is a deliberate
 * choice — this is one small request per finding now, not one huge
 * per-session batch, so the absolute per-request cost stays bounded,
 * and a partial/guessed subset risks the model being unable to find
 * the actually-correct entry for an area whose defects don't map
 * cleanly to its name (see docs/ai_provider_architecture.md, "Why the
 * full catalogue").
 * @return {string} the catalogue listing, one line per defect entry.
 */
function buildCatalogueListing(): string {
  return defectCatalogue.entries
    .map(
      (e) =>
        `${e.id} | ${e.mainElementName} | ${e.componentName} | ` +
        e.defectDescription
    )
    .join("\n");
}

/**
 * Builds the system prompt: the controlled catalogue, the JSON
 * contract, and explicit instructions to select only from the given
 * ids, to say so when uncertain, and to distinguish what's visible in
 * a photo from what's inferred.
 * @return {string} the system prompt.
 */
function buildSystemPrompt(): string {
  const jsonShape = "{\"catalogueEntryId\": string | null, " +
    "\"confidence\": number, \"shortReason\": string, " +
    "\"candidateEntryIds\": string[], \"needsReview\": boolean}";
  return [
    "You are ProDefact's professional home inspection defect",
    "classification engine. You can see a photo of one defect plus",
    "the inspector's own optional note and the area it was found in.",
    "",
    "You must classify this finding by choosing exactly ONE entry",
    "from the CONTROLLED DEFECT CATALOGUE below, identified by its",
    "id. You are NEVER allowed to invent a main element, component,",
    "defect, or corrective action that is not one of the ids listed.",
    "The catalogue format is: id | main element | component | defect",
    "description.",
    "",
    "CONTROLLED DEFECT CATALOGUE:",
    buildCatalogueListing(),
    "",
    "You are advisory only. The human inspector is the final",
    "authority and reviews every classification — never state or",
    "imply otherwise.",
    "",
    "In your notes/reason, clearly distinguish what is directly",
    "visible in the photo from what is inference from context. If",
    "the photo is unclear, irrelevant, or does not clearly match any",
    "catalogue entry, or if multiple entries are similarly plausible,",
    "set needsReview to true and catalogueEntryId to null — do NOT",
    "guess an entry just to have an answer. You may still list up to",
    "3 plausible catalogueEntryIds in candidateEntryIds even when",
    "needsReview is true, so the inspector has a shortlist.",
    "",
    "Respond with JSON only, shaped exactly as:",
    jsonShape,
    "",
    "catalogueEntryId must be exactly one of the ids from the",
    "catalogue above, or null. Never invent a new id.",
  ].join("\n");
}

type DeepSeekContentBlock =
  | {type: "text"; text: string}
  | {type: "image_url"; image_url: {url: string; detail: "auto"}};

/**
 * Builds the finding's multimodal user-message content: its structured
 * text context first, followed by any resolved photos.
 * @param {ClassifyFindingInput} input the finding's structured context.
 * @param {FindingImages} images that finding's resolved images.
 * @return {DeepSeekContentBlock[]} the content blocks for this finding.
 */
function buildFindingContent(
  input: ClassifyFindingInput,
  images: FindingImages
): DeepSeekContentBlock[] {
  const lines = [
    `findingId: ${input.findingId}`,
    `area: ${input.area}${input.isPlumbingArea ? " (plumbing area)" : ""}`,
  ];
  if (input.note) lines.push(`inspector note: ${input.note}`);

  const photoCount = images.images.length;
  if (photoCount > 0) {
    lines.push(`attached photos: ${photoCount}`);
  } else {
    lines.push(
      "attached photos: none usable (missing, not yet synced, or " +
        "unreadable) — rely on the area/note above only"
    );
  }
  if (images.unavailableCount > 0) {
    lines.push(
      `(${images.unavailableCount} additional photo(s) could not be ` +
        "processed)"
    );
  }

  const blocks: DeepSeekContentBlock[] = [
    {type: "text", text: lines.join("\n")},
  ];
  for (const image of images.images) {
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
 * all — `gateway.validateAndNormalize` performs the real, catalogue-
 * aware validation before this data is used for anything.
 * @param {unknown} raw the parsed JSON body from the model.
 * @param {string} findingId the finding this response is for.
 * @return {ClassificationResult} the raw (not yet catalogue-validated)
 *   classification.
 */
function parseClassificationPayload(
  raw: unknown,
  findingId: string
): ClassificationResult {
  if (typeof raw !== "object" || raw === null) {
    throw new AiProviderError("DeepSeek response was not a JSON object.");
  }
  const r = raw as Record<string, unknown>;
  return {
    findingId,
    catalogueEntryId:
      typeof r.catalogueEntryId === "string" ? r.catalogueEntryId : undefined,
    confidence: typeof r.confidence === "number" ? r.confidence : undefined,
    shortReason:
      typeof r.shortReason === "string" ? r.shortReason : undefined,
    candidateEntryIds: Array.isArray(r.candidateEntryIds) ?
      r.candidateEntryIds.filter((x): x is string => typeof x === "string") :
      [],
    needsReview: r.needsReview === true,
  };
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
 * DeepSeek request/response shape. Multimodal: sends the finding's
 * structured context plus any resolved evidence photos (already
 * downloaded/validated/normalized by `ai/evidence.ts` before this
 * class ever sees them), and classifies against the controlled defect
 * catalogue rather than freely inventing a defect/recommendation.
 */
export class DeepSeekProvider implements AiProvider {
  readonly id = "deepseek";
  readonly supportsImages = true;

  /**
   * @param {string} apiKey the DeepSeek API key, from Secret Manager.
   */
  constructor(private readonly apiKey: string) {}

  /** @inheritdoc */
  async classifyFinding(
    input: ClassifyFindingInput,
    images: FindingImages
  ): Promise<ClassificationResult> {
    const requestBody = {
      model: DEEPSEEK_MODEL,
      temperature: 0.2,
      response_format: {type: "json_object"},
      messages: [
        {role: "system", content: buildSystemPrompt()},
        {role: "user", content: buildFindingContent(input, images)},
      ],
    };

    let lastError: unknown;
    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      try {
        return await this.callOnce(requestBody, input.findingId);
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
   * @param {string} findingId the finding this request is for.
   * @return {Promise<ClassificationResult>} the validated result.
   */
  private async callOnce(
    requestBody: Record<string, unknown>,
    findingId: string
  ): Promise<ClassificationResult> {
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

    return parseClassificationPayload(parsedContent, findingId);
  }
}
