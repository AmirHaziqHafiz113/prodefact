import {DefectCatalogueEntry, defectCatalogue} from "./defect_catalogue";
import {defectTermsFor} from "./defect_terms";
import {StrongNoteMatch} from "./types";
import {
  NormalizationStrategy,
  normalizeInspectorNote,
} from "./inspector_note";

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
  /** The note gave only a weak signal (defect words, no component): its
   * matches first, then a broader spread over the area's elements. */
  | "noteWeak"
  /** The note was absent or too vague; the area guided the list. */
  | "areaContext"
  /** Neither helped: an even spread across every component. */
  | "broad";

export interface CatalogueShortlist {
  /** In score order (strongest first) — and only these may be chosen. */
  entries: DefectCatalogueEntry[];
  entryIds: string[];
  strategy: ShortlistStrategy;
  /** How the note was read (see `normalizeInspectorNote`). */
  normalizationStrategy: NormalizationStrategy;
  totalCatalogueSize: number;
  /** What the note alone pins down (component and/or defect family). */
  strongNote: StrongNoteMatch;
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
  // Sliding doors route to their own components, never generic doors.
  "sliding": ["sliding door frame", "sliding door panel",
    "sliding door glass"],
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
  reanalysisAttempt?: number;
}): CatalogueShortlist {
  // An explicit Reanalyse is a deliberate second look: the same single
  // request, but over a broader (still capped, still relevant) list.
  const maxEntries = (input.reanalysisAttempt ?? 0) > 0 ?
    SHORTLIST_BROAD_MAX :
    SHORTLIST_MAX;
  const all = defectCatalogue.entries;
  const note = input.note?.trim() ?? "";
  const reading = note ? normalizeInspectorNote(note) : undefined;
  const normalized = reading?.normalized ?? "";
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

  const slidingNote = noteWords.includes("slid");
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
    // A note that says "sliding" is about a sliding door: generic doors
    // and windows (which share words like "glass" or "frame") yield.
    if (slidingNote && !componentWords.includes("slid")) score -= 6;
    const noteScore = Math.max(0, score);
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

  // A component, element or synonym match is a strong reading of the
  // note; defect wording alone (e.g. "gap", "loose") is weak.
  const STRONG_NOTE_SCORE = 8;
  const topNote = Math.max(0, ...scored.map((s) => s.noteScore));

  if (topNote > 0 && topNote < STRONG_NOTE_SCORE) {
    // Weak reading: the note's matches first, then an even spread over
    // the area's elements (or every component), so a vague or
    // misspelt note never narrows the list to the wrong family.
    strategy = "noteWeak";
    const matched = byScore.filter((s) => s.noteScore > 0)
      .slice(0, maxEntries);
    const pool = scored.filter((s) => !matched.includes(s) &&
      (hintedElements.size === 0 || hintedElements.has(s.entry.mainElementId)));
    chosen = [
      ...matched,
      ...roundRobinByComponent(pool, SHORTLIST_BROAD_MAX - matched.length),
    ];
  } else if (topNote > 0) {
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
    chosen = pick([...core, ...rest], maxEntries);
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

  const strongNote = detectStrongNote(normalized || note);
  let entries = chosen.map((s) => s.entry);
  // Component first: when the note names a component, every entry of
  // it is offered (and ranked first) — the defect is then chosen
  // within that component rather than across look-alike ones.
  if (strongNote.componentIds.length > 0) {
    const named = new Set(strongNote.componentIds);
    const fromNamed = all.filter((e) => named.has(e.componentId));
    const ordered = [
      ...strongNote.entryIds.flatMap((id) => {
        const e = all.find((x) => x.id === id);
        return e ? [e] : [];
      }),
      ...fromNamed,
      ...entries,
    ];
    const seen = new Set<string>();
    entries = ordered.filter((e) => !seen.has(e.id) && seen.add(e.id))
      .slice(0, Math.max(maxEntries, fromNamed.length));
  } else if (strongNote.entryIds.length > 0) {
    // A defect family the note spells out ("poor paint") leads the list.
    const lead = strongNote.entryIds.flatMap((id) => {
      const e = all.find((x) => x.id === id);
      return e ? [e] : [];
    });
    const seen = new Set<string>();
    entries = [...lead, ...entries]
      .filter((e) => !seen.has(e.id) && seen.add(e.id))
      .slice(0, maxEntries);
  }
  return {
    entries,
    entryIds: entries.map((e) => e.id),
    strategy,
    normalizationStrategy: reading?.strategy ?? "none",
    totalCatalogueSize: all.length,
    strongNote,
  };
}

/**
 * Deterministically reads what the (normalised) note pins down: the
 * components whose full name it mentions, and the entries whose wording
 * covers every remaining content word. No model call.
 * @param {string} text the normalised note.
 * @return {StrongNoteMatch} the match, `matched: false` when nothing
 *   specific is named.
 */
export function detectStrongNote(text: string): StrongNoteMatch {
  const none: StrongNoteMatch = {
    matched: false, componentIds: [], componentNames: [], entryIds: [],
    unlistedTerms: [],
  };
  const noteWords = Array.from(new Set(words(text)));
  if (noteWords.length === 0) return none;
  const all = defectCatalogue.entries;
  const unlistedTerms = UNLISTED_PARTS
    .filter((phrase) => phrase.every((p) => noteWords.some((n) => same(n, p))))
    .map((phrase) => phrase.join(" "));
  // Words that only name an uncatalogued part are not defect wording.
  const unlistedWords = new Set(
    UNLISTED_PARTS.filter((p) => unlistedTerms.includes(p.join(" ")))
      .flat());

  const components = new Map<string, string>();
  for (const e of all) components.set(e.componentId, e.componentName);
  // The most specific names first, so "sliding door frame" is taken
  // whole and does not also claim the plain "door frame".
  const named = Array.from(components.entries())
    .map(([id, name]) => ({id, name, ws: words(name)}))
    .filter((c) => c.ws.length > 0 &&
      c.ws.every((w) => noteWords.some((n) => same(n, w))))
    .sort((a, b) => b.ws.length - a.ws.length);
  const claimed = new Set<string>();
  const chosen: typeof named = [];
  for (const c of named) {
    if (c.ws.every((w) => claimed.has(w)) && chosen.length > 0) continue;
    chosen.push(c);
    c.ws.forEach((w) => claimed.add(w));
  }
  // "door frame" is part of "sliding door frame": drop the shorter one
  // when the note clearly says sliding.
  const finalNamed = chosen.filter((c) =>
    !chosen.some((o) => o !== c && o.ws.length > c.ws.length &&
      c.ws.every((w) => o.ws.includes(w))));

  const componentWords = new Set(finalNamed.flatMap((c) => c.ws));
  const defectWords = noteWords.filter((w) =>
    !Array.from(componentWords).some((c) => same(c, w)) &&
    !Array.from(unlistedWords).some((u) => same(u, w)));
  const pool = finalNamed.length > 0 ?
    all.filter((e) => finalNamed.some((c) => c.id === e.componentId)) :
    all;
  // With a named component one more word is enough ("railing paint");
  // without one the note must spell out a defect ("poor paint").
  const needed = finalNamed.length > 0 ? 1 : 2;
  const entryIds = defectWords.length >= needed ?
    pool.filter((e) => {
      const dw = [
        ...words(e.defectDescription),
        ...defectTermsFor(e.defectDescription).flatMap(words),
      ];
      return defectWords.every((w) => dw.some((d) => same(d, w)));
    }).slice(0, 12).map((e) => e.id) :
    [];

  return {
    matched: finalNamed.length > 0 || entryIds.length > 0,
    componentIds: finalNamed.map((c) => c.id),
    componentNames: finalNamed.map((c) => c.name),
    entryIds,
    unlistedTerms,
  };
}

/**
 * Parts inspectors name that the controlled catalogue has no component
 * for. A note naming one must not be forced onto a look-alike (a
 * railing is not a door); the inspector adds it to their own catalogue.
 * Stemmed words; every word of a phrase must appear.
 */
const UNLISTED_PARTS: string[][] = [
  ["railing"], ["handrail"], ["balustrade"], ["staircase"], ["stair"],
  ["floor", "trap"], ["cabinet"], ["wardrobe"], ["countertop"], ["fence"],
];

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
