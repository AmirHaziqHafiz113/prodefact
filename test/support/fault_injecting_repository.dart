import 'package:prodefact/core/inspection/inspection_domain.dart';

/// Wraps a real [InspectionRepository] and can be told to throw on the
/// *next* call to one specific method — used to simulate a durable-write
/// failure (disk full, permission error, etc.) without needing to
/// actually break the filesystem. Every other method passes straight
/// through to [_inner] unchanged.
class FaultInjectingRepository implements InspectionRepository {
  FaultInjectingRepository(this._inner);

  final InspectionRepository _inner;

  /// Method name (e.g. `'saveFinding'`) to fail on its next call. Reset
  /// to null automatically after it fires once.
  String? failNextCallTo;

  void _maybeFail(String methodName) {
    if (failNextCallTo == methodName) {
      failNextCallTo = null;
      throw Exception('simulated failure in $methodName');
    }
  }

  @override
  Future<InspectionSession> createSession({
    required Industry industry,
    required String assetTypeId,
    required List<Section> initialSections,
    String? ownerUid,
    PropertyDetails propertyDetails = PropertyDetails.empty,
    CommercialMode? commercialMode,
    AiLevel? selectedAiLevel,
  }) {
    _maybeFail('createSession');
    return _inner.createSession(
      industry: industry,
      assetTypeId: assetTypeId,
      initialSections: initialSections,
      ownerUid: ownerUid,
      propertyDetails: propertyDetails,
      commercialMode: commercialMode,
      selectedAiLevel: selectedAiLevel,
    );
  }

  @override
  Future<InspectionSession?> loadSession(String id) {
    _maybeFail('loadSession');
    return _inner.loadSession(id);
  }

  @override
  Future<List<InspectionSessionSummary>> listSessions({String? ownerUid}) {
    _maybeFail('listSessions');
    return _inner.listSessions(ownerUid: ownerUid);
  }

  @override
  Future<void> setSessionOwner(String sessionId, String ownerUid) {
    _maybeFail('setSessionOwner');
    return _inner.setSessionOwner(sessionId, ownerUid);
  }

  @override
  Future<void> saveSections(String sessionId, List<Section> sections) {
    _maybeFail('saveSections');
    return _inner.saveSections(sessionId, sections);
  }

  @override
  Future<void> saveSectionStatus(
    String sessionId,
    String sectionId,
    SectionStatus status,
  ) {
    _maybeFail('saveSectionStatus');
    return _inner.saveSectionStatus(sessionId, sectionId, status);
  }

  @override
  Future<void> saveFinding(String sessionId, Finding finding) {
    _maybeFail('saveFinding');
    return _inner.saveFinding(sessionId, finding);
  }

  @override
  Future<void> deleteFinding(String sessionId, String findingId) {
    _maybeFail('deleteFinding');
    return _inner.deleteFinding(sessionId, findingId);
  }

  @override
  Future<void> setFindingAiStatus(
    String sessionId,
    String findingId,
    AiFindingStatus status,
  ) {
    _maybeFail('setFindingAiStatus');
    return _inner.setFindingAiStatus(sessionId, findingId, status);
  }

  @override
  Future<void> deleteSession(String sessionId) {
    _maybeFail('deleteSession');
    return _inner.deleteSession(sessionId);
  }

  @override
  Future<void> addEvidence(String sessionId, Evidence evidence) {
    _maybeFail('addEvidence');
    return _inner.addEvidence(sessionId, evidence);
  }

  @override
  Future<void> removeEvidence(String sessionId, String evidenceId) {
    _maybeFail('removeEvidence');
    return _inner.removeEvidence(sessionId, evidenceId);
  }

  @override
  Future<void> updateEvidenceSyncState(
    String evidenceId, {
    required SyncStatus syncStatus,
    String? storagePath,
  }) {
    _maybeFail('updateEvidenceSyncState');
    return _inner.updateEvidenceSyncState(
      evidenceId,
      syncStatus: syncStatus,
      storagePath: storagePath,
    );
  }

  @override
  Future<void> setSessionStatus(String sessionId, InspectionStatus status) {
    _maybeFail('setSessionStatus');
    return _inner.setSessionStatus(sessionId, status);
  }

  @override
  Future<void> setSessionSyncStatus(String sessionId, SyncStatus syncStatus) {
    _maybeFail('setSessionSyncStatus');
    return _inner.setSessionSyncStatus(sessionId, syncStatus);
  }

  @override
  Future<void> setAiReviewState(String sessionId, AiReviewState state) {
    _maybeFail('setAiReviewState');
    return _inner.setAiReviewState(sessionId, state);
  }

  @override
  Future<void> saveAiSuggestion(AiSuggestion suggestion) {
    _maybeFail('saveAiSuggestion');
    return _inner.saveAiSuggestion(suggestion);
  }

  @override
  Future<void> saveReport(Report report) {
    _maybeFail('saveReport');
    return _inner.saveReport(report);
  }

  @override
  Future<UserProfile> loadUserProfile() {
    _maybeFail('loadUserProfile');
    return _inner.loadUserProfile();
  }

  @override
  Future<void> saveUserProfile(UserProfile profile) {
    _maybeFail('saveUserProfile');
    return _inner.saveUserProfile(profile);
  }

  @override
  Future<void> saveReportMetadata(String sessionId, ReportMetadata metadata) {
    _maybeFail('saveReportMetadata');
    return _inner.saveReportMetadata(sessionId, metadata);
  }

  @override
  Future<void> saveInspectionNote(String sessionId, String? note) {
    _maybeFail('saveInspectionNote');
    return _inner.saveInspectionNote(sessionId, note);
  }

  @override
  Future<void> setAutoAnalyseEnabled(String sessionId, bool enabled) {
    _maybeFail('setAutoAnalyseEnabled');
    return _inner.setAutoAnalyseEnabled(sessionId, enabled);
  }

  @override
  Future<void> setCommercialMode(String sessionId, CommercialMode mode) {
    _maybeFail('setCommercialMode');
    return _inner.setCommercialMode(sessionId, mode);
  }

  @override
  Future<WalletCache?> loadWalletCache() {
    _maybeFail('loadWalletCache');
    return _inner.loadWalletCache();
  }

  @override
  Future<void> saveWalletCache(WalletCache cache) {
    _maybeFail('saveWalletCache');
    return _inner.saveWalletCache(cache);
  }

  @override
  Future<void> close() => _inner.close();
}
