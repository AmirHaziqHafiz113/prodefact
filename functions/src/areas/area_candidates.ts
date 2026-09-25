import {HttpsError} from "firebase-functions/v2/https";
import type {Firestore} from "firebase-admin/firestore";

/**
 * Newly discovered areas (QA #12).
 *
 * When an inspector adds an area the suggested list didn't have, it is
 * added to their own inspection immediately, on the device, with no
 * waiting. Separately, the name is submitted here as a *candidate* for
 * future suggestions. Candidates never enter the suggested-area
 * catalogue automatically: typed names are messy ("Master bedroom",
 * "Masterbed", "MBR", "Bilik Master"), so each is normalised, variants
 * are merged into one candidate, and only candidates a reviewer marks
 * `approved` are ever offered to other inspectors.
 *
 * Stored at `areaCandidates/{propertyType}__{normalized_name}`, which
 * Firestore rules make unreachable from clients; only these callables
 * read or write it. A candidate holds the area name, property type,
 * variants seen, a usage count, a review state, timestamps, and the uid
 * of the first submitter. No inspection, unit, address, client, or
 * contact details are stored.
 */

export type AreaCandidateStatus = "pending" | "approved" | "rejected";

export interface AreaCandidate {
  key: string;
  normalizedName: string;
  displayName: string;
  propertyType: string;
  /** Distinct raw spellings seen, capped at [MAX_RAW_VARIANTS]. */
  rawNames: string[];
  usageCount: number;
  status: AreaCandidateStatus;
  createdBy: string;
  createdAt: number;
  updatedAt: number;
}

const MAX_NAME_LENGTH = 60;
const MAX_RAW_VARIANTS = 10;
const PROPERTY_TYPE = /^[a-zA-Z][a-zA-Z0-9]{0,31}$/;

/**
 * Whole-name and phrase synonyms: shorthand, joined words, and Malay
 * terms that mean the same room. Longest phrases are applied first.
 */
const PHRASE_SYNONYMS: Record<string, string> = {
  "bilik tidur utama": "master bedroom",
  "bilik master": "master bedroom",
  "master room": "master bedroom",
  "master bed": "master bedroom",
  "m bedroom": "master bedroom",
  "m bed": "master bedroom",
  "bilik tidur": "bedroom",
  "bilik air": "bathroom",
  "ruang tamu": "living",
  "living room": "living",
  "ruang makan": "dining",
  "dining room": "dining",
  "bilik stor": "store room",
  "storeroom": "store room",
  "bilik utiliti": "utility room",
  "wet kitchen": "wet kitchen",
  "dry kitchen": "dry kitchen",
};

const WORD_SYNONYMS: Record<string, string> = {
  "masterbed": "master bedroom",
  "masterbedroom": "master bedroom",
  "mbr": "master bedroom",
  "bedrm": "bedroom",
  "bdrm": "bedroom",
  "br": "bedroom",
  "bath": "bathroom",
  "bthrm": "bathroom",
  "toilet": "bathroom",
  "tandas": "bathroom",
  "wc": "bathroom",
  "dapur": "kitchen",
  "balkoni": "balcony",
  "stor": "store room",
  "laman": "yard",
  "garaj": "garage",
  "porch": "car porch",
  "one": "1",
  "two": "2",
  "three": "3",
  "four": "4",
  "five": "5",
};

/**
 * Normalises a typed area name so variants of the same room share one
 * candidate. Deterministic, and the raw name is never discarded by
 * callers — it is kept among the candidate's variants.
 * @param {string} raw the area name as typed.
 * @return {string} the normalized name (lower case), or "" if nothing
 *   usable remains.
 */
export function normalizeAreaName(raw: string): string {
  let name = raw
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9 ]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  // "bedroom2" / "br2" -> "bedroom 2" / "br 2"
  name = name.replace(/([a-z])(\d)/g, "$1 $2");

  const phrases = Object.keys(PHRASE_SYNONYMS).sort(
    (a, b) => b.length - a.length
  );
  for (const phrase of phrases) {
    name = name.replace(
      new RegExp(`\\b${phrase}\\b`, "g"),
      PHRASE_SYNONYMS[phrase]
    );
  }
  name = name
    .split(" ")
    .map((word) => WORD_SYNONYMS[word] ?? word)
    .join(" ")
    .replace(/\s+/g, " ")
    .trim();
  // Collapse accidental repeats ("master bedroom bedroom").
  name = name.replace(/\b(\w+)( \1\b)+/g, "$1");
  return name;
}

