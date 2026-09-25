/// A newly discovered area waiting to be submitted as a candidate for
/// future suggestions (QA #12). The area itself is already part of the
/// inspection where it was found; this record only exists so the
/// submission survives being offline. It holds the typed name and
/// property type — nothing about the inspection, unit, or client.
class AreaCandidate {
  const AreaCandidate({
    required this.id,
    required this.rawName,
    required this.normalizedName,
    required this.propertyType,
    required this.createdAt,
    this.submitted = false,
  });

  final String id;

  /// Exactly as the inspector typed it.
  final String rawName;

  /// A light local normalisation (lower case, single spaces) for
  /// de-duplicating on the device. The backend applies the authoritative
  /// normalisation (synonyms, shorthand, Malay) when merging candidates.
  final String normalizedName;
  final String propertyType;
  final DateTime createdAt;
  final bool submitted;

  static String normalizeLocally(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
