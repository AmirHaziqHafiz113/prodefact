/// Whether the inspector accepted, edited, or rejected an [AiSuggestion].
enum AiSuggestionOutcome { accepted, edited, rejected }

/// AI's advisory suggestion for a [Finding], produced only after the full
/// physical inspection is complete (never per-photo, in real time).
///
/// Both the original AI suggestion and the inspector's final decision are
/// preserved together, since this data is later used for AI evaluation.
class AiSuggestion {
  const AiSuggestion({
    required this.suggestedElementId,
    required this.suggestedComponentId,
    required this.suggestedDefectType,
    required this.suggestedRecommendation,
    this.suggestedNotes,
    this.outcome,
    this.inspectorCorrection,
  });

  final String suggestedElementId;
  final String suggestedComponentId;
  final String suggestedDefectType;
  final String suggestedRecommendation;
  final String? suggestedNotes;

  /// Null until the inspector has reviewed this suggestion.
  final AiSuggestionOutcome? outcome;

  /// The inspector's corrected/edited value, if [outcome] is not accepted.
  final String? inspectorCorrection;

  AiSuggestion copyWith({
    AiSuggestionOutcome? outcome,
    String? inspectorCorrection,
  }) {
    return AiSuggestion(
      suggestedElementId: suggestedElementId,
      suggestedComponentId: suggestedComponentId,
      suggestedDefectType: suggestedDefectType,
      suggestedRecommendation: suggestedRecommendation,
      suggestedNotes: suggestedNotes,
      outcome: outcome ?? this.outcome,
      inspectorCorrection: inspectorCorrection ?? this.inspectorCorrection,
    );
  }
}
