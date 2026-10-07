import {defectCatalogue} from "./defect_catalogue";

/**
 * Inspector shorthand support (QA #17). Field notes are written fast:
 * abbreviations ("win frem gap"), phonetic spelling ("holo"), Malay
 * ("retak dinding") and English mixed together, and small typos.
 *
 * Two complementary measures, neither of which alters what the
 * inspector wrote:
 * 1. The system prompt tells the model explicitly to expect this (see
 *    `INSPECTOR_NOTE_GUIDANCE`), so it can interpret shorthand that no
 *    list anticipates.
 * 2. `normalizeInspectorNote` expands a curated list of common tokens
 *    into a separate "likely meaning" line. The verbatim note is always
 *    sent too, and is the only version stored or shown in reports.
 */

/**
 * Common shorthand, misspellings and Malay terms, keyed by lower-case
 * token. Multi-word keys are matched as whole phrases before single
 * words. Deliberately conservative: only mappings an inspector would
 * agree with; anything ambiguous is left for the model.
 */
const EXPANSIONS: Record<string, string> = {
  // English shorthand / phonetic spellings
  "holo": "hollow",
  "hallow": "hollow",
  "holoww": "hollow",
  "lekang": "hollow",
  "hollo": "hollow",
  "holow": "hollow",
  "hollw": "hollow",
  "frem": "frame",
  "fram": "frame",
  "frm": "frame",
  "win": "window",
  "wdw": "window",
  "wndw": "window",
  "windw": "window",
  "dr": "door",
  "dore": "door",
  "dor": "door",
  "slidng": "sliding",
  "sliiding": "sliding",
  "flr": "floor",
  "clg": "ceiling",
  "ceil": "ceiling",
  "celing": "ceiling",
  "wl": "wall",
  "crk": "crack",
  "crak": "crack",
  "krak": "crack",
  "cracj": "crack",
  "tl": "tile",
  "tyle": "tile",
  "skm": "skim",
  "pnt": "paint",
  "unevn": "uneven",
  "uneve": "uneven",
  "lkg": "leaking",
  "leek": "leak",
  "dmg": "damage",
  "dmgd": "damaged",
  "misalign": "misaligned",
  "stn": "stain",
  "scrtch": "scratch",
  "scrach": "scratch",
  "sealnt": "sealant",
  "silicon": "silicone",
  "grt": "grout",
  "cab": "cabinet",
  "cabnet": "cabinet",
  "sktg": "skirting",
  "skirt": "skirting",
  "wc": "toilet",
  "bth": "bathroom",
  "mbr": "master bedroom",
  "mbth": "master bathroom",
  // Sliding doors (QA 2026-10-04): never collapse into generic doors.
  "pintu gelongsor": "sliding door",
  "pintu sliding": "sliding door",
  "sliding pintu": "sliding door",
  "glass door": "sliding door glass",
  "pintu kaca": "sliding door glass",
  "gelongsor": "sliding",
  // Malay (BM)
  "retak": "crack",
  "keretakan": "crack",
  "bocor": "leak",
  "rosak": "damaged",
  "pecah": "broken",
  "kemek": "dent",
  "calar": "scratch",
  "kotor": "dirty",
  "tompok": "stain",
  "kesan air": "water stain",
  "air bertakung": "water ponding",
  "bertakung": "ponding",
  "takung": "ponding",
  "berlubang": "hole",
  "lubang": "hole",
  "tak rata": "uneven",
  "tidak rata": "uneven",
  "senget": "not aligned slanted",
  "tak align": "not aligned",
  "x align": "not aligned",
  "tidak align": "not aligned",
  "tak lurus": "not straight",
  "align": "aligned",
  "tombol": "knob handle",
  "pemegang": "handle",
  "engsel": "hinge",
  "kunci": "lock",
  "kaca": "glass",
  "bingkai tingkap": "window frame",
  "kepala paip": "water tap",
  "pili": "tap",
  "mangkuk tandas": "toilet bowl",
  "karat": "rusty",
  "berkarat": "rusty",
  "sompek": "chipped",
  "sumbing": "chipped",
  "kesan": "stain",
  "silikon": "sealant",
  "getah": "rubber seal",
  "skru": "screw",
  "hilang": "missing",
  "tiada": "missing",
  "takde": "missing",
  "berbunyi": "creaking sound",
  "bunyi": "sound",
  "tersumbat": "clogged",
  "sumbat": "clogged",
  "tak jalan": "not functioning",
  "tak berfungsi": "not functioning",
  "rekahan": "crack",
  "longgar": "loose",
  "kosong": "hollow",
  "jubin": "tile",
  "dinding": "wall",
  "lantai": "floor",
  "siling": "ceiling",
  "tingkap": "window",
  "pintu": "door",
  "bingkai": "frame",
  "paip": "pipe",
  "sinki": "sink",
  "tandas": "toilet",
  "bilik air": "bathroom",
  "dapur": "kitchen",
  "cat": "paint",
  "celah": "gap",
  "renggang": "gap",
  "perangkap lantai": "floor trap",
  "perangkap": "trap",
  "por": "poor",
  "pur": "poor",
  "peint": "paint",
  "railng": "railing",
  "railin": "railing",
  "raling": "railing",
  "railings": "railing",
  "flo": "floor",
};

