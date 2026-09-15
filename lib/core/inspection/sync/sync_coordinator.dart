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
}
