import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../data/ai/ai_providers.dart';
import '../../../data/local/database_providers.dart';
import '../../../data/remote/remote_providers.dart';
import '../../../data/report/report_providers.dart';
import '../config/home_inspection_config.dart';
import '../config/property_type.dart';
import 'session_list_providers.dart';

String? _orNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// The final/reviewed values an inspector approves for one suggestion.
typedef _ReviewedFields = ({
  String? elementId,
  String? componentId,
  String? defectType,
  String? recommendation,
  String? notes,
});

/// The single active inspection session, held fully in memory and
/// written through to [InspectionRepository] on every change.
///
/// The local database is the durable source of truth; this notifier is
/// a synchronized in-memory mirror of it so the UI can read/update
/// state synchronously without waiting on disk I/O for every rebuild.
/// Persistence happens as an un-awaited write-through after each
/// in-memory update, which is why normal inspection work never blocks
/// on storage — offline or otherwise.
///
/// Null until a session is started ([startNew]) or resumed ([resume]).
class ActiveInspectionSession extends Notifier<InspectionSession?> {
  @override
  InspectionSession? build() => null;

  InspectionRepository get _repository =>
      ref.read(inspectionRepositoryProvider);

  Future<void> startNew(PropertyType propertyType) async {
    final sections = HomeInspectionConfig.defaultSectionsFor(propertyType);
    final session = await _repository.createSession(
      industry: Industry.homeInspection,
      assetTypeId: propertyType.name,
      initialSections: sections,
      ownerUid: ref.read(authServiceProvider).currentUser?.uid,
    );
    state = session;
    ref.invalidate(sessionSummariesProvider);
  }

  /// Loads a session for the resume screen. If it's an unclaimed
  /// "guest" session and the inspector is now signed in, it becomes
  /// owned by that user from this point on — see the ownership policy
  /// in `docs/firebase.md`.
  Future<void> resume(String sessionId) async {
    final uid = ref.read(authServiceProvider).currentUser?.uid;
    var session = await _repository.loadSession(sessionId);
    if (session != null && session.ownerUid == null && uid != null) {
      await _repository.setSessionOwner(sessionId, uid);
      session = await _repository.loadSession(sessionId);
    }
    state = session;
  }

  void clear() => state = null;

  // ---- area configuration (Phase 2) ----

  void resetAreasToDefaults() {
    final session = state;
    if (session == null) return;
    final propertyType = PropertyType.values.firstWhereOrNull(
      (p) => p.name == session.assetTypeId,
    );
    if (propertyType == null) return;
    _updateSections(HomeInspectionConfig.defaultSectionsFor(propertyType));
  }

  void toggleAreaIncluded(String sectionId) {
    final session = state;
    if (session == null) return;
    _updateSections([
      for (final section in session.sections)
        if (section.id == sectionId)
          section.copyWith(isIncluded: !section.isIncluded)
        else
          section,
    ]);
  }

  void renameArea(String sectionId, String newName) {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;
    final session = state;
    if (session == null) return;
    _updateSections([
      for (final section in session.sections)
        if (section.id == sectionId)
          section.copyWith(name: trimmed)
        else
          section,
    ]);
  }

  void removeArea(String sectionId) {
    final session = state;
    if (session == null) return;
    _updateSections(
      session.sections.where((section) => section.id != sectionId).toList(),
    );
  }

  void addCustomArea(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final session = state;
    if (session == null) return;
    _updateSections([
      ...session.sections,
      HomeInspectionConfig.customSection(trimmed),
    ]);
  }

