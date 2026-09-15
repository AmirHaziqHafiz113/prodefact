import '../entities/ai_review.dart';
import '../entities/ai_review_state.dart';
import '../entities/evidence.dart';
import '../entities/finding.dart';
import '../entities/industry.dart';
import '../entities/inspection.dart';
import '../entities/inspection_session.dart';
import '../entities/section.dart';
import '../entities/section_status.dart';
import '../entities/sync_status.dart';

/// Durable storage for [InspectionSession]s, generic across industries.
///
/// UI and Riverpod providers never touch the underlying database
/// directly — they depend on this interface, which a local (Drift)
/// implementation satisfies today and a future remote-sync layer can
/// wrap or replace without changing callers.
abstract class InspectionRepository {
  /// Creates and persists a new session with a stable, freshly-generated
  /// id and the given starting sections. [ownerUid] is null for a
  /// "guest" session started while signed out — see the ownership
  /// policy in `docs/firebase.md`.
  Future<InspectionSession> createSession({
    required Industry industry,
    required String assetTypeId,
    required List<Section> initialSections,
    String? ownerUid,
  });

  /// Loads a previously-created session by id, or null if it doesn't
  /// exist (e.g. it was never created, or storage was cleared).
  Future<InspectionSession?> loadSession(String id);

  /// Lightweight summaries of stored sessions, most recently updated
  /// first. Pass [ownerUid] to scope the list to sessions owned by that
  /// user, or leave it null to list only unowned ("guest") sessions —
  /// callers never get another user's sessions this way.
  Future<List<InspectionSessionSummary>> listSessions({String? ownerUid});

  /// Assigns an owner to a previously-unowned ("guest") session — used
  /// when a guest session is claimed by a newly signed-in user. Never
  /// reassigns a session that already has a different owner.
  Future<void> setSessionOwner(String sessionId, String ownerUid);

  /// Replaces a session's configured sections (include/exclude, renames,
  /// custom additions/removals).
  Future<void> saveSections(String sessionId, List<Section> sections);

  /// Records physical-inspection progress for one section.
  Future<void> saveSectionStatus(
    String sessionId,
    String sectionId,
    SectionStatus status,
  );

  /// Creates or updates a finding (upsert, keyed by [Finding.id]).
  Future<void> saveFinding(String sessionId, Finding finding);

  Future<void> deleteFinding(String sessionId, String findingId);

  /// Attaches evidence metadata to a finding. The file itself must
  /// already exist at [Evidence.filePath] in app-managed storage.
  Future<void> addEvidence(String sessionId, Evidence evidence);

  Future<void> removeEvidence(String sessionId, String evidenceId);

  /// Records the outcome of a cloud upload for one piece of evidence.
  Future<void> updateEvidenceSyncState(
    String evidenceId, {
    required SyncStatus syncStatus,
    String? storagePath,
  });

  Future<void> setSessionStatus(String sessionId, InspectionStatus status);

  /// Records the session's cloud sync state (informational — the local
  /// row remains the durable source of truth regardless of this value).
  Future<void> setSessionSyncStatus(String sessionId, SyncStatus syncStatus);

  /// Records the state of the whole-session AI analysis run.
  Future<void> setAiReviewState(String sessionId, AiReviewState state);

  /// Creates or updates an AI suggestion (upsert, keyed by
  /// [AiSuggestion.id]) — used both to persist freshly-generated
  /// suggestions and to record the inspector's review of one.
  Future<void> saveAiSuggestion(AiSuggestion suggestion);

  Future<void> close();
}