const PHRASES = Object.keys(EXPANSIONS)
  .filter((key) => key.includes(" "))
  .sort((a, b) => b.length - a.length);

/** Words never "corrected" (Malay/English filler, units, numbers). */
const NO_FUZZ = new Set([
  "bawah", "atas", "dekat", "sebelah", "kat", "ada", "tak", "yang",
  "dan", "dengan", "pada", "near", "under", "above", "beside", "below",
  "area", "unit", "level", "check", "please", "maybe",
]);

/**
 * Words the fuzzy corrector may snap a typo to: every word of the
 * controlled catalogue (element, component, defect wording) plus every
 * expansion target. Built once.
 */
let fuzzyVocabulary: Set<string> | undefined;

/**
 * @return {Set<string>} the correction vocabulary.
 */
function vocabulary(): Set<string> {
  if (fuzzyVocabulary) return fuzzyVocabulary;
  const words = new Set<string>();
  const add = (text: string) => {
    for (const w of text.toLowerCase().split(/[^a-z]+/)) {
      if (w.length >= 4) words.add(w);
    }
  };
  for (const e of defectCatalogue.entries) {
    add(e.mainElementName);
    add(e.componentName);
    add(e.defectDescription);
  }
  Object.values(EXPANSIONS).forEach(add);
  fuzzyVocabulary = words;
  return words;
}

/**
 * Optimal string alignment distance (Levenshtein + adjacent swaps),
 * stopping early once it exceeds [max].
 * @param {string} a one word.
 * @param {string} b another.
 * @param {number} max the largest distance of interest.
 * @return {number} the distance, or max + 1 when larger.
 */
export function editDistance(a: string, b: string, max: number): number {
  if (Math.abs(a.length - b.length) > max) return max + 1;
  const d: number[][] = Array.from({length: a.length + 1}, (_, i) =>
    Array.from({length: b.length + 1}, (_, j) => (i === 0 ? j : j === 0 ?
      i : 0)));
  for (let i = 1; i <= a.length; i++) {
    let rowMin = Infinity;
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      d[i][j] = Math.min(d[i - 1][j] + 1, d[i][j - 1] + 1,
        d[i - 1][j - 1] + cost);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        d[i][j] = Math.min(d[i][j], d[i - 2][j - 2] + 1);
      }
      rowMin = Math.min(rowMin, d[i][j]);
    }
    if (rowMin > max) return max + 1;
  }
  return d[a.length][b.length];
}

/**
 * The one vocabulary word [word] is most likely a typo of, if any:
 * distance 1 for 4-6 letters, 2 for 7+, and only when a single best
 * match exists (a tie is ambiguous and left alone).
 * @param {string} word a lower-case word not otherwise recognised.
 * @return {string | undefined} the correction.
 */
