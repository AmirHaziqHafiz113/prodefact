import 'package:prodefact/core/inspection/inspection_domain.dart';

/// In-memory [CloudInspectionRepository] fake — no Firebase involved.
/// Records every push so tests can assert on stable ids, idempotency
/// (repeated pushes overwrite rather than duplicate), and can be told to
/// throw on the next call to simulate a failed sync.
class FakeCloudInspectionRepository implements CloudInspectionRepository {
  final Map<String, InspectionSession> pushedSessions = {};
  final Map<String, List<Section>> pushedSections = {};
  final Map<String, Finding> pushedFindings = {};
  final Map<String, Evidence> pushedEvidenceMetadata = {};
  final Map<String, String> uploadedFiles = {}; // evidenceId -> storagePath
  final List<String> deletedFindingIds = [];
  final List<String> deletedEvidenceIds = [];
  final Map<String, AiSuggestion> pushedAiSuggestions = {};

  int pushAiSuggestionCalls = 0;

  int pushSessionCalls = 0;
  int pushSectionsCalls = 0;
  int pushFindingCalls = 0;
  int uploadEvidenceCalls = 0;

  /// When set, the next call to any method throws this instead of
  /// succeeding — simulating a network/Firebase failure.
  Object? failNextCallWith;

  void _maybeThrow() {
    final failure = failNextCallWith;
    if (failure != null) {
      failNextCallWith = null;
      throw failure;
    }
  }

  @override
  Future<void> pushSession(String ownerUid, InspectionSession session) async {
    _maybeThrow();
    pushSessionCalls++;
    pushedSessions[session.id] = session;
  }

  @override
  Future<void> pushSections(
    String ownerUid,
    String sessionId,
    List<Section> sections,
  ) async {
    _maybeThrow();
    pushSectionsCalls++;
    pushedSections[sessionId] = sections;
  }

  @override
  Future<void> pushFinding(
    String ownerUid,
    String sessionId,
    Finding finding,
  ) async {
    _maybeThrow();
    pushFindingCalls++;
    pushedFindings[finding.id] = finding;
  }

  @override
  Future<void> deleteFinding(
    String ownerUid,
    String sessionId,
    String findingId,
  ) async {
    _maybeThrow();
    pushedFindings.remove(findingId);
    deletedFindingIds.add(findingId);
  }

  @override
  Future<String> uploadEvidenceFile(
    String ownerUid,
    String sessionId,
    Evidence evidence,
  ) async {
    _maybeThrow();
    uploadEvidenceCalls++;
    final path =
        'users/$ownerUid/inspections/$sessionId/findings/'
        '${evidence.findingId}/${evidence.id}.jpg';
    uploadedFiles[evidence.id] = path;
    return path;
  }

  @override
  Future<void> pushEvidenceMetadata(
    String ownerUid,
    String sessionId,
    Evidence evidence,
  ) async {
    _maybeThrow();
    pushedEvidenceMetadata[evidence.id] = evidence;
  }

  @override
  Future<void> deleteEvidence(
    String ownerUid,
    String sessionId,
    String findingId,
    String evidenceId,
  ) async {
    _maybeThrow();
    pushedEvidenceMetadata.remove(evidenceId);
    deletedEvidenceIds.add(evidenceId);
  }

  @override
  Future<void> pushAiSuggestion(
    String ownerUid,
    String sessionId,
    AiSuggestion suggestion,
  ) async {
    _maybeThrow();
    pushAiSuggestionCalls++;
    pushedAiSuggestions[suggestion.id] = suggestion;
  }
}
