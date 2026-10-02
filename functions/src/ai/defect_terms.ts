/**
 * One concrete defect per finding (tester feedback, 2026-10-02).
 *
 * Many controlled catalogue entries word several defects as one, e.g.
 * "Window frame is damaged/chipped/scratched". The catalogue itself
 * stays exactly as the client wrote it; instead the model also picks
 * ONE concrete defect term, and that term must be one of the
 * alternatives in the chosen entry's own wording. This file derives
 * those alternatives mechanically — the Flutter app mirrors it in
 * `lib/core/inspection/entities/defect_terms.dart`, and both are
 * pinned to the same fixture (`defect_terms.fixture.json`).
 */

/**
 * Defect words/phrases an alternative may be. Only these count, so a
 * slash that separates something else ("opened/closed", "wall/floor")
 * never turns into a fake choice. Longer phrases are tried first.
 */
export const DEFECT_TERM_VOCABULARY: readonly string[] = [
  "inconsistent colour tone",
  "contaminated with stain",
  "not installed properly",
  "not properly done",
  "reversed gradient",
  "slow draining",
  "not functioning properly",
  "rattles when closed",
  "not straight",
  "not aligned",
  "peeled off",
  "misaligned",
  "scratched",
  "damaged",
  "chipped",
  "cracked",
  "crack",
  "slanted",
  "lippage",
  "missing",
  "leaking",
  "stained",
  "uneven",
  "hollow",
  "broken",
  "dented",
  "dripping",
  "clogged",
  "faded",
  "rusty",
  "loose",
  "poor",
  "gap",
].slice().sort((a, b) => b.length - a.length);

/**
 * @param {string} description a catalogue entry's defect description.
 * @return {string[]} its concrete defect alternatives, in order, or an
 *   empty list when it describes a single defect (fewer than two
 *   alternatives recognised).
 */
export function defectTermsFor(description: string): string[] {
  if (!description.includes("/")) return [];
  const terms: string[] = [];
  for (const raw of description.split("/")) {
    const token = raw.trim().toLowerCase().replace(/[.\s]+$/, "");
    const term = DEFECT_TERM_VOCABULARY.find(
      (v) =>
        token === v ||
        token.endsWith(` ${v}`) ||
        token.startsWith(`${v} `)
    );
    if (term && !terms.includes(term)) terms.push(term);
  }
  return terms.length >= 2 ? terms : [];
}

/**
 * @param {string} description the chosen entry's defect description.
 * @param {unknown} term the model's proposed term.
 * @return {string | undefined} the matching allowed term (in its
 *   canonical lower-case form), or undefined if it isn't one.
 */
export function matchDefectTerm(
  description: string,
  term: unknown
): string | undefined {
  if (typeof term !== "string") return undefined;
  const wanted = term.trim().toLowerCase();
  return defectTermsFor(description).find((t) => t === wanted);
}
