/// The per-finding AI processing pipeline state — distinct from
/// [FindingStatus] (physical-inspection lifecycle) and from
/// `AiSuggestionStatus` (the inspector's review decision once a
/// suggestion exists).
///
/// This is what makes progressive, asynchronous AI analysis observable
/// and resumable: a finding's photo/note is saved immediately and
/// independently of AI, then moves through this pipeline in the
/// background — see `docs/ai_provider_architecture.md` ("Progressive
/// per-finding AI pipeline").
enum AiFindingStatus {
  /// This finding has no evidence yet, or hasn't been queued for AI —
  /// e.g. a legacy finding from before progressive AI existed.
  notQueued,

  /// Saved and eligible, but AI has not been queued yet because it
  /// hasn't been explicitly approved — AI Credits cost money, so
  /// Save Finding alone never spends any; the inspector must see the
  /// estimate and approve before analysis runs. Set instead of
  /// [queued] whenever `InspectionSession.autoAnalyseEnabled` is
  /// false (the default for Flex Credits) — see
  /// docs/commercial_model.md ("The estimate -> approval -> reservation
  /// -> settlement protocol"). Never used when auto-analyse is on,
  /// where a finding goes straight to [queued] instead.
  awaitingApproval,

  /// Queued for analysis. Also the state shown as "waiting for
  /// connection" whenever the app is offline/signed out — queued is
  /// queued either way; only the *display* distinguishes the reason
  /// nothing is happening yet (see `AiCardState`).
  queued,

  /// Evidence for this finding is being uploaded to cloud storage so
  /// the backend can resolve it — a prerequisite for analysis, not
  /// analysis itself.
  uploading,

  /// The classification request is in flight.
  analyzing,

  /// AI produced a confident catalogue match. An `AiSuggestion` exists
  /// for this finding with a non-null `suggestedCatalogueEntryId`.
  completed,

  /// The classification attempt itself failed (timeout, provider
  /// error, network) — safe and expected to retry; physical inspection
  /// data is never affected either way.
  failed,

  /// AI ran but could not confidently match a catalogue entry (unclear
  /// photo, no plausible match, or multiple equally plausible
  /// candidates). An `AiSuggestion` may still exist with candidate
  /// entries for the inspector to choose from, but
  /// `suggestedCatalogueEntryId` is null. The inspector must classify
  /// this one manually via the searchable catalogue picker.
  needsReview,
}

/// Whether [status] means AI processing is still actively working on
/// this finding (as opposed to settled in a terminal state).
bool aiFindingStatusIsInFlight(AiFindingStatus status) => switch (status) {
  AiFindingStatus.queued ||
  AiFindingStatus.uploading ||
  AiFindingStatus.analyzing => true,
  AiFindingStatus.notQueued ||
  AiFindingStatus.awaitingApproval ||
  AiFindingStatus.completed ||
  AiFindingStatus.failed ||
  AiFindingStatus.needsReview => false,
};
