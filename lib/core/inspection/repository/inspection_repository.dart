import '../entities/evidence.dart';
import '../entities/finding.dart';
import '../entities/industry.dart';
import '../entities/inspection.dart';
import '../entities/inspection_session.dart';
import '../entities/section.dart';
import '../entities/section_status.dart';

/// Durable storage for [InspectionSession]s, generic across industries.
///
/// UI and Riverpod providers never touch the underlying database
/// directly — they depend on this interface, which a local (Drift)
/// implementation satisfies today and a future remote-sync layer can
/// wrap or replace without changing callers.
abstract class InspectionRepository {
  /// Creates and persists a new session with a stable, freshly-generated
  /// id and the given starting sections.
  Future<InspectionSession> createSession({
    required Industry industry,
    required String assetTypeId,
    required List<Section> initialSections,
  });

  /// Loads a previously-created session by id, or null if it doesn't
  /// exist (e.g. it was never created, or storage was cleared).
  Future<InspectionSession?> loadSession(String id);

  /// Lightweight summaries of every stored session, most recently
  /// updated first — enough to power a resume/list screen.
  Future<List<InspectionSessionSummary>> listSessions();

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

  Future<void> setSessionStatus(String sessionId, InspectionStatus status);

  Future<void> close();
}
