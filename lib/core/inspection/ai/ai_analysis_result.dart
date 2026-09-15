/// Outcome of one [AiReviewCoordinator.runAnalysis] call.
enum AiAnalysisOutcome {
  /// Analysis ran and suggestions were generated/persisted.
  success,

  /// The AI gate: physical inspection isn't complete yet. Analysis was
  /// never attempted, and no suggestion records were touched.
  notReady,

  /// Suggestions already exist and review is in progress or done —
  /// calling again would risk duplicating/discarding review work, so
  /// nothing happened. Use the per-suggestion review actions instead.
  alreadyReviewed,

  /// The session id doesn't exist locally.
  sessionNotFound,

  /// The AI backend call failed. Physical inspection data (findings,
  /// evidence, etc.) is completely untouched — see the retry policy in
  /// `docs/ai_review.md`.
  failure,
}

class AiAnalysisResult {
  const AiAnalysisResult._(this.outcome, this.message);

  const AiAnalysisResult.success() : this._(AiAnalysisOutcome.success, null);
  const AiAnalysisResult.notReady() : this._(AiAnalysisOutcome.notReady, null);
  const AiAnalysisResult.alreadyReviewed()
    : this._(AiAnalysisOutcome.alreadyReviewed, null);
  const AiAnalysisResult.sessionNotFound()
    : this._(AiAnalysisOutcome.sessionNotFound, null);
  const AiAnalysisResult.failure(String message)
    : this._(AiAnalysisOutcome.failure, message);

  final AiAnalysisOutcome outcome;
  final String? message;

  bool get isSuccess => outcome == AiAnalysisOutcome.success;
}
