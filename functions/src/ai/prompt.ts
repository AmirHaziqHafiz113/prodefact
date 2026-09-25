import {defectCatalogue} from "./defect_catalogue";
import {
  INSPECTOR_NOTE_GUIDANCE,
  normalizeInspectorNote,
} from "./inspector_note";
import {
  ClassificationResult,
  ClassifyFindingInput,
  FindingImages,
} from "./types";

/**
 * Shared, provider-neutral prompt construction — every multimodal
 * provider (DeepSeek, OpenAI, ...) sends the exact same system prompt
 * and finding content, so classification behavior never quietly
 * differs by provider. Only the request envelope (endpoint, auth,
 * model id, response-format flag) is provider-specific.
 */

/**
 * Builds the compact catalogue listing embedded in the system prompt —
 * id, main element, component, and defect description only. The
 * corrective action is deliberately never sent to the model: it's
 * resolved server-side from whichever id the model returns, so a
 * hallucinated or altered corrective action can never reach the
 * inspector. Sending the *entire* catalogue every request (rather than
 * a deterministic subset keyed off the area name) is a deliberate
 * choice — see docs/ai_provider_architecture.md ("Why the full
 * catalogue").
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
export function buildSystemPrompt(): string {
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
    INSPECTOR_NOTE_GUIDANCE,
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

export type PromptContentBlock =
  | {type: "text"; text: string}
  | {type: "image_url"; image_url: {url: string; detail: "auto"}};

/**
 * Builds the finding's multimodal user-message content: its structured
 * text context first, followed by any resolved photos. The
 * `image_url`/data-URL content-block shape is the de facto standard
 * both DeepSeek's and OpenAI's Chat Completions APIs use.
 * @param {ClassifyFindingInput} input the finding's structured context.
 * @param {FindingImages} images that finding's resolved images.
 * @return {PromptContentBlock[]} the content blocks for this finding.
 */
export function buildFindingContent(
  input: ClassifyFindingInput,
  images: FindingImages
): PromptContentBlock[] {
  const lines = [
    `findingId: ${input.findingId}`,
    `area: ${input.area}${input.isPlumbingArea ? " (plumbing area)" : ""}`,
  ];
  if (input.note) {
    // Verbatim first; the expanded reading is a separate helper line so
    // the inspector's own wording is never lost (QA #17).
    const note = normalizeInspectorNote(input.note);
    lines.push(`inspector note (verbatim): ${note.original}`);
    if (note.normalized.toLowerCase() !== note.original.toLowerCase()) {
      lines.push(`likely meaning: ${note.normalized}`);
    }
  }

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

  const blocks: PromptContentBlock[] = [
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

/**
 * Structurally validates the raw parsed JSON before it's trusted at
 * all — `gateway.validateAndNormalize` performs the real, catalogue-
 * aware validation before this data is used for anything.
 * @param {unknown} raw the parsed JSON body from the model.
 * @param {string} findingId the finding this response is for.
 * @return {ClassificationResult} the raw (not yet catalogue-validated)
 *   classification.
 */
export function parseClassificationPayload(
  raw: unknown,
  findingId: string
): ClassificationResult {
  if (typeof raw !== "object" || raw === null) {
    throw new Error("Provider response was not a JSON object.");
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
