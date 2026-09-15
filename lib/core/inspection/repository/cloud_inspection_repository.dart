import '../entities/ai_review.dart';
import '../entities/evidence.dart';
import '../entities/finding.dart';
import '../entities/inspection_session.dart';
import '../entities/report.dart';
import '../entities/section.dart';

/// Remote mirror of a user's inspections, generic across industries.
///
/// Every method is scoped to [ownerUid] — implementations must never
/// read or write another user's data. This interface never leaks
/// Firebase SDK types; a Firestore/Storage implementation lives in the
/// data layer.
abstract class CloudInspectionRepository {
  /// Creates or overwrites the session document itself (not its
  /// sections/findings/evidence — see the other methods). Keyed by
  /// [InspectionSession.id], so calling this again for the same session
  /// updates the existing remote record rather than duplicating it.
  Future<void> pushSession(String ownerUid, InspectionSession session);

  /// Replaces the session's section documents wholesale, mirroring how
  /// the local repository treats configured areas as a replaced-in-full
  /// list rather than incrementally diffed rows.
  Future<void> pushSections(
    String ownerUid,
    String sessionId,
    List<Section> sections,
  );

  /// Creates or updates one finding document, keyed by [Finding.id].
  Future<void> pushFinding(String ownerUid, String sessionId, Finding finding);

  Future<void> deleteFinding(
    String ownerUid,
    String sessionId,
    String findingId,
  );

  /// Uploads the evidence file at [Evidence.filePath] to cloud storage
  /// and returns the storage path it was written to. Does not touch
  /// Firestore — call [pushEvidenceMetadata] after a successful upload.
  Future<String> uploadEvidenceFile(
    String ownerUid,
    String sessionId,
    Evidence evidence,
  );

  /// Creates or updates the evidence metadata document, keyed by
  /// [Evidence.id].
  Future<void> pushEvidenceMetadata(
    String ownerUid,
    String sessionId,
    Evidence evidence,
  );

  Future<void> deleteEvidence(
    String ownerUid,
    String sessionId,
    String findingId,
    String evidenceId,
  );

  /// Creates or updates one AI suggestion document, keyed by
  /// [AiSuggestion.id] — including whatever the inspector has reviewed
  /// so far, so the cloud record always mirrors local review state once
  /// synced.
  Future<void> pushAiSuggestion(
    String ownerUid,
    String sessionId,
    AiSuggestion suggestion,
  );

  /// Mirrors report *metadata* (id, filename, timestamps) — never the
  /// PDF bytes themselves; uploading the actual file to cloud storage is
  /// optional and out of scope for now (see `docs/report.md`).
  Future<void> pushReportMetadata(
    String ownerUid,
    String sessionId,
    Report report,
  );
}
