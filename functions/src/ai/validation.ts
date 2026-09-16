import {HttpsError} from "firebase-functions/v2/https";
import {AnalyzeInspectionInput, FindingInput} from "./types";

/**
 * Cost/abuse guardrails: bounds on what one callable invocation may
 * ask an AI provider to process. Rejecting oversized/malformed input
 * here means a runaway client (buggy or malicious) can never turn
 * into an unbounded provider bill.
 */
export const MAX_FINDINGS_PER_REQUEST = 60;
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
 * short, non-empty string, duplicates within the same finding are
 * dropped, and the list is capped at
 * [MAX_EVIDENCE_IDS_PER_FINDING] entries (extras are simply not sent
 * for resolution — this is a cost bound, not a hard failure, since a
 * finding can legitimately have more photos than we choose to send to
 * the model).
 * @param {unknown} value the candidate `evidenceIds` field.
 * @param {number} index the finding's index, for the error message.
 * @return {string[] | undefined} the validated, capped id list.
 */
function parseEvidenceIds(value: unknown, index: number): string[] | undefined {
  if (value === undefined || value === null) return undefined;
  if (!Array.isArray(value)) {
    throw new HttpsError(
      "invalid-argument",
      `findings[${index}].evidenceIds must be an array.`
    );
  }
  const seen = new Set<string>();
  const ids: string[] = [];
  for (const raw of value) {
    if (typeof raw !== "string" || raw.trim().length === 0) {
      throw new HttpsError(
        "invalid-argument",
        `findings[${index}].evidenceIds must contain only non-empty strings.`
      );
    }
    if (raw.length > MAX_SHORT_FIELD_LENGTH) {
      throw new HttpsError(
        "invalid-argument",
        `findings[${index}].evidenceIds entries exceed the maximum length.`
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
 * Validates and narrows the untyped callable payload. Throws a
 * well-formed `HttpsError` (never a raw exception) for anything
 * malformed or over the configured limits.
 * @param {unknown} data the raw `request.data` from the callable.
 * @return {AnalyzeInspectionInput} the validated, typed input.
 */
export function parseAnalyzeInspectionInput(
  data: unknown
): AnalyzeInspectionInput {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError("invalid-argument", "Request payload is required.");
  }
  const payload = data as Record<string, unknown>;

  const inspectionId = requireShortString(
    payload.inspectionId,
    "inspectionId"
  );
  const propertyType = requireShortString(
    payload.propertyType,
    "propertyType"
  );

  if (!Array.isArray(payload.findings)) {
    throw new HttpsError("invalid-argument", "findings must be an array.");
  }
  if (payload.findings.length === 0) {
    throw new HttpsError("invalid-argument", "findings must not be empty.");
  }
  if (payload.findings.length > MAX_FINDINGS_PER_REQUEST) {
    throw new HttpsError(
      "invalid-argument",
      "A maximum of " +
        `${MAX_FINDINGS_PER_REQUEST} findings may be analyzed per request.`
    );
  }

  const seenIds = new Set<string>();
  const findings: FindingInput[] = payload.findings.map((raw, index) => {
    if (typeof raw !== "object" || raw === null) {
      throw new HttpsError(
        "invalid-argument",
        `findings[${index}] is malformed.`
      );
    }
    const f = raw as Record<string, unknown>;
    const findingId = requireShortString(
      f.findingId,
      `findings[${index}].findingId`
    );
    if (seenIds.has(findingId)) {
      throw new HttpsError(
        "invalid-argument",
        `Duplicate findingId in request: ${findingId}.`
      );
    }
    seenIds.add(findingId);

    return {
      findingId,
      area: requireShortString(f.area, `findings[${index}].area`),
      isPlumbingArea: f.isPlumbingArea === true,
      element: requireShortString(f.element, `findings[${index}].element`),
      component: requireString(
        f.component,
        `findings[${index}].component`,
        MAX_SHORT_FIELD_LENGTH
      ),
      description: requireString(
        f.description,
        `findings[${index}].description`,
        MAX_TEXT_FIELD_LENGTH
      ),
      notes: requireString(
        f.notes,
        `findings[${index}].notes`,
        MAX_TEXT_FIELD_LENGTH
      ),
      evidenceCount:
        typeof f.evidenceCount === "number" && f.evidenceCount >= 0 ?
          Math.min(Math.floor(f.evidenceCount), 999) :
          0,
      evidenceIds: parseEvidenceIds(f.evidenceIds, index),
    };
  });

  return {inspectionId, propertyType, findings};
}
