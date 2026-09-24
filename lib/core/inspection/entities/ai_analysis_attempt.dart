import 'ai_level.dart';

/// The durable billing identity of one approved AI analysis request
/// for a finding — what makes interrupted AI work safely recoverable
/// after navigation, app termination, or a lost connection.
///
/// The backend `analyseFinding` callable is idempotent per
/// [idempotencyKey]: every Credits ledger mutation (reserve, settle,
/// release) is keyed by it, and a finished attempt's outcome is stored
/// under it, so replaying the *same* key can never reserve or charge
/// twice — see `functions/src/billing/handle_analyse_finding.ts` and
/// docs/commercial_model.md. This record is persisted locally **before**
/// the callable is invoked, so an app restart can always replay the
/// exact request that may already have reached the backend, instead of
/// minting a new key (which the backend would treat as a brand-new,
/// separately charged analysis).
///
/// Lifecycle:
/// - created and persisted immediately before the first submission;
/// - reused unchanged (same key, same level) by every replay;
/// - cleared only once the backend has given a *definitive* answer
///   (success, or a rejection known to have charged nothing).
///
/// A finding with no attempt has never had an analysis request that
/// might still be outstanding, so the next approved run safely mints a
/// fresh key.
class AiAnalysisAttempt {
  const AiAnalysisAttempt({
    required this.idempotencyKey,
    required this.aiLevel,
    required this.submittedAt,
  });

  /// How long after a submission a replay of the same key is allowed.
  ///
  /// Must exceed the backend's own `analyseFinding` `timeoutSeconds`
  /// (180s, `functions/src/index.ts`) plus the client callable timeout
  /// margin, so the original invocation is guaranteed to have been
  /// terminated before a replay can start. A replay that overlaps a
  /// still-running original would not double-charge Credits (the
  /// ledger dedupes by key) but could invoke the AI provider twice and
  /// record House Pass usage twice.
  static const Duration replaySafeAfter = Duration(minutes: 4);

  final String idempotencyKey;
  final AiLevel aiLevel;

  /// When this key was most recently submitted to the backend.
  /// Refreshed on every replay, since each replay is itself a new
  /// server invocation that must be allowed to finish first.
  final DateTime submittedAt;

  DateTime get replaySafeAt => submittedAt.add(replaySafeAfter);

  bool isReplaySafeAt(DateTime now) => !now.isBefore(replaySafeAt);

  AiAnalysisAttempt resubmittedAt(DateTime now) => AiAnalysisAttempt(
    idempotencyKey: idempotencyKey,
    aiLevel: aiLevel,
    submittedAt: now,
  );
}
