import {DefectCatalogueEntry, defectCatalogue} from "./defect_catalogue";
import {buildCatalogueShortlist} from "./catalogue_shortlist";
import {defectTermsFor} from "./defect_terms";
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
 * The catalogue lines one request may choose from: id, main element,
 * component, defect description, and (for multi-defect entries) the
 * allowed terms. Only the finding's shortlist is ever sent — never the
 * whole catalogue on a normal request (see `catalogue_shortlist.ts`).
 * The corrective action is deliberately never sent: it's resolved
 * server-side from whichever id the model returns, so a hallucinated
 * corrective action can never reach the inspector.
 * @param {DefectCatalogueEntry[]} entries the shortlisted entries.
 * @return {string} the listing, one line per entry.
 */
function buildCatalogueListing(entries: DefectCatalogueEntry[]): string {
  return entries
    .map((e) => {
      const terms = defectTermsFor(e.defectDescription);
      const line =
        `${e.id} | ${e.mainElementName} | ${e.componentName} | ` +
        e.defectDescription;
      return terms.length ? `${line} | terms: ${terms.join(", ")}` : line;
    })
    .join("\n");
}

/**
 * The entries one finding's request may choose from: the shortlist the
 * callable set on [input], or (a direct provider call) one built now.
 * @param {ClassifyFindingInput} input the finding's context.
 * @return {DefectCatalogueEntry[]} the allowed entries.
 */
export function promptCatalogueFor(
  input: ClassifyFindingInput
): DefectCatalogueEntry[] {
  const ids = input.shortlistEntryIds ??
    buildCatalogueShortlist(input).entryIds;
  return ids
    .map((id) => defectCatalogue.getById(id))
    .filter((e): e is DefectCatalogueEntry => e !== undefined);
}

/**
 * Builds the system prompt: the finding's shortlisted catalogue
 * entries, the JSON contract, and explicit instructions to select only
 * from the given ids, to say so when uncertain, and to flag photos that
 * are not inspection photos.
 * @param {DefectCatalogueEntry[]} entries the shortlisted entries.
 * @return {string} the system prompt.
 */
