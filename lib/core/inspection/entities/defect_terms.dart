/// One concrete defect per finding (tester feedback, 2026-10-02).
///
/// Many controlled catalogue entries word several defects as one, e.g.
/// "Window frame is damaged/chipped/scratched". The catalogue stays as
/// the client wrote it; AI picks ONE term from the chosen entry's own
/// alternatives, and the report prints that term.
///
/// Mirrors `functions/src/ai/defect_terms.ts` exactly; both are pinned
/// to `functions/src/ai/defect_terms.fixture.json`.
library;

/// Defect words/phrases an alternative may be — only these count, so a
/// slash separating something else ("opened/closed", "wall/floor") is
/// never a choice. Longest first.
final List<String> defectTermVocabulary = [
  'inconsistent colour tone',
  'contaminated with stain',
  'not installed properly',
  'not functioning properly',
  'not properly done',
  'rattles when closed',
  'reversed gradient',
  'slow draining',
  'not straight',
  'not aligned',
  'peeled off',
  'misaligned',
  'scratched',
  'damaged',
  'chipped',
  'cracked',
  'crack',
  'slanted',
  'lippage',
  'missing',
  'leaking',
  'stained',
  'uneven',
  'hollow',
  'broken',
  'dented',
  'dripping',
  'clogged',
  'faded',
  'rusty',
  'loose',
  'poor',
  'gap',
]..sort((a, b) => b.length.compareTo(a.length));

/// The concrete defect alternatives in [description], in order, or an
/// empty list when it describes a single defect.
List<String> defectTermsFor(String description) {
  if (!description.contains('/')) return const [];
  final terms = <String>[];
  for (final raw in description.split('/')) {
    final token = raw.trim().toLowerCase().replaceFirst(
      RegExp(r'[.\s]+$'),
      '',
    );
    String? term;
    for (final v in defectTermVocabulary) {
      if (token == v || token.endsWith(' $v') || token.startsWith('$v ')) {
        term = v;
        break;
      }
    }
    if (term != null && !terms.contains(term)) terms.add(term);
  }
  return terms.length >= 2 ? terms : const [];
}

/// [term] in its canonical form if it is one of [description]'s
/// alternatives, otherwise null.
String? matchDefectTerm(String description, String? term) {
  if (term == null) return null;
  final wanted = term.trim().toLowerCase();
  for (final t in defectTermsFor(description)) {
    if (t == wanted) return t;
  }
  return null;
}

/// How a classified finding's defect reads in the app and the report:
/// "Wall Tile - hollow" when a concrete [term] was chosen from a
/// multi-defect entry, otherwise the entry's own catalogue wording.
String concreteDefectText({
  required String componentName,
  required String defectDescription,
  String? term,
}) => term == null ? defectDescription : '$componentName - $term';
