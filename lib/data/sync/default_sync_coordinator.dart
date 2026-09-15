import '../../core/inspection/inspection_domain.dart';

/// Pushes one local session (sections, findings, evidence metadata and
/// files) to [CloudInspectionRepository]. Local data is always read
/// from and written back to [InspectionRepository] — this class never
/// invents its own notion of session state.
///
/// See `docs/firebase.md` for the full lifecycle and conflict policy;
/// in short: push-only (local → cloud), idempotent (stable local ids as
/// remote document ids), and a failure never touches local data beyond
/// marking it "still pending".
class DefaultSyncCoordinator implements SyncCoordinator {
  DefaultSyncCoordinator({
    required InspectionRepository localRepository,
    required CloudInspectionRepository cloudRepository,
    required AuthService authService,
  }) : _local = localRepository,
       _cloud = cloudRepository,
       _auth = authService;

  final InspectionRepository _local;
  final CloudInspectionRepository _cloud;
  final AuthService _auth;

  /// Guards against two concurrent `syncSession` calls for the same
  /// session — see `docs/production_readiness.md` ("Concurrency").
  final Set<String> _inFlight = {};

  @override
  Future<SyncResult> syncSession(String sessionId) async {
    if (!_inFlight.add(sessionId)) {
      return const SyncResult.failure('A sync is already running.');
    }
    try {
      return await _syncSession(sessionId);
    } finally {
      _inFlight.remove(sessionId);
    }
  }

  Future<SyncResult> _syncSession(String sessionId) async {
    final user = _auth.currentUser;
    if (user == null) return const SyncResult.unauthenticated();

    final session = await _local.loadSession(sessionId);
    if (session == null) return const SyncResult.sessionNotFound();

    // A guest session becomes owned by whoever first syncs it; a
    // session already owned by someone else is never touched by a
    // different signed-in user (defense in depth — callers are also
    // expected not to offer sync for sessions they don't own).
    if (session.ownerUid != null && session.ownerUid != user.uid) {
      return const SyncResult.unauthenticated();
    }
    if (session.ownerUid == null) {
      await _local.setSessionOwner(session.id, user.uid);
    }

    try {
      await _cloud.pushSession(user.uid, session);
      await _cloud.pushSections(user.uid, session.id, session.sections);

      for (final finding in session.findings) {
        await _cloud.pushFinding(user.uid, session.id, finding);

        for (final evidence in finding.evidence) {
          if (evidence.syncStatus == SyncStatus.synced) continue;

          final storagePath = await _cloud.uploadEvidenceFile(
            user.uid,
            session.id,
            evidence,
          );
          final synced = evidence.copyWith(
            syncStatus: SyncStatus.synced,
            storagePath: storagePath,
          );
          await _cloud.pushEvidenceMetadata(user.uid, session.id, synced);
          await _local.updateEvidenceSyncState(
            evidence.id,
            syncStatus: SyncStatus.synced,
            storagePath: storagePath,
          );
        }
      }

      for (final suggestion in session.aiSuggestions) {
        await _cloud.pushAiSuggestion(user.uid, session.id, suggestion);
      }

      final report = session.report;
      if (report != null) {
        await _cloud.pushReportMetadata(user.uid, session.id, report);
      }

      await _local.setSessionSyncStatus(session.id, SyncStatus.synced);
      return const SyncResult.success();
    } catch (error) {
      // Local data is left exactly as it was — only the sync status
      // reflects the failure, so the inspector's work is never lost and
      // the next "Sync now" (or trigger) can simply retry.
      await _local.setSessionSyncStatus(session.id, SyncStatus.pendingUpdate);
      return SyncResult.failure(error.toString());
    }
  }
}