/**
 * @param {string} normalized a normalized name.
 * @return {string} a readable title-cased name ("Master Bedroom").
 */
export function displayAreaName(normalized: string): string {
  return normalized
    .split(" ")
    .map((w) => (w.length === 0 ? w : w[0].toUpperCase() + w.slice(1)))
    .join(" ");
}

/**
 * @param {string} propertyType e.g. "highRise".
 * @param {string} normalized a normalized name.
 * @return {string} the candidate document id.
 */
export function areaCandidateKey(
  propertyType: string,
  normalized: string
): string {
  return `${propertyType}__${normalized.replace(/ /g, "_")}`;
}

/**
 * @param {unknown} data the callable payload.
 * @return {object} the validated name and property type.
 */
function parseSubmitRequest(data: unknown): {
  rawName: string;
  propertyType: string;
} {
  const d = (data ?? {}) as Record<string, unknown>;
  if (typeof d.rawName !== "string" || typeof d.propertyType !== "string") {
    throw new HttpsError(
      "invalid-argument",
      "rawName and propertyType are required."
    );
  }
  const rawName = d.rawName.trim().replace(/\s+/g, " ");
  if (rawName.length === 0 || rawName.length > MAX_NAME_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `Area names must be 1-${MAX_NAME_LENGTH} characters.`
    );
  }
  if (!PROPERTY_TYPE.test(d.propertyType)) {
    throw new HttpsError("invalid-argument", "Unknown property type.");
  }
  return {rawName, propertyType: d.propertyType};
}

/**
 * `submitAreaCandidate` — records one newly discovered area as a
 * candidate. Idempotent per call only in effect (a repeat counts as
 * another use); merging variants is what keeps the list clean.
 * @param {object} params the request/dependencies.
 * @return {Promise<object>} the candidate's key, name, and review state.
 */
export async function handleSubmitAreaCandidate(params: {
  auth: {uid: string} | null | undefined;
  data: unknown;
  firestore: Firestore;
  now?: () => number;
}): Promise<{key: string; normalizedName: string; status: string}> {
  if (!params.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const {rawName, propertyType} = parseSubmitRequest(params.data);
  const normalizedName = normalizeAreaName(rawName);
  if (normalizedName.length === 0) {
    throw new HttpsError("invalid-argument", "That area name is empty.");
  }
  const key = areaCandidateKey(propertyType, normalizedName);
  const ref = params.firestore.collection("areaCandidates").doc(key);
  const now = (params.now ?? Date.now)();

  const status = await params.firestore.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) {
      const candidate: AreaCandidate = {
        key,
        normalizedName,
        displayName: displayAreaName(normalizedName),
        propertyType,
        rawNames: [rawName],
        usageCount: 1,
        status: "pending",
        createdBy: params.auth!.uid,
        createdAt: now,
        updatedAt: now,
      };
      tx.set(ref, candidate);
      return candidate.status;
    }
    const existing = snap.data() as AreaCandidate;
    const rawNames = existing.rawNames.includes(rawName) ||
      existing.rawNames.length >= MAX_RAW_VARIANTS ?
      existing.rawNames :
      [...existing.rawNames, rawName];
    tx.set(ref, {
      ...existing,
      rawNames,
      usageCount: existing.usageCount + 1,
      updatedAt: now,
    } satisfies AreaCandidate);
    return existing.status;
  });

  return {key, normalizedName, status};
}

/**
 * `getAreaSuggestions` — the reviewed, reusable area names for one
 * property type, most-used first. Pending and rejected candidates are
 * never returned.
 * @param {object} params the request/dependencies.
 * @return {Promise<object>} the approved display names.
 */
export async function handleGetAreaSuggestions(params: {
  auth: {uid: string} | null | undefined;
  data: unknown;
  firestore: Firestore;
}): Promise<{names: string[]}> {
  if (!params.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }
  const d = (params.data ?? {}) as Record<string, unknown>;
  if (typeof d.propertyType !== "string" ||
    !PROPERTY_TYPE.test(d.propertyType)) {
    throw new HttpsError("invalid-argument", "Unknown property type.");
  }
  const snap = await params.firestore
    .collection("areaCandidates")
    .where("propertyType", "==", d.propertyType)
    .limit(200)
    .get();
  const approved = snap.docs
    .map((doc) => doc.data() as AreaCandidate)
    .filter((c) => c.status === "approved")
    .sort((a, b) => b.usageCount - a.usageCount)
    .slice(0, 20);
  return {names: approved.map((c) => c.displayName)};
}
