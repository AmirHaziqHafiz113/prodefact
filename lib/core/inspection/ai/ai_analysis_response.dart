/// One finding's worth of structured AI output. The app never parses
/// free-form prose out of a model response — a real backend gateway is
/// responsible for validating the provider's response against this
/// exact shape before it ever reaches Flutter (see `docs/ai_review.md`).
class AiFindingSuggestion {
  const AiFindingSuggestion({
    required this.findingId,
    this.elementId,
    this.componentId,
    this.defectType,
    this.recommendation,
    this.notes,
  });

  final String findingId;
  final String? elementId;
  final String? componentId;
  final String? defectType;
  final String? recommendation;
  final String? notes;
}

/// The result of one analysis run: which backend produced it, and one
/// suggestion per finding that was submitted.
class AiAnalysisResponse {
  const AiAnalysisResponse({
    required this.providerId,
    required this.suggestions,
  });

  final String providerId;
  final List<AiFindingSuggestion> suggestions;
}
