import {HttpsError} from "firebase-functions/v2/https";
import {ClassifyFindingInput} from "./types";

/**
 * Cost/abuse guardrails: bounds on what one callable invocation may
 * ask an AI provider to process. Rejecting oversized/malformed input
 * here means a runaway client (buggy or malicious) can never turn
 * into an unbounded provider bill.
 */
export const MAX_TEXT_FIELD_LENGTH = 4_000;
export const MAX_SHORT_FIELD_LENGTH = 200;
/** Mirrors `evidence.ts`'s own per-finding cap — validated here too so
 * an oversized array is rejected with a clear error rather than
 * silently truncated deep inside evidence resolution. */
export const MAX_EVIDENCE_IDS_PER_FINDING = 4;

/**
 * @param {unknown} value the candidate field value.
 * @param {string} field the field's name, for the error message.
 * @param {number} maxLength the maximum allowed string length.
 * @return {string | undefined} the value, if it was a valid optional
 *   string within the length limit.
 */
function requireString(
  value: unknown,
  field: string,
  maxLength: number
): string | undefined {
  if (value === undefined || value === null) return undefined;
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", `${field} must be a string.`);
  }
  if (value.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${field} exceeds the maximum length of ${maxLength} characters.`
    );
  }
  return value;
}

/**
 * @param {unknown} value the candidate field value.
 * @param {string} field the field's name, for the error message.
 * @return {string} the value, if it was a valid required short
 *   string.
 */
function requireShortString(value: unknown, field: string): string {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new HttpsError("invalid-argument", `${field} is required.`);
  }
  if (value.length > MAX_SHORT_FIELD_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `${field} exceeds the maximum length of ` +
        `${MAX_SHORT_FIELD_LENGTH} characters.`
    );
  }
  return value;
}

/**
 * Validates an optional `evidenceIds` array: each entry must be a
 * short, non-empty string, duplicates are dropped, and the list is
 * capped at [MAX_EVIDENCE_IDS_PER_FINDING] entries (extras are simply
 * not sent for resolution — this is a cost bound, not a hard failure,
 * since a finding can legitimately have more photos than we choose to
 * send to the model).
 * @param {unknown} value the candidate `evidenceIds` field.
 * @return {string[] | undefined} the validated, capped id list.
 */
function parseEvidenceIds(value: unknown): string[] | undefined {
  if (value === undefined || value === null) return undefined;
  if (!Array.isArray(value)) {
    throw new HttpsError("invalid-argument", "evidenceIds must be an array.");
  }
  const seen = new Set<string>();
  const ids: string[] = [];
  for (const raw of value) {
    if (typeof raw !== "string" || raw.trim().length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "evidenceIds must contain only non-empty strings."
      );
    }
    if (raw.length > MAX_SHORT_FIELD_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        "evidenceIds entries exceed the maximum length."
      );
    }
    if (seen.has(raw)) continue;
    seen.add(raw);
    if (ids.length < MAX_EVIDENCE_IDS_PER_FINDING) {
      ids.push(raw);
    }
  }
  return ids;
}

/**
 * Validates and narrows the untyped callable payload for one finding.
 * Throws a well-formed `HttpsError` (never a raw exception) for
 * anything malformed or over the configured limits.
 * @param {unknown} data the raw `request.data` from the callable.
 * @return {ClassifyFindingInput} the validated, typed input.
 */
export function parseClassifyFindingInput(
  data: unknown
): ClassifyFindingInput {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError("invalid-argument", "Request payload is required.");
  }
  const payload = data as Record<string, unknown>;

  return {
    inspectionId: requireShortString(payload.inspectionId, "inspectionId"),
    findingId: requireShortString(payload.findingId, "findingId"),
    area: requireShortString(payload.area, "area"),
    isPlumbingArea: payload.isPlumbingArea === true,
    note: requireString(payload.note, "note", MAX_TEXT_FIELD_LENGTH),
    evidenceIds: parseEvidenceIds(payload.evidenceIds),
  };
}