function fuzzyCorrect(word: string): string | undefined {
  if (word.length < 4 || NO_FUZZ.has(word) || /\d/.test(word)) {
    return undefined;
  }
  const vocab = vocabulary();
  if (vocab.has(word)) return undefined;
  const max = word.length >= 7 ? 2 : 1;
  let best: string | undefined;
  let bestDistance = max + 1;
  let tie = false;
  for (const candidate of vocab) {
    const distance = editDistance(word, candidate, max);
    if (distance < bestDistance) {
      best = candidate;
      bestDistance = distance;
      tie = false;
    } else if (distance === bestDistance && distance <= max) {
      // Plural/singular of the same word is not a real tie.
      if (!(candidate.startsWith(best ?? "") ||
        (best ?? "").startsWith(candidate))) {
        tie = true;
      }
    }
  }
  return best && bestDistance <= max && !tie ? best : undefined;
}

export type NormalizationStrategy = "none" | "alias" | "fuzzy";

export interface NormalizedInspectorNote {
  /** Exactly what the inspector typed (trimmed). Never modified. */
  original: string;
  /** The note with known shorthand expanded; equals [original] when
   * nothing was recognised. */
  normalized: string;
  /** Each recognised token and what it was read as, in order. */
  expansions: Array<{from: string; to: string}>;
  /** How the note was read: unchanged, via known aliases, or with at
   * least one fuzzy typo correction. */
  strategy: NormalizationStrategy;
}

/**
 * @param {string} note the inspector's note, verbatim.
 * @return {NormalizedInspectorNote} the original plus a separate,
 *   expanded reading.
 */
export function normalizeInspectorNote(note: string): NormalizedInspectorNote {
  const original = note.trim();
  const expansions: Array<{from: string; to: string}> = [];
  let working = original.toLowerCase();

  for (const phrase of PHRASES) {
    const pattern = new RegExp(`\\b${phrase}\\b`, "g");
    if (pattern.test(working)) {
      expansions.push({from: phrase, to: EXPANSIONS[phrase]});
      working = working.replace(pattern, EXPANSIONS[phrase]);
    }
  }

  const aliasCount = expansions.length;
  const words = working.split(/(\s+|[,.;:/()+-])/);
  let fuzzy = 0;
  const normalizedWords = words.map((word) => {
    const expansion = EXPANSIONS[word];
    if (expansion !== undefined && !word.includes(" ")) {
      expansions.push({from: word, to: expansion});
      return expansion;
    }
    if (!/^[a-z]+$/.test(word)) return word;
    const corrected = fuzzyCorrect(word);
    if (!corrected) return word;
    fuzzy++;
    expansions.push({from: word, to: corrected});
    return corrected;
  });
  const normalized = expansions.length === 0 ?
    original :
    normalizedWords.join("").replace(/\s+/g, " ").trim();
  const strategy: NormalizationStrategy = fuzzy > 0 ? "fuzzy" :
    expansions.length > 0 || aliasCount > 0 ? "alias" : "none";

  return {original, normalized, expansions, strategy};
}

/**
 * The system-prompt section telling the model how inspector notes are
 * written.
 */
export const INSPECTOR_NOTE_GUIDANCE = [
  "INSPECTOR NOTES:",
  "The inspector's note is typed quickly on site. Expect shorthand and",
  "abbreviations (\"win\" = window, \"frem\" = frame, \"flr\" = floor),",
  "phonetic or misspelt words (\"holo\" = hollow, \"crak\" = crack),",
  "Malay (BM), English, or both mixed in one note (\"retak dinding\" =",
  "wall crack, \"jubin kosong\" = hollow tile, \"bocor\" = leak), and",
  "minor spelling mistakes. Interpret the note generously as a",
  "professional inspector would, using the photo to resolve anything",
  "ambiguous. A \"likely meaning\" line may accompany the verbatim note;",
  "it is only a helper — the verbatim note and the photo remain the",
  "evidence. Never reject or down-weight a note because of its",
  "spelling or language.",
].join("\n");
