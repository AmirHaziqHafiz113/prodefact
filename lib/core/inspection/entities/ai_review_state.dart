/// The state of the AI analysis run for a whole [InspectionSession] —
/// distinct from any individual `AiSuggestion.status`, which tracks one
/// finding's review instead. See `docs/ai_review.md` for the full
/// lifecycle and the timing rule this exists to enforce.
enum AiReviewState {
  /// Physical inspection may or may not be complete yet; analysis has
  /// never been run for this session.
  notStarted,

  /// An analysis run is in flight (or was interrupted mid-run — e.g. by
  /// a crash — in which case it's safe to retry from this state).
  analyzing,

  /// Suggestions exist and at least one is still pending review.
  readyForReview,

  /// Every generated suggestion has been resolved (accepted, edited, or
  /// rejected/corrected). Only from this state can the inspection
  /// proceed to reporting.
  completed,

  /// The last analysis attempt failed before producing suggestions.
  /// Physical inspection data is always preserved regardless — see
  /// the retry policy in `docs/ai_review.md`.
  failed,
}
