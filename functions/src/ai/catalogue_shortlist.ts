import {DefectCatalogueEntry, defectCatalogue} from "./defect_catalogue";
import {defectTermsFor} from "./defect_terms";
import {normalizeInspectorNote} from "./inspector_note";

/**
 * Deterministic, server-side catalogue shortlisting (2026-10-04).
 *
 * Instead of sending all 222 controlled entries on every request, the
 * model sees only the entries this finding's note and area point to.
 * No model call is involved here — just scoring against the catalogue's
 * own names and wording. If the model can't classify from the
 * shortlist, the finding becomes needsReview: there is never an
 * automatic second (full-catalogue) request.
 */

/** Target size when the note points somewhere specific. */
export const SHORTLIST_MIN = 12;
export const SHORTLIST_MAX = 30;
/** Ceiling when the note gives nothing to go on (broader, still capped). */
export const SHORTLIST_BROAD_MAX = 60;

export type ShortlistStrategy =
  /** The note matched catalogue components/elements/defects. */
  | "noteMatch"
  /** The note was absent or too vague; the area guided the list. */
  | "areaContext"
  /** Neither helped: an even spread across every component. */
  | "broad";

export interface CatalogueShortlist {
  /** In score order (strongest first) — and only these may be chosen. */
  entries: DefectCatalogueEntry[];
  entryIds: string[];
  strategy: ShortlistStrategy;
  totalCatalogueSize: number;
}

/** Field words for a component/element that its catalogue name lacks. */
const SYNONYMS: Record<string, string[]> = {
  "toilet": ["wc toilet bowl", "wc cistern"],
  "wc": ["wc toilet bowl", "wc cistern"],
  "cistern": ["wc cistern"],
  "bowl": ["wc toilet bowl"],
  "flush": ["wc cistern"],
  "tap": ["water tap"],
  "faucet": ["water tap"],
  "shower": ["shower head"],
  "sink": ["bottle trap", "water tap"],
  "basin": ["bottle trap", "water tap"],
  "trap": ["bottle trap"],
  "drain": ["discharge pipe", "bottle trap"],
  "pipe": ["discharge pipe"],
  "leak": ["water tap", "discharge pipe", "bottle trap", "wc cistern"],
  "db": ["distribution board"],
  "electrical": ["distribution board"],
  "switch": ["door bell switch", "distribution board"],
  "handle": ["door knob/handle", "window handle"],
  "knob": ["door knob/handle"],
  "lock": ["door lockset", "door latch"],
  "hinge": ["door hinge", "window hinge"],
  "grout": ["wall tile", "floor tiles"],
  "plaster": ["concrete wall", "ceiling"],
  "paint": ["concrete wall", "ceiling", "door leaf"],
  "skim": ["concrete wall", "ceiling"],
  "lippage": ["floor tiles", "wall tile"],
  "glass": ["window glass", "sliding door glass"],
  "awning": ["window awning"],
  "grille": ["grill door"],
  "gate": ["grill door"],
  "parquet": ["timber floor"],
  "timber": ["timber floor"],
  "wood": ["timber floor", "wood skirting"],
  "roof": ["roof tiles"],
};

/** Area words and the main elements usually inspected there. */
const AREA_HINTS: Array<[RegExp, string[]]> = [
  [/bath|toilet|wc|powder|shower/, ["sanitary_fitting", "plumbing",
    "wall", "floor"]],
  [/kitchen|dapur|laundry|wash|utility/, ["plumbing", "sanitary_fitting",
    "wall", "floor"]],
  [/balcony|yard|patio|terrace|porch|garden|car ?porch/, ["floor", "wall",
    "door", "plumbing"]],
  // Whole words for "room"/"hall", so "Bathroom" is not a living space.
  [/bed|living|dining|family|study|\bhall\b|\broom\b|foyer|corridor/, [
    "floor",
    "wall", "ceiling", "door", "window", "electrical_fitting"]],
  [/roof|attic/, ["roof", "ceiling"]],
  [/store|utility|db|electrical/, ["electrical_fitting", "door", "wall"]],
  [/entrance|main door|gate/, ["door", "floor", "wall"]],
];

const STOPWORDS = new Set([
  "the", "a", "an", "is", "are", "of", "and", "or", "at", "on", "in",
  "with", "near", "to", "not", "properly", "very", "some", "this", "that",
  "there", "have", "has", "for", "from", "area", "check", "see", "photo",
  "defect", "issue", "problem", "rosak", "ada", "yang", "dan", "di",
]);

/**
 * @param {string} word a lower-case word.
 * @return {string} a light stem: "cracked" -> "crack", "tiles" -> "tile".
 */
function stem(word: string): string {
  if (word.length > 5 && word.endsWith("ing")) return word.slice(0, -3);
  if (word.length > 4 && word.endsWith("ed")) return word.slice(0, -2);
  if (word.length > 3 && word.endsWith("s") && !word.endsWith("ss")) {
    return word.slice(0, -1);
  }
  return word;
}

/**
 * @param {string} text any text.
 * @return {string[]} its meaningful, stemmed words.
 */
function words(text: string): string[] {
  return text
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((w) => w.length >= 2 && !STOPWORDS.has(w))
    .map(stem);
}

/**
 * @param {string} a a stemmed word.
 * @param {string} b another.
 * @return {boolean} whether they name the same thing ("chip"/"chipp",
 *   "damag"/"damage").
 */
function same(a: string, b: string): boolean {
  if (a === b) return true;
  const [short, long] = a.length <= b.length ? [a, b] : [b, a];
  return short.length >= 4 && long.startsWith(short);
}

