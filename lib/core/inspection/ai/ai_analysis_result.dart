/// Outcome of one [AiClassificationCoordinator.classifyFinding] call.
enum AiClassificationOutcome {
  /// Classification ran and a suggestion was generated/persisted (with
  /// or without a confident catalogue match — `needsReview` either
  /// way is reflected on the resulting `AiSuggestion`/`Finding`, not
  /// here).
  success,

  /// This finding is already queued/being classified by another
  /// in-flight call — calling again would risk duplicating the
  /// suggestion, so nothing happened. Idempotent: safe to just ignore.
  alreadyInFlight,

  /// The session or finding id doesn't exist locally.
  sessionNotFound,
  findingNotFound,

  /// The finding has no evidence yet — nothing to classify.
  noEvidence,

  /// The AI backend call failed. Physical inspection data (findings,
  /// evidence, etc.) is completely untouched — see the retry policy in
  /// `docs/ai_provider_architecture.md`.
  failure,

  /// The finding has an outstanding request that may still be running
  /// on the backend, so replaying it now could overlap the original.
  /// Nothing was sent; retry at [AiClassificationResult.retryAt] — see
  /// `AiAnalysisAttempt.replaySafeAfter`.
  deferred,
}

class AiClassificationResult {
  const AiClassificationResult._(this.outcome, this.message, [this.retryAt]);

  const AiClassificationResult.success()
    : this._(AiClassificationOutcome.success, null);
  const AiClassificationResult.alreadyInFlight()
    : this._(AiClassificationOutcome.alreadyInFlight, null);
  const AiClassificationResult.sessionNotFound()
    : this._(AiClassificationOutcome.sessionNotFound, null);
  const AiClassificationResult.findingNotFound()
    : this._(AiClassificationOutcome.findingNotFound, null);
  const AiClassificationResult.noEvidence()
    : this._(AiClassificationOutcome.noEvidence, null);
  const AiClassificationResult.failure(String message)
    : this._(AiClassificationOutcome.failure, message);
  const AiClassificationResult.deferred(DateTime retryAt)
    : this._(AiClassificationOutcome.deferred, null, retryAt);

  final AiClassificationOutcome outcome;
  final String? message;

  /// Set only for [AiClassificationOutcome.deferred].
  final DateTime? retryAt;

  bool get isSuccess => outcome == AiClassificationOutcome.success;
}
