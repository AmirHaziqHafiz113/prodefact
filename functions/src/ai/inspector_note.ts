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
  "senget": "misaligned",
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
};

const PHRASES = Object.keys(EXPANSIONS)
  .filter((key) => key.includes(" "))
  .sort((a, b) => b.length - a.length);

export interface NormalizedInspectorNote {
  /** Exactly what the inspector typed (trimmed). Never modified. */
  original: string;
  /** The note with known shorthand expanded; equals [original] when
   * nothing was recognised. */
  normalized: string;
  /** Each recognised token and what it was read as, in order. */
  expansions: Array<{from: string; to: string}>;
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

  const words = working.split(/(\s+|[,.;:/()+-])/);
  const normalizedWords = words.map((word) => {
    const expansion = EXPANSIONS[word];
    if (expansion === undefined || word.includes(" ")) return word;
    expansions.push({from: word, to: expansion});
    return expansion;
  });
  const normalized = expansions.length === 0 ?
    original :
    normalizedWords.join("").replace(/\s+/g, " ").trim();

  return {original, normalized, expansions};
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
