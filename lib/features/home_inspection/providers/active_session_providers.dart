import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../core/logging/app_logger.dart';
import '../../../data/ai/ai_providers.dart';
import '../../../data/analytics/analytics_providers.dart';
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

/// Holds the most recent local-write failure message for the active
/// session, if any — a durable-write "surfaced failure" companion to
/// [activeSessionProvider]. UI can watch this to show a banner/snackbar
/// without every screen re-implementing its own error plumbing. Cleared
/// automatically the next time any write succeeds.
class ActiveSessionError extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String message) => state = message;

  void clear() => state = null;
}

final activeSessionErrorProvider =
    NotifierProvider<ActiveSessionError, String?>(ActiveSessionError.new);

/// The single active inspection session, held fully in memory and
/// written through to [InspectionRepository] on every change.
///
/// The local database is the durable source of truth; this notifier is
/// a synchronized in-memory mirror of it so the UI can read/update
/// state synchronously without waiting on disk I/O for every rebuild.
/// Persistence happens as an un-awaited write-through after each
/// in-memory update, which is why normal inspection work never blocks
/// on storage — offline or otherwise. If a write-through actually fails
/// (disk full, permission error, etc.), [_persist] rolls the in-memory
/// state back to what was durably saved and reports the failure via
/// [activeSessionErrorProvider] — the UI can never be left believing a
/// change was saved when it wasn't. See `docs/production_readiness.md`
/// ("Durable write safety").
///
/// Null until a session is started ([startNew]) or resumed ([resume]).
class ActiveInspectionSession extends Notifier<InspectionSession?> {
  @override
  InspectionSession? build() => null;

  InspectionRepository get _repository =>
      ref.read(inspectionRepositoryProvider);

  bool _isSyncing = false;
  bool _isAnalyzing = false;
  bool _isGeneratingReport = false;

  /// Runs [write] (the durable persistence for a mutation already
  /// applied optimistically to [state]). If it throws, [state] is rolled
  /// back to [previous] — the last state known to match the database —
  /// and the failure is surfaced via [activeSessionErrorProvider] rather
  /// than left silent. On success, any previously-surfaced error is
  /// cleared.
  Future<void> _persist(
    Future<void> Function() write, {
    required InspectionSession previous,
    required String action,
  }) async {
    // The value the caller optimistically assigned to `state` right
    // before calling this — captured now so a failure can tell whether
    // anything *else* has changed `state` since (a later, unrelated
    // edit made while this write was still in flight), in which case
    // rolling back to `previous` would incorrectly discard it.
    final optimistic = state;
    try {
      await write();
      // The notifier (and its `ref`) may have been disposed while this
      // write was in flight — e.g. the screen was popped, or (in tests)
      // the container was torn down. There's nothing left to update at
      // that point, and touching a disposed `ref` throws.
      if (!ref.mounted) return;
      ref.read(activeSessionErrorProvider.notifier).clear();
    } catch (error, stackTrace) {
      if (!ref.mounted) return;
      AppLogger.error('Failed to save: $action', error, stackTrace);
      if (identical(state, optimistic)) {
        state = previous;
      }
      ref
          .read(activeSessionErrorProvider.notifier)
          .set('Could not save your change ($action). Please try again.');
    }
  }

  /// Logs a coarse product-usage milestone, swallowing any failure —
  /// including a failure to even construct the analytics service (e.g.
  /// Firebase not initialized in a plain Dart test, or Analytics
  /// unreachable). Analytics is always best-effort and must never affect
  /// the outcome of the workflow step it's attached to.
  void _logAnalytics(AnalyticsEvent event) {
    try {
      unawaited(ref.read(analyticsServiceProvider).logEvent(event));
    } catch (error) {
      AppLogger.warning('Could not log an analytics event', error);
    }
  }

