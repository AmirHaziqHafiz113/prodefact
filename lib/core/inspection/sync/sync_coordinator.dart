import 'sync_result.dart';

/// Orchestrates pushing one local inspection session (and its sections,
/// findings, and evidence) to the cloud. See `docs/firebase.md` for the
/// full sync lifecycle and conflict policy.
///
/// This is push-only (local → cloud): it never pulls remote data back
/// down over local state, so it can never silently overwrite a newer
/// local edit with a stale cloud one.
abstract class SyncCoordinator {
  Future<SyncResult> syncSession(String sessionId);

  /// Uploads just what AI analysis of one finding needs: the finding
  /// document and its not-yet-uploaded photos (plus their metadata).
  /// Unlike [syncSession] there is no session-wide lock, so several
  /// findings can prepare for AI at the same time without one parking
  /// the others (QA #27).
  Future<SyncResult> syncFindingEvidence(String sessionId, String findingId);
}