export function buildSystemPrompt(entries: DefectCatalogueEntry[]): string {
  const jsonShape = "{\"isRelevantInspectionImage\": boolean, " +
    "\"imageUsable\": boolean, \"qualityIssues\": string[], " +
    "\"catalogueEntryId\": string | null, " +
    "\"defectTerm\": string | null, " +
    "\"confidence\": number, \"shortReason\": string, " +
    "\"candidateEntryIds\": string[], \"needsReview\": boolean}";
  return [
    "You are ProDefact's professional home inspection defect",
    "classification engine. For ONE finding you receive the",
    "inspector's note, the area it was found in, and ONE photo.",
    "",
    "EVIDENCE PRIORITY:",
    "1. The inspector's note is the PRIMARY signal. The inspector was",
    "   on site and can tap, test and see what a photo cannot (e.g. a",
    "   hollow-sounding tile, a leak that only shows when water runs).",
    "2. Use the photo to verify, refine or challenge the note — for",
    "   example to tell a wall tile from a floor tile, or a frame from",
    "   its glass.",
    "3. If the photo clearly contradicts the note (it plainly shows a",
    "   different element or defect), do not follow the note blindly:",
    "   set needsReview to true.",
    "4. If the note is plausible but the defect is subtle or not",
    "   visible in the photo, prefer the note.",
    "5. With no note, classify from the photo and area alone.",
    "",
    "IS THIS AN INSPECTION PHOTO?",
    "First decide whether the photo is meaningfully related to a",
    "home/property inspection (building elements, finishes, fittings,",
    "plumbing, electrical, doors, windows, ...). A selfie, food, an",
    "animal, a random screenshot, social-media content, an unrelated",
    "vehicle or object is NOT. For such a photo set",
    "isRelevantInspectionImage to false, catalogueEntryId and",
    "defectTerm to null, candidateEntryIds to [], needsReview to true,",
    "and shortReason to \"Image does not appear related to home",
    "inspection.\" — never force it onto a catalogue entry. Also set",
    "imageUsable to false and qualityIssues to [\"unrelated\"].",
    "",
    "IMAGE USABILITY:",
    "Report qualityIssues using ONLY these values: blur, too_dark,",
    "overexposed, subject_too_small, obstructed, insufficient_context,",
    "unclear, unrelated (an empty list when the photo is fine). Set",
    "imageUsable to false ONLY when the photo genuinely prevents useful",
    "interpretation (you cannot tell what element or area it shows);",
    "then also set needsReview to true. A defect that is simply not",
    "visible — a hollow tile, an intermittent leak, a loose fitting —",
    "does NOT make the photo unusable: if the photo confirms the",
    "component, location or context, it is usable and the inspector's",
    "note carries the defect. Never judge a photo by angle, distance or",
    "framing alone.",
    "",
    "You must classify this finding by choosing exactly ONE entry",
    "from the CONTROLLED DEFECT CATALOGUE below, identified by its",
    "id. The list is a shortlist chosen for this finding; you may ONLY",
    "use its ids. If none of them fits, set needsReview to true and",
    "catalogueEntryId to null.",
    "You are NEVER allowed to invent a main element, component,",
    "defect, or corrective action that is not one of the ids listed.",
    "The catalogue format is: id | main element | component | defect",
    "description, optionally followed by \"| terms: ...\".",
    "",
    "ONE CONCRETE DEFECT ONLY:",
    "Some descriptions list several defects in one entry. Those lines",
    "end with \"terms:\" — when you choose such an entry you MUST also",
    "set defectTerm to the ONE term from that list that best matches",
    "this finding (copy it exactly). For entries without terms, set",
    "defectTerm to null. Never combine defects: no \"/\", \"or\",",
    "\"and\" or multiple ids anywhere in catalogueEntryId or",
    "defectTerm. If several entries or terms are possible, choose the",
    "single most likely one; if you cannot choose with reasonable",
    "confidence, set needsReview to true.",
    "",
    "CONTROLLED DEFECT CATALOGUE (shortlist for this finding):",
    buildCatalogueListing(entries),
    "",
    INSPECTOR_NOTE_GUIDANCE,
    "",
    "You are advisory only. The human inspector is the final",
    "authority and reviews every classification — never state or",
    "imply otherwise.",
    "",
    "In shortReason, say briefly what the note says and what the photo",
    "shows. If the photo is unclear or irrelevant and the note does",
    "not identify the defect, or if no entry fits, set needsReview to",
    "true and catalogueEntryId to null — do NOT guess an entry just to",
    "have an answer. You may still list up to 3 plausible",
    "catalogueEntryIds in candidateEntryIds even when needsReview is",
    "true, so the inspector has a shortlist.",
    "",
    "confidence is your probability (0 to 1) that catalogueEntryId",
    "and defectTerm are both correct.",
    "",
    "Respond with JSON only, shaped exactly as:",
    jsonShape,
    "",
    "catalogueEntryId must be exactly one of the ids listed above, or",
    "null. Never invent a new id. candidateEntryIds may only contain",
    "ids listed above.",
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
  const lines = [`findingId: ${input.findingId}`];
  if (input.note) {
    // The note is the primary signal, so it comes first. Verbatim
    // first; the expanded reading is a separate helper line so the
    // inspector's own wording is never lost (QA #17).
    const note = normalizeInspectorNote(input.note);
    lines.push(`inspector note (PRIMARY, verbatim): ${note.original}`);
    if (note.normalized.toLowerCase() !== note.original.toLowerCase()) {
      lines.push(`likely meaning: ${note.normalized}`);
    }
  } else {
    lines.push("inspector note: none");
  }
  lines.push(
    `area: ${input.area}${input.isPlumbingArea ? " (plumbing area)" : ""}`
  );

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
    defectTerm: typeof r.defectTerm === "string" ? r.defectTerm : undefined,
    isRelevantInspectionImage:
      typeof r.isRelevantInspectionImage === "boolean" ?
        r.isRelevantInspectionImage :
        undefined,
    imageUsable:
      typeof r.imageUsable === "boolean" ? r.imageUsable : undefined,
    qualityIssues: Array.isArray(r.qualityIssues) ?
      r.qualityIssues.filter((x): x is string => typeof x === "string") :
      undefined,
    candidateEntryIds: Array.isArray(r.candidateEntryIds) ?
      r.candidateEntryIds.filter((x): x is string => typeof x === "string") :
      [],
    needsReview: r.needsReview === true,
  };
}
