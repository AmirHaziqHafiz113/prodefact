import '../entities/ai_analysis_attempt.dart';
import '../entities/ai_finding_status.dart';
import '../entities/ai_level.dart';
import '../entities/ai_review.dart';
import '../entities/ai_review_state.dart';
import '../entities/commercial_mode.dart';
import '../entities/evidence.dart';
import '../entities/finding.dart';
import '../entities/industry.dart';
import '../entities/inspection.dart';
import '../entities/inspection_session.dart';
import '../entities/property_details.dart';
import '../entities/report.dart';
import '../entities/report_metadata.dart';
import '../entities/section.dart';
import '../entities/section_status.dart';
import '../entities/sync_status.dart';
import '../entities/user_profile.dart';
import '../entities/wallet_cache.dart';

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
  ///
  /// [commercialMode]/[selectedAiLevel] are the outcome of the Choose AI
  /// Plan step (see docs/commercial_model.md) — null means that choice
  /// hasn't happened yet (e.g. a caller that predates this feature).
  Future<InspectionSession> createSession({
    required Industry industry,
    required String assetTypeId,
    required List<Section> initialSections,
    String? ownerUid,
    PropertyDetails propertyDetails = PropertyDetails.empty,
    CommercialMode? commercialMode,
    AiLevel? selectedAiLevel,
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

  /// Records the per-finding progressive AI processing state — see
  /// `AiFindingStatus`.
  Future<void> setFindingAiStatus(
    String sessionId,
    String findingId,
    AiFindingStatus status,
  );

  /// Durably records [attempt] as this finding's outstanding AI
  /// analysis request and moves it to `analyzing`, in one write. Must
  /// complete *before* the analysis request is sent, so an app restart
  /// can always replay the same idempotency key — see
  /// `AiAnalysisAttempt`.
  Future<void> beginFindingAiAttempt(
    String sessionId,
    String findingId,
    AiAnalysisAttempt attempt,
  );

  /// Records a *definitive* AI outcome: sets [status] and clears the
  /// outstanding attempt, so the next approved run mints a fresh key.
  /// Use [setFindingAiStatus] instead when the outcome is unknown and
  /// the attempt must be kept for a safe replay.
  Future<void> finishFindingAiAttempt(
    String sessionId,
    String findingId,
    AiFindingStatus status,
  );

  /// Permanently deletes a session and everything that references it
  /// (sections, findings, evidence metadata, AI suggestions, report
  /// metadata) via cascading foreign keys. Does not touch any file on
  /// disk — callers are responsible for deleting the evidence/report
  /// files a session referenced *before* calling this, using the file
  /// paths from a freshly [loadSession]ed copy (see
  /// `docs/production_readiness.md`, "Session deletion").
  ///
  /// A no-op (not an error) if [sessionId] doesn't exist.
  Future<void> deleteSession(String sessionId);

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

  /// Replaces the session's report metadata (upsert, keyed by
  /// [Report.sessionId] — "latest report per inspection"; see
  /// `docs/report.md`).
  Future<void> saveReport(Report report);

  /// The single on-device inspector profile — see `UserProfile`.
  /// `UserProfile.empty` if nothing has been saved yet.
  Future<UserProfile> loadUserProfile();

  Future<void> saveUserProfile(UserProfile profile);

  /// Records the inspector-confirmed report cover-page metadata (the
  /// Report Details step) — see `ReportMetadata`'s doc comment for why
  /// this never touches the session's own `PropertyDetails`.
  Future<void> saveReportMetadata(String sessionId, ReportMetadata metadata);

  /// Records the whole-inspection contextual note. Pass null to clear
  /// it.
  Future<void> saveInspectionNote(String sessionId, String? note);

  /// Records the Auto Analyse preference for one inspection — see
  /// `InspectionSession.autoAnalyseEnabled`, docs/commercial_model.md.
  Future<void> setAutoAnalyseEnabled(String sessionId, bool enabled);

  /// Records the inspector's post-setup commercial choice for one
  /// inspection — House Pass purchase is no longer offered during New
  /// Inspection setup (see the QA/QC simplification pass), so this is
  /// how an inspection that starts with `commercialMode` unset (Flex
  /// Credits by default) can still switch to House Pass once the
  /// inspector actually opts in via `HousePassScreen`.
  Future<void> setCommercialMode(String sessionId, CommercialMode mode);

  /// The last-known Credits balance cached locally for instant/offline
  /// display — null if nothing has been cached yet. **Never
  /// authoritative** — see `WalletCache`'s doc comment.
  Future<WalletCache?> loadWalletCache();

  Future<void> saveWalletCache(WalletCache cache);

  Future<void> close();
}
