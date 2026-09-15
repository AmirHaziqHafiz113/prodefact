/// Outcome of one [SyncCoordinator] run for a single session.
enum SyncOutcome {
  /// Pushed successfully; local sync status is now `synced`.
  success,

  /// No signed-in user — sync was not attempted, and local data is
  /// untouched.
  unauthenticated,

  /// The session id doesn't exist locally (nothing to sync).
  sessionNotFound,

  /// A push failed (network, Firebase error, etc). Local data is left
  /// exactly as it was — see the failure-handling policy in
  /// `docs/firebase.md`.
  failure,
}

class SyncResult {
  const SyncResult._(this.outcome, this.message);

  const SyncResult.success() : this._(SyncOutcome.success, null);
  const SyncResult.unauthenticated()
    : this._(SyncOutcome.unauthenticated, null);
  const SyncResult.sessionNotFound()
    : this._(SyncOutcome.sessionNotFound, null);
  const SyncResult.failure(String message)
    : this._(SyncOutcome.failure, message);

  final SyncOutcome outcome;

  /// Human-readable detail for [SyncOutcome.failure]; null otherwise.
  final String? message;

  bool get isSuccess => outcome == SyncOutcome.success;
}
