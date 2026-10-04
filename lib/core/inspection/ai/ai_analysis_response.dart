/// One finding's structured AI classification against the controlled
/// defect catalogue. The app never parses free-form prose out of a
/// model response — a real backend gateway validates the provider's
/// response against this exact shape, and rejects/discards any
/// catalogue id that isn't genuinely in `DefectCatalogue`, before this
/// ever reaches Flutter. See `docs/ai_provider_architecture.md`.
class AiFindingClassification {
  const AiFindingClassification({
    required this.findingId,
    required this.needsReview,
    this.catalogueEntryId,
    this.defectTerm,
    this.isRelevantInspectionImage,
    this.imageUsable,
    this.qualityIssues = const [],
    this.confidence,
    this.shortReason,
    this.candidateEntryIds = const [],
  });

  final String findingId;

  /// The selected catalogue entry id, or null if AI could not
  /// confidently classify this finding at all ([needsReview] is then
  /// always true). Always either null or a genuinely valid catalogue
  /// id — never trusted/used to look up a corrective action until the
  /// gateway/coordinator has independently verified it exists.
  final String? catalogueEntryId;

  /// The ONE concrete defect within [catalogueEntryId]'s wording, when
  /// that entry lists several — see `defectTermsFor`.
  final String? defectTerm;

  /// False when the photo isn't a home-inspection photo at all.
  final bool? isRelevantInspectionImage;

  /// False when the photo prevented useful interpretation.
  final bool? imageUsable;

  /// Controlled values (blur, too_dark, overexposed, subject_too_small,
  /// obstructed, insufficient_context, unclear, unrelated).
  final List<String> qualityIssues;

  /// 0.0-1.0, if the provider reported one.
  final double? confidence;

  /// A short, plain-language reason — not a technical diagnostic
  /// paragraph.
  final String? shortReason;

  /// Ranked alternative catalogue entries, when more than one match
  /// was plausible.
  final List<String> candidateEntryIds;

  /// True when [catalogueEntryId] is null, or when the provider
  /// otherwise flagged this finding as needing manual review (unclear
  /// photo, no confident match).
  final bool needsReview;
}