/**
 * @param {string[]} noteWords the note's words.
 * @param {string[]} target a name's words.
 * @return {number} how many of [target]'s words the note mentions.
 */
function overlap(noteWords: string[], target: string[]): number {
  return target.filter((t) => noteWords.some((n) => same(n, t))).length;
}

/**
 * Builds the shortlist for one finding from its note and area.
 * @param {object} input the finding's note and area.
 * @return {CatalogueShortlist} the entries the model may choose from.
 */
export function buildCatalogueShortlist(input: {
  note?: string;
  area: string;
  isPlumbingArea: boolean;
}): CatalogueShortlist {
  const all = defectCatalogue.entries;
  const note = input.note?.trim() ?? "";
  const normalized = note ? normalizeInspectorNote(note).normalized : "";
  const noteWords = Array.from(new Set(words(`${note} ${normalized}`)));

  const areaLower = input.area.toLowerCase();
  const hintedElements = new Set<string>();
  for (const [pattern, elements] of AREA_HINTS) {
    if (pattern.test(areaLower)) elements.forEach((e) => hintedElements.add(e));
  }
  if (input.isPlumbingArea) {
    hintedElements.add("plumbing");
    hintedElements.add("sanitary_fitting");
  }

  const synonymComponents = new Set<string>();
  for (const w of noteWords) {
    for (const [key, components] of Object.entries(SYNONYMS)) {
      if (same(w, stem(key))) {
        components.forEach((c) => synonymComponents.add(c));
      }
    }
  }

  const scored = all.map((entry, index) => {
    const componentWords = words(entry.componentName);
    const elementWords = words(entry.mainElementName);
    const componentHits = overlap(noteWords, componentWords);
    let score = 0;
    // The component named in full is the strongest signal.
    if (componentHits > 0 && componentHits === componentWords.length) {
      score += 10;
    } else {
      score += componentHits * 4;
    }
    if (synonymComponents.has(entry.componentName.toLowerCase())) score += 8;
    score += overlap(noteWords, elementWords) * 5;
    // Defect wording ("hollow", "leaking", "cracked", ...).
    const defectWords = words(entry.defectDescription);
    score += overlap(noteWords, defectWords) * 3;
    score += overlap(
      noteWords,
      defectTermsFor(entry.defectDescription).flatMap(words)
    ) * 2;
    const noteScore = score;
    // Worth one defect-word match, so the area's usual elements win ties
    // against incidental wording elsewhere in the catalogue.
    if (hintedElements.has(entry.mainElementId)) score += 3;
    return {entry, index, score, noteScore};
  });
  const byScore = [...scored].sort(
    (a, b) => b.score - a.score || a.index - b.index
  );

  const pick = (list: typeof scored, max: number) => list.slice(0, max);
  let chosen: typeof scored;
  let strategy: ShortlistStrategy;

  if (byScore[0]?.noteScore > 0) {
    // Every entry of the best-matching components (so the model can
    // choose the right defect), then the next-strongest matches across
    // the catalogue, so one keyword never excludes all alternatives.
    strategy = "noteMatch";
    const top = byScore[0].score;
    const strongComponents = new Set(
      byScore
        .filter((s) => s.noteScore > 0 && s.score >= top * 0.6)
        .map((s) => s.entry.componentId)
    );
    const core = byScore.filter((s) =>
      strongComponents.has(s.entry.componentId));
    const rest = byScore.filter((s) =>
      !strongComponents.has(s.entry.componentId) && s.score > 0);
    chosen = pick([...core, ...rest], SHORTLIST_MAX);
    if (chosen.length < SHORTLIST_MIN) {
      // Too narrow: broaden with siblings of the matched elements.
      const elements = new Set(chosen.map((s) => s.entry.mainElementId));
      const siblings = byScore.filter((s) =>
        !chosen.includes(s) && elements.has(s.entry.mainElementId));
      chosen = pick([...chosen, ...siblings], SHORTLIST_MIN);
    }
  } else if (hintedElements.size > 0) {
    // An even spread over the area's usual components, so one large
    // group (Door has 74 entries) can't crowd out the rest.
    strategy = "areaContext";
    chosen = roundRobinByComponent(
      scored.filter((s) => hintedElements.has(s.entry.mainElementId)),
      SHORTLIST_BROAD_MAX
    );
  } else {
    strategy = "broad";
    chosen = roundRobinByComponent(scored, SHORTLIST_BROAD_MAX);
  }

  const entries = chosen.map((s) => s.entry);
  return {
    entries,
    entryIds: entries.map((e) => e.id),
    strategy,
    totalCatalogueSize: all.length,
  };
}

/**
 * An even spread: the first entry of every component, then the second,
 * and so on, up to [max].
 * @param {Array<{entry: DefectCatalogueEntry}>} scored every entry.
 * @param {number} max the size cap.
 * @return {Array<{entry: DefectCatalogueEntry}>} the spread.
 */
function roundRobinByComponent<T extends {entry: DefectCatalogueEntry}>(
  scored: T[],
  max: number
): T[] {
  const groups = new Map<string, T[]>();
  for (const s of scored) {
    const list = groups.get(s.entry.componentId) ?? [];
    list.push(s);
    groups.set(s.entry.componentId, list);
  }
  const result: T[] = [];
  for (let round = 0; result.length < max; round++) {
    let added = false;
    for (const list of groups.values()) {
      if (round < list.length && result.length < max) {
        result.push(list[round]);
        added = true;
      }
    }
    if (!added) break;
  }
  return result;
}
