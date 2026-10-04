/// Ranked, searchable access to the full controlled catalogue for the
/// "Other possible defects" picker (2026-10-06) — a manual,
/// never-AI-calling alternative/supplement to the top-4 candidates.
/// Deterministic and entirely on-device.
library;

import 'defect_catalogue.dart';
import 'defect_terms.dart';
import 'note_aliases.dart';

const _stopwords = {
  'the',
  'a',
  'an',
  'is',
  'are',
  'of',
  'and',
  'or',
  'at',
  'on',
  'in',
  'with',
  'near',
  'to',
  'not',
  'properly',
  'very',
  'some',
  'this',
  'that',
  'there',
  'have',
  'has',
  'for',
  'from',
  'area',
  'check',
  'see',
  'photo',
  'defect',
  'issue',
  'problem',
};

/// @return the significant, alias-expanded words of [text] (raw and
/// expanded forms combined, deduplicated) — case-insensitive. Used for
/// the *haystack* side of a match (an entry's own text, or scoring a
/// note against it): extra variants here only make matching more
/// permissive, never less.
Set<String> _tokensOf(String text) {
  if (text.trim().isEmpty) return const {};
  final raw = text.toLowerCase().split(RegExp(r'[^a-z0-9]+'));
  final expanded = expandNoteAliases(text).split(RegExp(r'[^a-z0-9]+'));
  return {
    for (final w in [...raw, ...expanded])
      if (w.length >= 2 && !_stopwords.contains(w)) w,
  };
}

/// The *query* side of a match: [text] read as one normalized phrase
/// (aliases/Malay expanded first, so "pintu sliding" becomes "sliding
/// door" rather than requiring the literal, no-longer-relevant word
/// "pintu" too) and then tokenized. Unlike [_tokensOf], this never
/// unions in the pre-expansion raw words — a word the alias table
/// recognised is superseded by its expansion, not added alongside it.
Set<String> _queryTokensOf(String text) {
  if (text.trim().isEmpty) return const {};
  final expanded = expandNoteAliases(text).split(RegExp(r'[^a-z0-9]+'));
  return {
    for (final w in expanded)
      if (w.length >= 2 && !_stopwords.contains(w)) w,
  };
}

/// What the picker ranks results against: the finding's own note (raw;
/// alias-expanded internally), whatever the AI already reported about
/// this photo, and the entry already shown above (excluded from the
/// results, since it's already offered there).
class RelatedDefectContext {
  const RelatedDefectContext({
    this.note,
    this.detectedElement,
    this.detectedComponent,
    this.candidateEntryIds = const [],
    this.excludeEntryId,
  });

  /// The inspector's quick defect note, verbatim — never modified here.
  final String? note;

  /// What the AI reported seeing in the photo, if anything.
  final String? detectedElement;
  final String? detectedComponent;

  /// The AI's own ranked alternatives (e.g. the top-4 "Possible
  /// defects"), already shown above — ranked ahead of the rest, but
  /// never duplicated below.
  final List<String> candidateEntryIds;

  /// The entry already shown as the current AI/final result — left out
  /// of this list entirely.
  final String? excludeEntryId;
}

/// One catalogue entry scored against [context] — higher is more
/// likely to be what this finding actually is.
double _relatedScore(DefectCatalogueEntry entry, RelatedDefectContext context) {
  var score = 0.0;
  final index = context.candidateEntryIds.indexOf(entry.id);
  if (index != -1) {
    // Still ranked first-to-last among themselves.
    score += 100 - index;
  }
  if (context.detectedComponent != null &&
      entry.componentName.toLowerCase() ==
          context.detectedComponent!.toLowerCase()) {
    score += 40;
  }
  if (context.detectedElement != null &&
      entry.mainElementName.toLowerCase() ==
          context.detectedElement!.toLowerCase()) {
    score += 15;
  }
  final noteTokens = _tokensOf(context.note ?? '');
  if (noteTokens.isNotEmpty) {
    final componentWords = _tokensOf(entry.componentName);
    final elementWords = _tokensOf(entry.mainElementName);
    final defectWords = _tokensOf(entry.defectDescription);
    final termWords = {
      for (final t in defectTermsFor(entry.defectDescription)) ..._tokensOf(t),
    };
    score += componentWords.intersection(noteTokens).length * 6;
    score += elementWords.intersection(noteTokens).length * 3;
    score += defectWords.intersection(noteTokens).length * 2;
    score += termWords.intersection(noteTokens).length * 2;
  }
  return score;
}

/// The full controlled catalogue (minus [RelatedDefectContext.excludeEntryId]),
/// ordered most-related-to-this-finding first, then the rest of the
/// catalogue in its stable, original order. Never filters anything out
/// — the inspector can always scroll to any of the 222 entries; use
/// [searchRelatedDefects] to narrow it by a typed query.
List<DefectCatalogueEntry> rankRelatedDefects(RelatedDefectContext context) {
  final all = DefectCatalogue.instance.entries
      .where((e) => e.id != context.excludeEntryId)
      .toList();
  final scored = [
    for (final e in all) (entry: e, score: _relatedScore(e, context)),
  ];
  // Stable sort: ties keep the catalogue's own order, so an unscored
  // search still reads as a sensible, consistent list.
  scored.sort((a, b) => b.score.compareTo(a.score));
  return [for (final s in scored) s.entry];
}

/// [ranked] narrowed to entries whose element, component, description
/// or recognised aliases match every word of [query] (order-independent,
/// case-insensitive) — relatedness order is preserved. An empty or
/// blank [query] returns [ranked] unchanged.
List<DefectCatalogueEntry> searchRelatedDefects({
  required List<DefectCatalogueEntry> ranked,
  required String query,
}) {
  final queryTokens = _queryTokensOf(query);
  if (queryTokens.isEmpty) return ranked;
  return [
    for (final entry in ranked)
      if (queryTokens.every(
        (t) => _searchableText(entry).any((word) => word.contains(t)),
      ))
        entry,
  ];
}

/// [entry]'s own searchable words, plus the alias-expanded reading of
/// its text — so a search for "sliding door" or "retak" reaches an
/// entry worded only as "Sliding Door Frame" or "crack" respectively.
Set<String> _searchableText(DefectCatalogueEntry entry) {
  final joined =
      '${entry.mainElementName} ${entry.componentName} '
      '${entry.defectDescription}';
  return _tokensOf(joined);
}
