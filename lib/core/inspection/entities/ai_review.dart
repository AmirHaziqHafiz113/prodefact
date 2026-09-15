/// Where one [AiSuggestion] stands in the inspector's review.
///
/// `pending` suggestions are what gate AI review completion — see
/// `InspectionSession.aiReviewState` and `docs/ai_review.md`.
enum AiSuggestionStatus { pending, accepted, edited, rejected }

/// AI's advisory suggestion for a [Finding], generated only after the
/// full physical inspection is complete (never per-photo, in real time
/// — see the AI timing rule in `docs/ai_review.md`).
///
/// The original AI output (`suggested*`) is immutable once generated and
/// is never overwritten by inspector review — the inspector's
/// accepted/edited/corrected values live separately in the `final*`
/// fields. Both are preserved together for later AI evaluation.
class AiSuggestion {
  const AiSuggestion({
    required this.id,
    required this.sessionId,
    required this.findingId,
    required this.providerId,
    required this.generatedAt,
    this.suggestedElementId,
    this.suggestedComponentId,
    this.suggestedDefectType,
    this.suggestedRecommendation,
    this.suggestedNotes,
    this.finalElementId,
    this.finalComponentId,
    this.finalDefectType,
    this.finalRecommendation,
    this.finalNotes,
    this.status = AiSuggestionStatus.pending,
    this.reviewedAt,
  });

  final String id;
  final String sessionId;
  final String findingId;

  /// Identifies which AI backend/model produced this suggestion (e.g.
  /// `fake-demo-v1`). Never a provider SDK type — just an identifying
  /// string for evaluation/debugging.
  final String providerId;

  final DateTime generatedAt;

  // ---- original AI output — never mutated after generation ----
  final String? suggestedElementId;
  final String? suggestedComponentId;
  final String? suggestedDefectType;
  final String? suggestedRecommendation;
  final String? suggestedNotes;

  // ---- inspector-reviewed / final values ----
  // Start out equal to the suggested* values (see AiReviewCoordinator);
  // Edit changes them directly, Reject/Correct replaces them with the
  // inspector's own assessment, Accept leaves them as-is.
  final String? finalElementId;
  final String? finalComponentId;
  final String? finalDefectType;
  final String? finalRecommendation;
  final String? finalNotes;

  final AiSuggestionStatus status;
  final DateTime? reviewedAt;

  bool get isResolved => status != AiSuggestionStatus.pending;

  AiSuggestion copyWith({
    String? finalElementId,
    String? finalComponentId,
    String? finalDefectType,
    String? finalRecommendation,
    String? finalNotes,
    AiSuggestionStatus? status,
    DateTime? reviewedAt,
  }) {
    return AiSuggestion(
      id: id,
      sessionId: sessionId,
      findingId: findingId,
      providerId: providerId,
      generatedAt: generatedAt,
      suggestedElementId: suggestedElementId,
      suggestedComponentId: suggestedComponentId,
      suggestedDefectType: suggestedDefectType,
      suggestedRecommendation: suggestedRecommendation,
      suggestedNotes: suggestedNotes,
      finalElementId: finalElementId ?? this.finalElementId,
      finalComponentId: finalComponentId ?? this.finalComponentId,
      finalDefectType: finalDefectType ?? this.finalDefectType,
      finalRecommendation: finalRecommendation ?? this.finalRecommendation,
      finalNotes: finalNotes ?? this.finalNotes,
      status: status ?? this.status,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}