  Future<bool> startNew(PropertyType propertyType) async {
    final sections = HomeInspectionConfig.defaultSectionsFor(propertyType);
    try {
      final session = await _repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: propertyType.name,
        initialSections: sections,
        ownerUid: ref.read(authServiceProvider).currentUser?.uid,
      );
      state = session;
      ref.read(activeSessionErrorProvider.notifier).clear();
      ref.invalidate(sessionSummariesProvider);
      _logAnalytics(AnalyticsEvent.inspectionStarted);
      return true;
    } catch (error, stackTrace) {
      AppLogger.error('Failed to start a new inspection', error, stackTrace);
      ref
          .read(activeSessionErrorProvider.notifier)
          .set('Could not start a new inspection. Please try again.');
      return false;
    }
  }

  /// Loads a session for the resume screen. If it's an unclaimed
  /// "guest" session and the inspector is now signed in, it becomes
  /// owned by that user from this point on — see the ownership policy
  /// in `docs/firebase.md`. Returns false (state left unchanged) if the
  /// session could not be loaded at all.
  Future<bool> resume(String sessionId) async {
    try {
      final uid = ref.read(authServiceProvider).currentUser?.uid;
      var session = await _repository.loadSession(sessionId);
      if (session != null && session.ownerUid == null && uid != null) {
        await _repository.setSessionOwner(sessionId, uid);
        session = await _repository.loadSession(sessionId);
      }
      if (session == null) {
        ref
            .read(activeSessionErrorProvider.notifier)
            .set('That inspection could not be found.');
        return false;
      }
      state = session;
      ref.read(activeSessionErrorProvider.notifier).clear();
      return true;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to resume inspection $sessionId',
        error,
        stackTrace,
      );
      ref
          .read(activeSessionErrorProvider.notifier)
          .set('Could not open that inspection. Please try again.');
      return false;
    }
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
    unawaited(
      _persist(
        () => _repository.saveSections(session.id, sections),
        previous: session,
        action: 'update areas',
      ),
    );
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
    unawaited(
      _persist(
        () => _repository.saveSectionStatus(session.id, sectionId, status),
        previous: session,
        action: 'update area status',
      ),
    );
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
    unawaited(
      _persist(
        () => _repository.saveFinding(session.id, finding),
        previous: session,
        action: 'save finding',
      ),
    );
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
    unawaited(
      _persist(
        () => _repository.saveFinding(session.id, finding),
        previous: session,
        action: 'save finding',
      ),
    );
    ref.invalidate(sessionSummariesProvider);
  }

  void removeFinding(String findingId) {
    final session = state;
    if (session == null) return;
    final removedFinding = session.findings.firstWhereOrNull(
      (finding) => finding.id == findingId,
    );
    state = session.copyWith(
      findings: session.findings
          .where((finding) => finding.id != findingId)
          .toList(),
      updatedAt: DateTime.now(),
    );
    unawaited(
      _persist(
        () => _repository.deleteFinding(session.id, findingId),
        previous: session,
        action: 'delete finding',
      ),
    );
    if (removedFinding != null) {
      final fileStore = ref.read(evidenceFileStoreProvider);
      for (final evidence in removedFinding.evidence) {
        unawaited(fileStore.deleteEvidenceFile(evidence.filePath));
      }
    }
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
    await _persist(
      () => _repository.setSessionStatus(
        session.id,
        InspectionStatus.physicalInspectionComplete,
      ),
      previous: session,
      action: 'complete physical inspection',
    );
    ref.invalidate(sessionSummariesProvider);
  }

  // ---- evidence (Phase 4) ----

  /// Captures/imports a photo and attaches it to a finding. Any capture
  /// failure (permission denied, picker/import error) or persistence
  /// failure is caught and surfaced via [activeSessionErrorProvider]
  /// instead of throwing out of a UI callback.
  Future<void> addEvidence({
    required String findingId,
    required EvidenceSource source,
  }) async {
    final session = state;
    if (session == null) return;

    final CapturedEvidence? captured;
    try {
      final captureService = ref.read(evidenceCaptureServiceProvider);
      captured = await captureService.captureImage(
        findingId: findingId,
        source: source,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Evidence capture failed', error, stackTrace);
      ref
          .read(activeSessionErrorProvider.notifier)
          .set(
            'Could not add that photo. Check camera/photo permissions and '
            'try again.',
          );
      return;
    }
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
    unawaited(
      _persist(
        () => _repository.addEvidence(session.id, evidence),
        previous: session,
        action: 'attach photo',
      ),
    );
  }

  void removeEvidence({required String findingId, required String evidenceId}) {
    final session = state;
    if (session == null) return;
    final now = DateTime.now();
    String? removedFilePath;
    final findings = [
      for (final finding in session.findings)
        if (finding.id == findingId)
          finding.copyWith(
            evidence: finding.evidence.where((e) {
              final keep = e.id != evidenceId;
              if (!keep) removedFilePath = e.filePath;
              return keep;
            }).toList(),
            updatedAt: now,
          )
        else
          finding,
    ];
    state = session.copyWith(findings: findings, updatedAt: now);
    unawaited(
      _persist(
        () => _repository.removeEvidence(session.id, evidenceId),
        previous: session,
        action: 'remove photo',
      ),
    );
    final filePath = removedFilePath;
    if (filePath != null) {
      unawaited(
        ref.read(evidenceFileStoreProvider).deleteEvidenceFile(filePath),
      );
    }
  }

  // ---- cloud sync (Phase 5) ----

  /// Pushes the active session to the cloud and refreshes in-memory
  /// state (sync status, claimed ownership, per-evidence storage paths)
  /// from whatever the coordinator actually persisted locally. A no-op
  /// (returns the same failure every time) while a previous sync for
  /// this notifier is still in flight, so a double-tap of "Sync now"
  /// can never race two pushes against each other.
  Future<SyncResult> syncNow() async {
    final session = state;
    if (session == null) return const SyncResult.sessionNotFound();
    if (_isSyncing) {
      return const SyncResult.failure('A sync is already running.');
    }

    _isSyncing = true;
    try {
      final result = await ref
          .read(syncCoordinatorProvider)
          .syncSession(session.id);
      state = await _repository.loadSession(session.id);
      ref.invalidate(sessionSummariesProvider);
      return result;
    } catch (error, stackTrace) {
      AppLogger.error('Sync failed unexpectedly', error, stackTrace);
      return SyncResult.failure(error.toString());
    } finally {
      _isSyncing = false;
    }
  }

  // ---- AI review (Phase 6) ----

  /// Runs AI analysis for the active session, refusing to do anything
  /// (via [AiReviewCoordinator]'s gate) unless physical inspection is
  /// already complete. Refreshes in-memory state either way so the UI
  /// reflects the resulting `aiReviewState` and any new suggestions. A
  /// no-op while a previous call for this notifier is still in flight —
  /// double-tapping "Start AI Analysis" can never trigger two concurrent
  /// analysis runs (which, without this guard, could each pass the
  /// coordinator's own gate check before either had persisted
  /// `analyzing`, and so both call the AI backend and duplicate
  /// suggestions).
  Future<AiAnalysisResult> startAiAnalysis() async {
    final session = state;
    if (session == null) return const AiAnalysisResult.sessionNotFound();
    if (_isAnalyzing) return const AiAnalysisResult.alreadyReviewed();

    _isAnalyzing = true;
    try {
      final result = await ref
          .read(aiReviewCoordinatorProvider)
          .runAnalysis(session.id);
      state = await _repository.loadSession(session.id);
      ref.invalidate(sessionSummariesProvider);
      if (result.outcome == AiAnalysisOutcome.success) {
        _logAnalytics(AnalyticsEvent.aiReviewStarted);
      }
      return result;
    } catch (error, stackTrace) {
      AppLogger.error('AI analysis failed unexpectedly', error, stackTrace);
      return AiAnalysisResult.failure(error.toString());
    } finally {
      _isAnalyzing = false;
    }
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
    unawaited(
      _persist(
        () => _repository.saveAiSuggestion(finalUpdated),
        previous: session,
        action: 'save AI review decision',
      ),
    );
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
      _logAnalytics(AnalyticsEvent.aiReviewCompleted);
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
  /// in-memory state either way so the UI reflects the resulting report
  /// metadata. A no-op while a previous call for this notifier is still
  /// in flight, so double-tapping "Generate Report" can never start two
  /// concurrent renders that would race writing the same predictable
  /// filename.
  Future<ReportGenerationResult> generateReport() async {
    final session = state;
    if (session == null) return const ReportGenerationResult.sessionNotFound();
    if (_isGeneratingReport) {
      return const ReportGenerationResult.failure(
        'A report is already being generated.',
      );
    }

    _isGeneratingReport = true;
    try {
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
      if (result.isSuccess) {
        _logAnalytics(AnalyticsEvent.reportGenerated);
        _logAnalytics(AnalyticsEvent.inspectionCompleted);
      }
      return result;
    } catch (error, stackTrace) {
      AppLogger.error(
        'Report generation failed unexpectedly',
        error,
        stackTrace,
      );
      return ReportGenerationResult.failure(error.toString());
    } finally {
      _isGeneratingReport = false;
    }
  }

  Future<void> shareReport() async {
    final report = state?.report;
    if (report == null) return;
    try {
      await ref
          .read(reportShareServiceProvider)
          .shareReport(filePath: report.filePath, fileName: report.fileName);
    } catch (error, stackTrace) {
      AppLogger.error('Report share failed', error, stackTrace);
      ref
          .read(activeSessionErrorProvider.notifier)
          .set('Could not share the report. Please try again.');
    }
  }

  // ---- session deletion (Phase 8) ----

  /// Permanently deletes [sessionId]: its database row (and, via
  /// cascading foreign keys, its sections/findings/evidence metadata/AI
  /// suggestions/report metadata), plus every evidence file and the
  /// generated report file it referenced. Local-only — cloud data
  /// previously synced for this session is not deleted; see
  /// `docs/production_readiness.md` ("Session deletion").
  ///
  /// If [sessionId] is the active session, the active session is
  /// cleared. Best-effort file cleanup: a file that fails to delete is
  /// logged and otherwise ignored — it never blocks or reverts the
  /// database deletion.
  Future<void> deleteSession(String sessionId) async {
    final toDelete = await _repository.loadSession(sessionId);
    await _repository.deleteSession(sessionId);

    if (toDelete != null) {
      final evidenceFileStore = ref.read(evidenceFileStoreProvider);
      for (final finding in toDelete.findings) {
        for (final evidence in finding.evidence) {
          unawaited(evidenceFileStore.deleteEvidenceFile(evidence.filePath));
        }
      }
      final report = toDelete.report;
      if (report != null) {
        unawaited(
          ref.read(reportFileStoreProvider).deleteReportFile(report.filePath),
        );
      }
    }

    if (state?.id == sessionId) {
      state = null;
    }
    ref.invalidate(sessionSummariesProvider);
  }
}

final activeSessionProvider =
    NotifierProvider<ActiveInspectionSession, InspectionSession?>(
      ActiveInspectionSession.new,
    );