  void _updateSections(List<Section> sections) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(sections: sections, updatedAt: DateTime.now());
    unawaited(_repository.saveSections(session.id, sections));
    ref.invalidate(sessionSummariesProvider);
  }

  // ---- physical inspection progress (Phase 3) ----

  void setSectionStatus(String sectionId, SectionStatus status) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      sectionStatuses: {...session.sectionStatuses, sectionId: status},
      updatedAt: DateTime.now(),
    );
    unawaited(_repository.saveSectionStatus(session.id, sectionId, status));
    ref.invalidate(sessionSummariesProvider);
  }

  Finding addFinding({
    required String sectionId,
    required String elementId,
    String? componentId,
    String? description,
    String? notes,
  }) {
    final session = state;
    if (session == null) {
      throw StateError('Cannot add a finding without an active session');
    }
    final now = DateTime.now();
    final finding = Finding(
      id: 'finding_${now.microsecondsSinceEpoch}',
      sectionId: sectionId,
      elementId: elementId,
      componentId: componentId,
      description: _orNull(description),
      notes: _orNull(notes),
      createdAt: now,
      updatedAt: now,
    );
    state = session.copyWith(
      findings: [...session.findings, finding],
      updatedAt: now,
    );
    unawaited(_repository.saveFinding(session.id, finding));
    ref.invalidate(sessionSummariesProvider);
    return finding;
  }

  void updateFinding({
    required String findingId,
    required String? description,
    required String? notes,
  }) {
    final session = state;
    if (session == null) return;
    final now = DateTime.now();
    Finding? updatedFinding;
    final findings = [
      for (final finding in session.findings)
        if (finding.id == findingId)
          (updatedFinding = finding.copyWith(
            description: _orNull(description) ?? '',
            notes: _orNull(notes) ?? '',
            updatedAt: now,
          ))
        else
          finding,
    ];
    final finding = updatedFinding;
    if (finding == null) return;
    state = session.copyWith(findings: findings, updatedAt: now);
    unawaited(_repository.saveFinding(session.id, finding));
    ref.invalidate(sessionSummariesProvider);
  }

  void removeFinding(String findingId) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      findings: session.findings
          .where((finding) => finding.id != findingId)
          .toList(),
      updatedAt: DateTime.now(),
    );
    unawaited(_repository.deleteFinding(session.id, findingId));
    ref.invalidate(sessionSummariesProvider);
  }

  Future<void> markPhysicalInspectionComplete() async {
    final session = state;
    if (session == null) return;
    final now = DateTime.now();
    state = session.copyWith(
      status: InspectionStatus.physicalInspectionComplete,
      updatedAt: now,
    );
    await _repository.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    ref.invalidate(sessionSummariesProvider);
  }

  // ---- evidence (Phase 4) ----

  Future<void> addEvidence({
    required String findingId,
    required EvidenceSource source,
  }) async {
    final session = state;
    if (session == null) return;

    final captureService = ref.read(evidenceCaptureServiceProvider);
    final captured = await captureService.captureImage(
      findingId: findingId,
      source: source,
    );
    if (captured == null) return; // user cancelled the picker

    final now = DateTime.now();
    final evidence = Evidence(
      id: 'evidence_${now.microsecondsSinceEpoch}',
      findingId: findingId,
      filePath: captured.filePath,
      createdAt: now,
      source: captured.source,
    );

    final findings = [
      for (final finding in session.findings)
        if (finding.id == findingId)
          finding.copyWith(
            evidence: [...finding.evidence, evidence],
            updatedAt: now,
          )
        else
          finding,
    ];
    state = session.copyWith(findings: findings, updatedAt: now);
    unawaited(_repository.addEvidence(session.id, evidence));
  }

  void removeEvidence({required String findingId, required String evidenceId}) {
    final session = state;
    if (session == null) return;
    final now = DateTime.now();
    final findings = [
      for (final finding in session.findings)
        if (finding.id == findingId)
          finding.copyWith(
            evidence: finding.evidence
                .where((e) => e.id != evidenceId)
                .toList(),
            updatedAt: now,
          )
        else
          finding,
    ];
    state = session.copyWith(findings: findings, updatedAt: now);
    unawaited(_repository.removeEvidence(session.id, evidenceId));
  }

  // ---- cloud sync (Phase 5) ----

  /// Pushes the active session to the cloud and refreshes in-memory
  /// state (sync status, claimed ownership, per-evidence storage paths)
  /// from whatever the coordinator actually persisted locally.
  Future<SyncResult> syncNow() async {
    final session = state;
    if (session == null) return const SyncResult.sessionNotFound();

    final result = await ref
        .read(syncCoordinatorProvider)
        .syncSession(session.id);
    state = await _repository.loadSession(session.id);
    ref.invalidate(sessionSummariesProvider);
    return result;
  }

  // ---- AI review (Phase 6) ----

  /// Runs AI analysis for the active session, refusing to do anything
  /// (via [AiReviewCoordinator]'s gate) unless physical inspection is
  /// already complete. Refreshes in-memory state either way so the UI
  /// reflects the resulting `aiReviewState` and any new suggestions.
  Future<AiAnalysisResult> startAiAnalysis() async {
    final session = state;
    if (session == null) return const AiAnalysisResult.sessionNotFound();

    final result = await ref
        .read(aiReviewCoordinatorProvider)
        .runAnalysis(session.id);
    state = await _repository.loadSession(session.id);
    ref.invalidate(sessionSummariesProvider);
    return result;
  }

  void acceptSuggestion(String suggestionId) {
    _reviewSuggestion(
      suggestionId,
      status: AiSuggestionStatus.accepted,
      buildFinal: (suggestion) => (
        elementId: suggestion.suggestedElementId,
        componentId: suggestion.suggestedComponentId,
        defectType: suggestion.suggestedDefectType,
        recommendation: suggestion.suggestedRecommendation,
        notes: suggestion.suggestedNotes,
      ),
    );
  }

  /// Inspector-modified values replace the AI's own suggestion in the
  /// `final*` fields; the original `suggested*` values are untouched.
  void editSuggestion(
    String suggestionId, {
    required String? elementId,
    required String? componentId,
    required String? defectType,
    required String? recommendation,
    required String? notes,
  }) {
    _reviewSuggestion(
      suggestionId,
      status: AiSuggestionStatus.edited,
      buildFinal: (_) => (
        elementId: elementId,
        componentId: componentId,
        defectType: defectType,
        recommendation: recommendation,
        notes: notes,
      ),
    );
  }

  /// The inspector disagrees with the AI entirely but still records
  /// their own assessment, rather than the finding being left with no
  /// resolution at all.
  void rejectSuggestion(
    String suggestionId, {
    required String? elementId,
    required String? componentId,
    required String? defectType,
    required String? recommendation,
    required String? notes,
  }) {
    _reviewSuggestion(
      suggestionId,
      status: AiSuggestionStatus.rejected,
      buildFinal: (_) => (
        elementId: elementId,
        componentId: componentId,
        defectType: defectType,
        recommendation: recommendation,
        notes: notes,
      ),
    );
  }

  void _reviewSuggestion(
    String suggestionId, {
    required AiSuggestionStatus status,
    required _ReviewedFields Function(AiSuggestion suggestion) buildFinal,
  }) {
    final session = state;
    if (session == null) return;
    final now = DateTime.now();

    AiSuggestion? updated;
    final suggestions = [
      for (final suggestion in session.aiSuggestions)
        if (suggestion.id == suggestionId)
          (updated = _applyReview(suggestion, status, now, buildFinal))
        else
          suggestion,
    ];
    final finalUpdated = updated;
    if (finalUpdated == null) return;

    final allResolved = suggestions.every((s) => s.isResolved);
    state = session.copyWith(
      aiSuggestions: suggestions,
      updatedAt: now,
      aiReviewState: allResolved
          ? AiReviewState.completed
          : session.aiReviewState,
      status: allResolved ? InspectionStatus.aiReviewComplete : session.status,
    );
    unawaited(_repository.saveAiSuggestion(finalUpdated));
    if (allResolved) {
      unawaited(
        _repository.setAiReviewState(session.id, AiReviewState.completed),
      );
      unawaited(
        _repository.setSessionStatus(
          session.id,
          InspectionStatus.aiReviewComplete,
        ),
      );
    }
    ref.invalidate(sessionSummariesProvider);
  }

  AiSuggestion _applyReview(
    AiSuggestion suggestion,
    AiSuggestionStatus status,
    DateTime reviewedAt,
    _ReviewedFields Function(AiSuggestion suggestion) buildFinal,
  ) {
    final finalValues = buildFinal(suggestion);
    return suggestion.copyWith(
      status: status,
      reviewedAt: reviewedAt,
      finalElementId: finalValues.elementId ?? '',
      finalComponentId: finalValues.componentId ?? '',
      finalDefectType: finalValues.defectType ?? '',
      finalRecommendation: finalValues.recommendation ?? '',
      finalNotes: finalValues.notes ?? '',
    );
  }

  // ---- report generation (Phase 7) ----

  /// Generates (or regenerates) the PDF report for the active session,
  /// refusing to do anything (via [ReportCoordinator]'s gate) unless
  /// physical inspection *and* AI review are both complete. Refreshes
  /// in-memory state either way so the UI reflects the resulting
  /// report metadata.
  Future<ReportGenerationResult> generateReport() async {
    final session = state;
    if (session == null) return const ReportGenerationResult.sessionNotFound();

    final propertyType = PropertyType.values.firstWhereOrNull(
      (p) => p.name == session.assetTypeId,
    );
    final result = await ref
        .read(reportCoordinatorProvider)
        .generateReport(
          session.id,
          propertyTypeLabel: propertyType?.label ?? session.assetTypeId,
        );
    state = await _repository.loadSession(session.id);
    ref.invalidate(sessionSummariesProvider);
    return result;
  }

  Future<void> shareReport() async {
    final report = state?.report;
    if (report == null) return;
    await ref
        .read(reportShareServiceProvider)
        .shareReport(filePath: report.filePath, fileName: report.fileName);
  }
}

final activeSessionProvider =
    NotifierProvider<ActiveInspectionSession, InspectionSession?>(
      ActiveInspectionSession.new,
    );
