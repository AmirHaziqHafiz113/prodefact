import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../core/logging/app_logger.dart';
import '../../../data/ai/ai_providers.dart';
import '../../../data/areas/area_candidate_providers.dart';
import '../../../data/analytics/analytics_providers.dart';
import '../../../data/billing/billing_providers.dart';
import '../../../data/local/database_providers.dart';
import '../../../data/remote/remote_providers.dart';
import '../../../data/report/report_providers.dart';
import '../config/home_inspection_config.dart';
import '../config/property_type.dart';
import 'session_list_providers.dart';
import 'wallet_providers.dart';

String? _orNull(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

/// A photo captured for a finding that doesn't exist yet — see
/// `ActiveInspectionSession.captureFindingPhoto`/`saveCameraFinding`.
class CapturedFindingPhoto {
  const CapturedFindingPhoto({
    required this.pendingFindingId,
    required this.filePath,
    required this.source,
    this.annotatedFilePath,
  });

  final String pendingFindingId;

  /// The original photo — never modified.
  final String filePath;
  final EvidenceSource source;

  /// A marked-up copy made before saving, if any (QA #14).
  final String? annotatedFilePath;

  String get displayFilePath => annotatedFilePath ?? filePath;

  CapturedFindingPhoto withAnnotation(String annotatedFilePath) =>
      CapturedFindingPhoto(
        pendingFindingId: pendingFindingId,
        filePath: filePath,
        source: source,
        annotatedFilePath: annotatedFilePath,
      );
}

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
  InspectionSession? build() {
    ref.onDispose(_cancelAiReplayTimers);
    ref.onDispose(() => _queueWatchdog?.cancel());
    // Auto-resume: the moment real device connectivity transitions to
    // online, recover every interrupted finding — see
    // `processQueuedAiClassifications`, which is idempotent (an
    // in-flight guard, de-duplicated replay timers, and replays that
    // reuse the persisted idempotency key) and never touches a
    // terminal or failed finding, so this can safely fire on every
    // reconnect without risking a duplicate request, charge, or
    // finding. Only relevant once Firebase is
    // configured — local-only/demo mode never needs connectivity at
    // all (AI runs synchronously, offline, via the fake service).
    if (ref.watch(firebaseReadyProvider)) {
      ref.listen(connectivityStatusProvider, (previous, next) {
        final wasOnline = previous?.value == ConnectivityStatus.online;
        final isOnlineNow = next.value == ConnectivityStatus.online;
        if (!wasOnline && isOnlineNow) {
          unawaited(processQueuedAiClassifications());
          unawaited(flushAreaCandidates());
        }
      });
      // Signing in (including Firebase restoring the user a moment
      // after a cold start) is a recovery trigger too: work parked as
      // "signed out" must not wait for a connectivity change that, on
      // an already-online device, never comes.
      ref.listen(authStateProvider, (previous, next) {
        if (previous?.value == null && next.value != null) {
          unawaited(processQueuedAiClassifications());
        }
      });
    }
    return null;
  }

  InspectionRepository get _repository =>
      ref.read(inspectionRepositoryProvider);

  bool _isSyncing = false;
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

  /// Persists a brand-new session and makes it the active one — this is
  /// the exact moment an inspection becomes "intentionally created," so
  /// callers should only invoke this from an explicit, final user
  /// action (e.g. "Start Inspection"), never merely from picking a
  /// property type — see `NewInspectionDraftNotifier`, which holds
  /// everything before that point in memory only, with no database row
  /// and nothing visible on the dashboard until this succeeds.
  ///
  /// [initialSections] lets a caller pass an already-configured area
  /// list (include/exclude, renames, custom areas) rather than the
  /// property type's untouched defaults.
  Future<bool> startNew(
    PropertyType propertyType, {
    List<Section>? initialSections,
    PropertyDetails propertyDetails = PropertyDetails.empty,
    CommercialMode? commercialMode,
    AiLevel? selectedAiLevel,
  }) async {
    final sections =
        initialSections ??
        HomeInspectionConfig.defaultSectionsFor(propertyType);
    try {
      final session = await _repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: propertyType.name,
        initialSections: sections,
        ownerUid: ref.read(authServiceProvider).currentUser?.uid,
        propertyDetails: propertyDetails,
        commercialMode: commercialMode,
        selectedAiLevel: selectedAiLevel,
      );
      state = session;
      // Areas added during setup ("Add Newly Discovered Area") are
      // candidates too (QA #12).
      final discovered = [
        for (final section in session.sections)
          if (section.id.startsWith('custom_')) section.name,
      ];
      if (discovered.isNotEmpty) {
        unawaited(_queueAreaCandidates(discovered, session.assetTypeId));
      }
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
      unawaited(processQueuedAiClassifications());
      unawaited(flushAreaCandidates());
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

  void addCustomArea(String name) => addDiscoveredArea(name);

  /// Adds an area found on site that the suggested list didn't have
  /// (QA #12). It joins this inspection immediately — no approval, no
  /// network — and is queued as a candidate so a reviewed version can
  /// later be suggested to other inspectors. Nothing is added to the
  /// suggested-area catalogue itself. Returns the new area, or null for
  /// a blank name.
  Section? addDiscoveredArea(String name, {bool isPlumbing = false}) {
    final trimmed = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return null;
    final session = state;
    if (session == null) return null;
    final section = HomeInspectionConfig.customSection(
      trimmed,
      isPlumbing: isPlumbing,
    );
    _updateSections([...session.sections, section]);
    unawaited(_queueAreaCandidates([trimmed], session.assetTypeId));
    return section;
  }

  bool _isFlushingAreaCandidates = false;

  Future<void> _queueAreaCandidates(
    List<String> names,
    String propertyType,
  ) async {
    try {
      final now = DateTime.now();
      for (final (i, name) in names.indexed) {
        await _repository.saveAreaCandidate(
          AreaCandidate(
            id: 'area_candidate_${now.microsecondsSinceEpoch}_$i',
            rawName: name,
            normalizedName: AreaCandidate.normalizeLocally(name),
            propertyType: propertyType,
            createdAt: now,
          ),
        );
      }
    } catch (error, stackTrace) {
      // Never blocks the inspection: the area is already added.
      AppLogger.error('Could not queue an area candidate', error, stackTrace);
      return;
    }
    await flushAreaCandidates();
  }

  /// Delivers queued area candidates, oldest first, stopping at the
  /// first failure (e.g. offline) so order is kept for the next attempt.
  /// Runs after an area is added, on reconnect, and when an inspection
  /// is opened. Safe to call repeatedly.
  Future<void> flushAreaCandidates() async {
    if (_isFlushingAreaCandidates || !ref.mounted) return;
    _isFlushingAreaCandidates = true;
    try {
      final pending = await _repository.pendingAreaCandidates();
      for (final candidate in pending) {
        if (!ref.mounted) return;
        try {
          await ref
              .read(areaCandidateServiceProvider)
              .submit(
                rawName: candidate.rawName,
                propertyType: candidate.propertyType,
              );
        } catch (error) {
          AppLogger.info('area_candidate_pending id=${candidate.id}');
          return;
        }
        await _repository.markAreaCandidateSubmitted(candidate.id);
      }
    } catch (error, stackTrace) {
      AppLogger.error('Could not deliver area candidates', error, stackTrace);
    } finally {
      _isFlushingAreaCandidates = false;
    }
  }

  /// Records a contextual note for one area — not a defect, never sent
  /// through AI classification. Pass an empty/blank string (or null) to
  /// clear it.
  void setAreaNote(String sectionId, String? note) {
    final session = state;
    if (session == null) return;
    final trimmed = note?.trim();
    final normalized = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _updateSections([
      for (final section in session.sections)
        if (section.id == sectionId)
          section.copyWith(note: normalized, clearNote: normalized == null)
        else
          section,
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
    final saved = _persist(
      () => _repository.saveFinding(session.id, finding),
      previous: session,
      action: 'save finding',
    );
    unawaited(saved);
    ref.invalidate(sessionSummariesProvider);
    // The quick note was the missing piece (QA #16): adding it starts AI
    // straight away (analysis is always automatic).
    if (finding.hasDefectNote &&
        finding.isAiEligible &&
        finding.aiStatus == AiFindingStatus.awaitingApproval) {
      _setFindingAiStatusDurable(session.id, findingId, AiFindingStatus.queued);
      unawaited(
        saved.then((_) => _enqueueAiClassification(session.id, findingId)),
      );
    }
  }

  /// Deletes a finding everywhere the workflow can see it: the area
  /// list, AI Review (its suggestion goes too), the queue (timers and
  /// backoff are cancelled), readiness counts and the report. A late AI
  /// answer for it is discarded by the coordinator, never resurrected.
  /// Its cloud copy is deleted too (best effort), so a stale replay is
  /// refused by the backend instead of analysed. Billing records stay.
  void removeFinding(String findingId) {
    final session = state;
    if (session == null) return;
    final removedFinding = session.findings.firstWhereOrNull(
      (finding) => finding.id == findingId,
    );
    _aiReplayTimers.remove(findingId)?.cancel();
    _parkedTimerFindingIds.remove(findingId);
    _uploadFailures.remove(findingId);
    _parkedWaits.remove(findingId);
    _parkedSince.remove(findingId);
    _failureReasons.remove(findingId);
    _aiDiagnostics.remove(findingId);
    state = session.copyWith(
      findings: session.findings
          .where((finding) => finding.id != findingId)
          .toList(),
      aiSuggestions: session.aiSuggestions
          .where((suggestion) => suggestion.findingId != findingId)
          .toList(),
      updatedAt: DateTime.now(),
    );
    AppLogger.info('finding_deleted finding=$findingId');
    final deleted = _persist(
      () => _repository.deleteFinding(session.id, findingId),
      previous: session,
      action: 'delete finding',
    );
    unawaited(deleted);
    if (ref.read(firebaseReadyProvider)) {
      unawaited(
        deleted.then(
          (_) => ref
              .read(syncCoordinatorProvider)
              .deleteRemoteFinding(session.id, findingId),
        ),
      );
    }
    if (removedFinding != null) {
      final fileStore = ref.read(evidenceFileStoreProvider);
      for (final evidence in removedFinding.evidence) {
        unawaited(fileStore.deleteEvidenceFile(evidence.filePath));
        final annotated = evidence.annotatedFilePath;
        if (annotated != null) {
          unawaited(fileStore.deleteEvidenceFile(annotated));
        }
      }
    }
    // Removing the last unresolved finding can settle the review.
    final current = state;
    if (current != null) state = _completeAiReviewIfSettled(current);
    ref.invalidate(sessionSummariesProvider);
  }

  /// Completes the physical site visit. Requires only that at least one
  /// area was inspected — never every suggested area, never AI or
  /// review (those gate the report, not the site visit; see
  /// [canCompletePhysicalInspection]). Every area the inspector worked
  /// in but didn't explicitly close is marked complete, since the
  /// inspector is leaving the property; untouched suggested areas stay
  /// untouched and are left out of the report. AI work already queued
  /// carries on in the background. Returns false if nothing has been
  /// inspected yet.
  Future<bool> markPhysicalInspectionComplete() async {
    final session = state;
    if (session == null || !canCompletePhysicalInspection(session)) {
      return false;
    }
    final now = DateTime.now();
    final startedAreaIds = [
      for (final section in session.sections)
        if (section.isIncluded &&
            areaVisitStateOf(session, section) == AreaVisitState.started)
          section.id,
    ];
    state = session.copyWith(
      status: InspectionStatus.physicalInspectionComplete,
      sectionStatuses: {
        ...session.sectionStatuses,
        for (final id in startedAreaIds) id: SectionStatus.completed,
      },
      updatedAt: now,
    );
    await _persist(
      () async {
        for (final id in startedAreaIds) {
          await _repository.saveSectionStatus(
            session.id,
            id,
            SectionStatus.completed,
          );
        }
        await _repository.setSessionStatus(
          session.id,
          InspectionStatus.physicalInspectionComplete,
        );
      },
      previous: session,
      action: 'complete physical inspection',
    );
    final completed = state;
    if (ref.mounted && completed != null && completed.id == session.id) {
      state = _completeAiReviewIfSettled(completed);
    }
    ref.invalidate(sessionSummariesProvider);
    return true;
  }

  // ---- evidence (Phase 4) ----

  /// Captures/imports a photo and attaches it to an EXISTING finding.
  ///
  /// Not part of the field workflow: one photo = one finding (tester
  /// feedback, 2026-10-01), so the app never stacks a new photo onto a
  /// finding — "Add another defect photo" creates a new finding instead.
  /// Kept only to build historical multi-photo findings in tests; the
  /// annotation makes any app-code call an analyzer warning.
  ///
  /// Any capture failure (permission denied, picker/import error) or
  /// persistence failure is caught and surfaced via
  /// [activeSessionErrorProvider] instead of throwing out of a UI
  /// callback.
  @visibleForTesting
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
    final evidencePersisted = _persist(
      () => _repository.addEvidence(session.id, evidence),
      previous: session,
      action: 'attach photo',
    );
    unawaited(evidencePersisted);

    // A new photo can change an already-settled classification, so a
    // finding whose AI processing already finished is re-queued
    // (analysis is always automatic).
    final target = findings.firstWhereOrNull((f) => f.id == findingId);
    if (target != null && !aiFindingStatusIsInFlight(target.aiStatus)) {
      // Durable: the coordinator reads the stored status and would skip
      // a finding still recorded as completed.
      _setFindingAiStatusDurable(session.id, findingId, AiFindingStatus.queued);
      // Only once the new evidence is durably saved — the coordinator
      // reads the finding from storage, not from this in-memory state.
      unawaited(
        evidencePersisted.then(
          (_) => _enqueueAiClassification(session.id, findingId),
        ),
      );
    }
  }

  // ---- camera-first finding creation ----

  /// Captures a photo for a **not-yet-created** finding in [sectionId]
  /// — no `Finding`/`Evidence` row is written to the database at this
  /// point, so the inspector can preview and discard without ever
  /// creating a finding (and, critically, without ever queuing AI —
  /// AI only ever runs after an explicit [saveCameraFinding]). Returns
  /// null if the picker was cancelled, or on a capture failure (surfaced
  /// via [activeSessionErrorProvider]).
  Future<CapturedFindingPhoto?> captureFindingPhoto({
    required EvidenceSource source,
  }) async {
    final pendingFindingId = 'finding_${DateTime.now().microsecondsSinceEpoch}';
    try {
      final captureService = ref.read(evidenceCaptureServiceProvider);
      final captured = await captureService.captureImage(
        findingId: pendingFindingId,
        source: source,
      );
      if (captured == null) return null; // user cancelled the picker
      return CapturedFindingPhoto(
        pendingFindingId: pendingFindingId,
        filePath: captured.filePath,
        source: captured.source,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Finding photo capture failed', error, stackTrace);
      ref
          .read(activeSessionErrorProvider.notifier)
          .set(
            'Could not add that photo. Check camera/photo permissions and '
            'try again.',
          );
      return null;
    }
  }

  /// Captures photos for **new** findings in one action: from the
  /// gallery the inspector can pick up to [maxImages] photos; the camera
  /// takes one. One photo = one finding, so every photo gets its OWN
  /// pending finding id and is saved as its own finding — even several
  /// angles of the same defect. Empty if cancelled or on a capture
  /// failure (surfaced via [activeSessionErrorProvider]).
  Future<List<CapturedFindingPhoto>> captureFindingPhotos({
    required EvidenceSource source,
    int maxImages = 3,
  }) async {
    final pendingFindingId = 'finding_${DateTime.now().microsecondsSinceEpoch}';
    try {
      final captured = await ref
          .read(evidenceCaptureServiceProvider)
          .captureImages(
            findingId: pendingFindingId,
            source: source,
            maxImages: maxImages,
          );
      return [
        for (final (i, c) in captured.indexed)
          CapturedFindingPhoto(
            pendingFindingId: i == 0
                ? pendingFindingId
                : '${pendingFindingId}_$i',
            filePath: c.filePath,
            source: c.source,
          ),
      ];
    } catch (error, stackTrace) {
      AppLogger.error('Finding photo capture failed', error, stackTrace);
      ref
          .read(activeSessionErrorProvider.notifier)
          .set(
            'Could not add those photos. Check camera/photo permissions and '
            'try again.',
          );
      return const [];
    }
  }

  /// Discards a photo captured via [captureFindingPhoto] that was never
  /// saved — deletes the temp file; nothing else to roll back, since
  /// nothing was ever persisted to the database.
  Future<void> discardCapturedFindingPhoto(CapturedFindingPhoto photo) async {
    final store = ref.read(evidenceFileStoreProvider);
    await store.deleteEvidenceFile(photo.filePath);
    final annotated = photo.annotatedFilePath;
    if (annotated != null) await store.deleteEvidenceFile(annotated);
  }

  /// Saves an annotated rendering of a captured, not-yet-saved photo as
  /// a separate file (the original is untouched) and returns the photo
  /// carrying it. Replacing an earlier annotation deletes that copy.
  Future<CapturedFindingPhoto> annotateCapturedPhoto(
    CapturedFindingPhoto photo,
    List<int> pngBytes,
  ) async {
    final store = ref.read(evidenceFileStoreProvider);
    final path = await store.saveAnnotatedCopy(
      originalFilePath: photo.filePath,
      pngBytes: pngBytes,
    );
    final previous = photo.annotatedFilePath;
    if (previous != null) unawaited(store.deleteEvidenceFile(previous));
    return photo.withAnnotation(path);
  }

  /// Saves an annotated rendering of an existing photo (QA #14/#20) as a
  /// separate file next to the original, which is never modified. The
  /// photo is queued for upload again so the copy reaches the cloud.
  Future<void> saveEvidenceAnnotation({
    required String findingId,
    required String evidenceId,
    required List<int> pngBytes,
  }) async {
    final session = state;
    if (session == null) return;
    final evidence = session.findings
        .firstWhereOrNull((f) => f.id == findingId)
        ?.evidence
        .firstWhereOrNull((e) => e.id == evidenceId);
    if (evidence == null) return;
    final store = ref.read(evidenceFileStoreProvider);
    final String path;
    try {
      path = await store.saveAnnotatedCopy(
        originalFilePath: evidence.filePath,
        pngBytes: pngBytes,
      );
    } catch (error, stackTrace) {
      AppLogger.error('Could not save an annotated photo', error, stackTrace);
      if (ref.mounted) {
        ref
            .read(activeSessionErrorProvider.notifier)
            .set('Could not save your markup. Please try again.');
      }
      return;
    }
    if (!ref.mounted) return;
    final current = state;
    if (current == null || current.id != session.id) return;
    state = current.copyWith(
      findings: [
        for (final finding in current.findings)
          if (finding.id == findingId)
            finding.copyWith(
              evidence: [
                for (final e in finding.evidence)
                  if (e.id == evidenceId)
                    e.copyWith(
                      annotatedFilePath: path,
                      syncStatus: SyncStatus.pendingUpdate,
                    )
                  else
                    e,
              ],
            )
          else
            finding,
      ],
    );
    unawaited(
      _persist(
        () => _repository.setEvidenceAnnotation(session.id, evidenceId, path),
        previous: current,
        action: 'save markup',
      ),
    );
    final previous = evidence.annotatedFilePath;
    if (previous != null) unawaited(store.deleteEvidenceFile(previous));
  }

  /// Commits a photo captured via [captureFindingPhoto] as a new
  /// camera-first finding: creates the `Finding` row (no pre-chosen
  /// element/component — see `Finding`'s doc comment), attaches the
  /// photo as its first evidence, and persists both. This is the
  /// **only** place a camera-first finding is created. AI analysis is
  /// always automatic (tester feedback, 2026-10-02: "the main reason to
  /// use the app"): a finding with its quick note is queued at once and
  /// drained in the background; one saved without a note waits as
  /// `awaitingApproval` ("Add a quick defect note to start AI") until
  /// the note is added (QA #16).
  Finding saveCameraFinding({
    required String sectionId,
    required CapturedFindingPhoto photo,
    String? note,
    String? captureBatchId,
  }) {
    final session = state;
    if (session == null) {
      throw StateError('Cannot save a finding without an active session');
    }
    final now = DateTime.now();
    // Exactly one photo per new finding. The evidence id derives from
    // the (unique) finding id, so findings saved together in one gallery
    // pick can never collide on an id.
    final evidence = Evidence(
      id: 'evidence_${photo.pendingFindingId.replaceFirst('finding_', '')}',
      findingId: photo.pendingFindingId,
      filePath: photo.filePath,
      annotatedFilePath: photo.annotatedFilePath,
      createdAt: now,
      source: photo.source,
    );
    final draft = Finding(
      id: photo.pendingFindingId,
      sectionId: sectionId,
      description: _orNull(note),
      createdAt: now,
      updatedAt: now,
      evidence: [evidence],
      captureBatchId: captureBatchId,
    );
    // AI waits for a quick defect note (QA #16); saving never does.
    // AI analysis is always automatic (tester feedback, 2026-10-02);
    // it only waits for the quick note (QA #16).
    final startsAi = draft.hasDefectNote;
    final finding = Finding(
      id: draft.id,
      sectionId: draft.sectionId,
      description: draft.description,
      createdAt: now,
      updatedAt: now,
      evidence: draft.evidence,
      aiStatus: startsAi
          ? AiFindingStatus.queued
          : AiFindingStatus.awaitingApproval,
      captureBatchId: captureBatchId,
    );

    // Recording a defect is what makes a suggested area "started".
    final areaWasUntouched =
        (session.sectionStatuses[sectionId] ?? SectionStatus.notStarted) ==
        SectionStatus.notStarted;
    state = session.copyWith(
      findings: [...session.findings, finding],
      sectionStatuses: areaWasUntouched
          ? {...session.sectionStatuses, sectionId: SectionStatus.inProgress}
          : null,
      updatedAt: now,
    );
    final saveTimer = Stopwatch()..start();
    final findingPersisted = _persist(
      () async {
        if (areaWasUntouched) {
          await _repository.saveSectionStatus(
            session.id,
            sectionId,
            SectionStatus.inProgress,
          );
        }
        await _repository.saveFinding(session.id, finding);
        await _repository.addEvidence(session.id, evidence);
        AppLogger.info(
          'finding_saved finding=${finding.id} '
          'ms=${saveTimer.elapsedMilliseconds} queued=$startsAi',
        );
      },
      previous: session,
      action: 'save finding',
    );
    unawaited(findingPersisted);
    ref.invalidate(sessionSummariesProvider);
    _logAnalytics(AnalyticsEvent.findingSaved);
    if (startsAi) {
      AppLogger.info('ai_queued finding=${finding.id} reason=saved');
      _ensureQueueWatchdog();
      // Only once the finding is durably saved: the coordinator reads it
      // from storage, and must never race ahead of the save (it would
      // find nothing and silently skip the finding). The caller still
      // returns immediately — nothing here is awaited by Save Finding.
      unawaited(
        findingPersisted.then(
          (_) => _enqueueAiClassification(session.id, finding.id),
        ),
      );
    }
    return finding;
  }

  /// Saves each captured photo as its own independent finding, in
  /// order, with the matching note from [notes] (missing entries mean no
  /// note). Each finding gets its own id, evidence, AI job and review —
  /// nothing is shared between them. Several photos from one pick share
  /// a `captureBatchId`, used only to show them as one visual group.
  List<Finding> saveCameraFindings({
    required String sectionId,
    required List<CapturedFindingPhoto> photos,
    List<String?> notes = const [],
  }) {
    final batchId = photos.length > 1
        ? 'batch_${photos.first.pendingFindingId}'
        : null;
    return [
      for (final (i, photo) in photos.indexed)
        saveCameraFinding(
          sectionId: sectionId,
          photo: photo,
          note: i < notes.length ? notes[i] : null,
          captureBatchId: batchId,
        ),
    ];
  }

  /// Removes one photo from a finding (QA #20) without touching the
  /// finding or its other photos. A finding's last photo can't be
  /// removed this way — remove the finding instead — so a defect ticket
  /// never silently loses all of its evidence. Returns false when
  /// nothing was removed.
  bool removeEvidence({required String findingId, required String evidenceId}) {
    final session = state;
    if (session == null) return false;
    final target = session.findings.firstWhereOrNull((f) => f.id == findingId);
    if (target == null ||
        target.evidence.length < 2 ||
        !target.evidence.any((e) => e.id == evidenceId)) {
      return false;
    }
    final now = DateTime.now();
    String? removedFilePath;
    String? removedAnnotatedPath;
    final findings = [
      for (final finding in session.findings)
        if (finding.id == findingId)
          finding.copyWith(
            evidence: finding.evidence.where((e) {
              final keep = e.id != evidenceId;
              if (!keep) {
                removedFilePath = e.filePath;
                removedAnnotatedPath = e.annotatedFilePath;
              }
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
    final store = ref.read(evidenceFileStoreProvider);
    for (final path in [removedFilePath, removedAnnotatedPath]) {
      if (path != null) unawaited(store.deleteEvidenceFile(path));
    }
    return true;
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

  // ---- progressive per-finding AI classification ----

  /// Findings currently being classified, so a duplicate trigger (e.g.
  /// resuming a session that already kicked off processing) can never
  /// start two concurrent classification calls for the same finding.
  final Set<String> _classifyingFindingIds = {};

  /// One pending replay timer per finding whose outstanding AI request
  /// can't be replayed yet (see `AiAnalysisAttempt.replaySafeAfter`).
  /// In-memory only by design: an app restart re-derives these from the
  /// persisted attempts on the next session load.
  final Map<String, Timer> _aiReplayTimers = {};

  void _cancelAiReplayTimers() {
    for (final timer in _aiReplayTimers.values) {
      timer.cancel();
    }
    _aiReplayTimers.clear();
  }

  /// Schedules one replay of [findingId]'s outstanding request at [at].
  /// Idempotent: an already-pending timer for the finding is kept, so
  /// repeated recovery triggers never stack duplicate replays.
  void _scheduleAiReplay(String sessionId, String findingId, DateTime at) {
    if (_aiReplayTimers[findingId]?.isActive ?? false) return;
    final delay = at.difference(DateTime.now()) + const Duration(seconds: 1);
    _aiReplayTimers[findingId] = Timer(
      delay.isNegative ? Duration.zero : delay,
      () {
        _aiReplayTimers.remove(findingId);
        _parkedTimerFindingIds.remove(findingId);
        if (!ref.mounted || state?.id != sessionId) return;
        unawaited(_enqueueAiClassification(sessionId, findingId));
      },
    );
  }

  /// How long to wait before re-trying a finding's evidence upload
  /// after a failure while online (QA #27). The queue wakes itself on
  /// these timers; no reconnect or app reopen is needed. After the last
  /// delay the finding moves to `failed`, where Retry is offered.
  static const _uploadRetryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
    Duration(minutes: 2),
  ];

  /// Consecutive upload failures per finding in this app session.
  final Map<String, int> _uploadFailures = {};

  // ---- queue guarantee (P0, 2026-10-02) ----
  //
  // A finding may never stay queued forever. Before this, a finding
  // parked as offline/signed-out had no timer of its own: only an
  // offline->online connectivity event (or reopening the inspection)
  // woke it. On an already-online device that event never comes — a
  // one-off "offline" reading from the connectivity check, or Firebase
  // Auth still restoring the user at cold start, left findings showing
  // "Queued for AI" indefinitely. Now every parked finding wakes itself
  // on a bounded backoff, sign-in drains the queue, and a watchdog
  // re-drains anything not actually being worked on.

  /// How often the watchdog re-drains the queue while any finding is
  /// still waiting for AI.
  static const _queueWatchdogInterval = Duration(seconds: 20);

  /// Self-wake delays for a finding that couldn't be sent (offline or
  /// signed out); the last repeats. Never ends in `failed` — waiting
  /// for a connection is honest — but always re-checks on its own.
  static const _parkedRetryDelays = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 20),
    Duration(seconds: 40),
    Duration(seconds: 60),
  ];

  /// After this many consecutive "offline" readings from the fresh
  /// connectivity check while the app's own connectivity signal says
  /// online, the request is attempted anyway: a real network failure is
  /// then handled (bounded) by the upload/AI failure paths.
  static const _maxConflictingOfflineReadings = 2;

  /// Upload of one finding's photo is abandoned (and retried on the
  /// bounded backoff) after this long, so a stalled transfer can never
  /// hold a finding in `uploading`.
  static const _evidenceUploadTimeout = Duration(minutes: 3);

  Timer? _queueWatchdog;
  final Map<String, int> _parkedWaits = {};

  /// A finding that has been unable to start for this long (signed out,
  /// or the device keeps reporting no connection) stops waiting silently
  /// and becomes a visible, retryable failure with a reason. Waiting for
  /// a connection is honest for a while — not forever.
  @visibleForTesting
  Duration maxParkedWait = const Duration(minutes: 10);

  /// When each currently-parked finding first failed to start.
  final Map<String, DateTime> _parkedSince = {};

  /// Why a finding last ended `failed` in this app session, in plain
  /// language for the card (in-memory; a restart shows the generic text).
  final Map<String, String> _failureReasons = {};

  /// The inspector-facing reason [findingId] last failed, if known.
  String? aiFailureReason(String findingId) => _failureReasons[findingId];

  void _failFinding(String sessionId, String findingId, String reason) {
    _failureReasons[findingId] = reason;
    _parkedSince.remove(findingId);
    _parkedWaits.remove(findingId);
    _setFindingAiStatusDurable(sessionId, findingId, AiFindingStatus.failed);
  }

  /// Findings whose pending timer is only a parked self-wake (offline /
  /// signed out). Any real recovery signal (reconnect, sign-in, resume)
  /// releases them at once; upload backoff and replay windows are
  /// still respected.
  final Set<String> _parkedTimerFindingIds = {};
  final Map<String, AiQueueDiagnostic> _aiDiagnostics = {};

  /// Per-finding queue diagnostics for QA (debug logs only — never
  /// shown in production UI, never containing notes, images or keys).
  List<AiQueueDiagnostic> aiQueueDiagnostics() {
    final session = state;
    if (session == null) return const [];
    return [
      for (final f in session.findings)
        (_aiDiagnostics[f.id] ?? AiQueueDiagnostic(findingId: f.id)).copyWith(
          aiStatus: f.aiStatus,
          uploadStatus: f.evidence.firstOrNull?.syncStatus,
        ),
    ];
  }

  void _noteDiagnostic(
    String findingId, {
    AiLevel? level,
    bool retried = false,
    String? errorCode,
  }) {
    final current =
        _aiDiagnostics[findingId] ?? AiQueueDiagnostic(findingId: findingId);
    _aiDiagnostics[findingId] = current.copyWith(
      aiLevel: level,
      retryCount: current.retryCount + (retried ? 1 : 0),
      lastTransitionAt: DateTime.now(),
      lastErrorCode: errorCode,
    );
  }

  /// Stops the watchdog once nothing is waiting on AI — it only exists
  /// while there is queue work to guarantee.
  void _stopQueueWatchdogIfIdle() {
    if (!ref.mounted) return;
    final waiting = state?.findings.any(_isAwaitingAiWork) ?? false;
    if (!waiting && _classifyingFindingIds.isEmpty) {
      _queueWatchdog?.cancel();
      _queueWatchdog = null;
    }
  }

  void _ensureQueueWatchdog() {
    if (_queueWatchdog?.isActive ?? false) return;
    _queueWatchdog = Timer.periodic(_queueWatchdogInterval, (_) {
      if (!ref.mounted) return;
      final session = state;
      final waiting =
          session?.findings.where(_isAwaitingAiWork).toList() ?? const [];
      if (waiting.isEmpty) {
        _queueWatchdog?.cancel();
        _queueWatchdog = null;
        return;
      }
      if (kDebugMode) _logQueueSummary();
      unawaited(processQueuedAiClassifications());
    });
  }

  /// Whether [finding] still needs the AI pipeline to do something
  /// without any inspector action.
  bool _isAwaitingAiWork(Finding finding) =>
      finding.isAiEligible &&
      (aiFindingStatusIsInFlight(finding.aiStatus) ||
          (finding.hasDefectNote &&
              (finding.aiStatus == AiFindingStatus.notQueued ||
                  finding.aiStatus == AiFindingStatus.awaitingApproval)));

  void _logQueueSummary() {
    final rows = aiQueueDiagnostics();
    final counts = <AiFindingStatus, int>{};
    for (final r in rows) {
      final status = r.aiStatus;
      if (status != null) counts[status] = (counts[status] ?? 0) + 1;
    }
    AppLogger.info(
      'ai_queue_summary '
      '${counts.entries.map((e) => '${e.key.name}=${e.value}').join(' ')}',
    );
    for (final r in rows) {
      final status = r.aiStatus;
      if (status != null && aiFindingStatusIsInFlight(status)) {
        AppLogger.info('ai_queue_item ${r.toLogString()}');
      }
    }
  }

  /// Parks [findingId] (offline/signed out) as `queued` with its own
  /// bounded self-wake — never left waiting on an external event.
  void _parkAndRetry(String sessionId, String findingId, String reason) {
    final since = _parkedSince.putIfAbsent(findingId, DateTime.now);
    if (DateTime.now().difference(since) >= maxParkedWait) {
      AppLogger.info(
        'job_failed finding=$findingId stage=queue reason=parkedTooLong '
        'cause=$reason',
      );
      _failFinding(
        sessionId,
        findingId,
        reason == 'signedOut'
            ? 'You appear to be signed out, so this could not be sent. '
                  'Sign in, then retry.'
            : 'No connection for too long, so this was not sent. '
                  'Check your connection, then retry.',
      );
      return;
    }
    _markWaitingIfInFlight(sessionId, findingId);
    final waits = _parkedWaits[findingId] ?? 0;
    _parkedWaits[findingId] = waits + 1;
    final delay =
        _parkedRetryDelays[waits.clamp(0, _parkedRetryDelays.length - 1)];
    _noteDiagnostic(findingId, retried: true, errorCode: reason);
    AppLogger.info(
      'job_retried finding=$findingId reason=$reason '
      'wait=${waits + 1} inSeconds=${delay.inSeconds}',
    );
    _scheduleAiReplay(sessionId, findingId, DateTime.now().add(delay));
    if (_aiReplayTimers[findingId]?.isActive ?? false) {
      _parkedTimerFindingIds.add(findingId);
    }
  }

  void _onEvidenceUploadFailed(
    String sessionId,
    String findingId,
    String reason,
  ) {
    final failures = (_uploadFailures[findingId] ?? 0) + 1;
    _noteDiagnostic(findingId, retried: true, errorCode: 'upload_$reason');
    if (failures > _uploadRetryDelays.length) {
      _uploadFailures.remove(findingId);
      AppLogger.info(
        'job_failed finding=$findingId stage=upload attempts=$failures',
      );
      _failFinding(
        sessionId,
        findingId,
        'The photo could not be uploaded after several tries. Check your '
        'connection, then retry.',
      );
      return;
    }
    _uploadFailures[findingId] = failures;
    final delay = _uploadRetryDelays[failures - 1];
    AppLogger.info(
      'job_retried finding=$findingId stage=upload attempt=$failures '
      'inSeconds=${delay.inSeconds} reason=$reason',
    );
    _setFindingAiStatusDurable(sessionId, findingId, AiFindingStatus.queued);
    _scheduleAiReplay(sessionId, findingId, DateTime.now().add(delay));
  }

  /// Persists [status] (and mirrors it locally) without touching the
  /// finding's outstanding attempt.
  void _setFindingAiStatusDurable(
    String sessionId,
    String findingId,
    AiFindingStatus status,
  ) {
    _setFindingAiStatusLocal(findingId, status);
    unawaited(_repository.setFindingAiStatus(sessionId, findingId, status));
  }

  void _setFindingAiStatusLocal(String findingId, AiFindingStatus status) {
    // The notifier (and its `ref`) may have been disposed while a
    // background classification was still in flight — e.g. the screen
    // was popped, or (in tests) the container was torn down. There's
    // nothing left to update at that point, and touching a disposed
    // `ref`/`state` throws.
    if (!ref.mounted) return;
    _noteDiagnostic(findingId);
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      findings: [
        for (final finding in session.findings)
          if (finding.id == findingId)
            finding.copyWith(aiStatus: status)
          else
            finding,
      ],
    );
  }

  /// Recovers AI work that isn't running in this process — call on
  /// session resume and on reconnect. Everything is derived from the
  /// durably persisted `aiStatus` + `aiAttempt`, never from in-memory
  /// futures (an app restart destroys those):
  ///
  /// - `completed`/`needsReview`: never touched.
  /// - `failed`: left for the inspector's Retry — never auto-retried,
  ///   so a definitive rejection can't loop, and nothing is re-sent
  ///   without an explicit action.
  /// - `queued`/`uploading`: nothing reached billing yet (or an
  ///   outstanding attempt is replayed under its own key) — resumed.
  /// - `analyzing` with an outstanding attempt: replayed under the same
  ///   key once the original invocation is guaranteed finished
  ///   (a timer covers the gap), so it resolves to the stored result.
  /// - `analyzing` with no attempt: written by a build from before
  ///   attempts were persisted. Its key is unknown, so it can't be
  ///   replayed safely — moved to `failed` for an explicit Retry rather
  ///   than left spinning forever.
  ///
  /// Idempotent: findings already running in this process are skipped,
  /// replay timers are de-duplicated, and the coordinator itself
  /// refuses a replay that could overlap the original — so calling this
  /// repeatedly (several resumes, reconnect flaps) never duplicates a
  /// request.
  Future<void> processQueuedAiClassifications() async {
    final session = state;
    if (session == null) return;
    var anyWaiting = false;
    for (final finding in session.findings) {
      if (!finding.isAiEligible) continue;
      if (_classifyingFindingIds.contains(finding.id)) {
        anyWaiting = true;
        continue;
      }
      // Already scheduled (upload backoff or replay window): the timer
      // owns it. A parked self-wake is released now instead.
      if (_aiReplayTimers[finding.id]?.isActive ?? false) {
        if (_parkedTimerFindingIds.remove(finding.id)) {
          _aiReplayTimers.remove(finding.id)?.cancel();
        } else {
          anyWaiting = true;
          continue;
        }
      }
      switch (finding.aiStatus) {
        case AiFindingStatus.queued:
        case AiFindingStatus.uploading:
          anyWaiting = true;
          unawaited(_enqueueAiClassification(session.id, finding.id));
        case AiFindingStatus.analyzing:
          if (finding.aiAttempt != null) {
            anyWaiting = true;
            unawaited(_enqueueAiClassification(session.id, finding.id));
          } else {
            AppLogger.info(
              'job_failed finding=${finding.id} reason=orphanedAnalyzing',
            );
            _setFindingAiStatusDurable(
              session.id,
              finding.id,
              AiFindingStatus.failed,
            );
          }
        case AiFindingStatus.notQueued:
        case AiFindingStatus.awaitingApproval:
          // Analysis is always automatic: a finding that has its note
          // (e.g. saved while Auto Analyse was an opt-in, or an older
          // record never queued) is analysed now. Without a note it
          // waits for one, shown as such.
          if (finding.hasDefectNote) {
            anyWaiting = true;
            AppLogger.info('ai_queued finding=${finding.id} reason=drain');
            _setFindingAiStatusDurable(
              session.id,
              finding.id,
              AiFindingStatus.queued,
            );
            unawaited(_enqueueAiClassification(session.id, finding.id));
          } else if (finding.aiStatus == AiFindingStatus.notQueued) {
            _setFindingAiStatusDurable(
              session.id,
              finding.id,
              AiFindingStatus.awaitingApproval,
            );
          }
        case AiFindingStatus.completed:
        case AiFindingStatus.needsReview:
          // Finished but its suggestion is missing (e.g. lost by an
          // older build): offer Retry instead of a silent dead end.
          if (!session.aiSuggestions.any((x) => x.findingId == finding.id)) {
            AppLogger.info(
              'job_failed finding=${finding.id} reason=missingSuggestion',
            );
            _setFindingAiStatusDurable(
              session.id,
              finding.id,
              AiFindingStatus.failed,
            );
          }
        case AiFindingStatus.failed:
          break;
      }
    }
    if (anyWaiting) {
      _ensureQueueWatchdog();
    } else {
      _stopQueueWatchdogIfIdle();
    }
  }

  /// Findings with a Reanalyse request being set up right now — a guard
  /// so a double tap can never start two analyses.
  final Set<String> _reanalysing = {};

  /// The inspector's explicit "Reanalyse" — available for ANY finding
  /// with a photo (passed, needs review, failed, manually corrected,
  /// accepted), never run automatically. It is a NEW analysis: a fresh
  /// request key (so the backend's idempotency never hands back the old
  /// answer) and normal AI usage. A failed request whose outcome is
  /// unknown is instead replayed under its own key, so it can't be
  /// charged twice. The previous result is kept in the suggestion's
  /// history; the new one becomes current (and is what the report
  /// uses). [newNote] ("Edit Note & Reanalyse") replaces the quick note
  /// first; otherwise the note is untouched.
  ///
  /// Returns false (and does nothing) when the finding has no photo or
  /// note, or is already being analysed.
  Future<bool> reanalyseFinding(String findingId, {String? newNote}) async {
    final session = state;
    if (session == null) return false;
    var finding = session.findings.firstWhereOrNull((f) => f.id == findingId);
    if (finding == null || !finding.isAiEligible) return false;
    if (_reanalysing.contains(findingId) ||
        _classifyingFindingIds.contains(findingId) ||
        aiFindingStatusIsInFlight(finding.aiStatus)) {
      return false;
    }
    _reanalysing.add(findingId);
    try {
      if (newNote != null) {
        final now = DateTime.now();
        final edited = finding.copyWith(
          description: _orNull(newNote) ?? '',
          updatedAt: now,
        );
        finding = edited;
        state = session.copyWith(
          findings: [
            for (final f in session.findings)
              if (f.id == findingId) edited else f,
          ],
          updatedAt: now,
        );
        // Saved before anything is sent: the request reads the note
        // from storage.
        await _persist(
          () => _repository.saveFinding(session.id, edited),
          previous: session,
          action: 'save finding',
        );
        if (!ref.mounted) return false;
        ref.invalidate(sessionSummariesProvider);
      }
      if (!finding.hasDefectNote) return false;
      _aiReplayTimers.remove(findingId)?.cancel();
      _parkedTimerFindingIds.remove(findingId);
      _uploadFailures.remove(findingId);
      _failureReasons.remove(findingId);
      _parkedSince.remove(findingId);
      _parkedWaits.remove(findingId);
      _noteDiagnostic(findingId, retried: true);
      AppLogger.info('job_retried finding=$findingId reason=reanalyse');
      _setFindingAiStatusDurable(session.id, findingId, AiFindingStatus.queued);
      unawaited(
        _enqueueAiClassification(session.id, findingId, reanalyse: true),
      );
      return true;
    } finally {
      _reanalysing.remove(findingId);
    }
  }

  /// Manually retries a finding whose AI classification previously
  /// failed. A no-op for any other status (in particular, this never
  /// re-runs a finding that's already `completed`/`needsReview` — use
  /// the review actions below to change that outcome instead).
  Future<void> retryAiClassification(String findingId) async {
    final session = state;
    if (session == null) return;
    final finding = session.findings.firstWhereOrNull((f) => f.id == findingId);
    if (finding == null || finding.aiStatus != AiFindingStatus.failed) return;
    _noteDiagnostic(findingId, retried: true);
    _failureReasons.remove(findingId);
    _parkedSince.remove(findingId);
    _parkedWaits.remove(findingId);
    AppLogger.info('job_retried finding=$findingId reason=manualRetry');
    _setFindingAiStatusLocal(findingId, AiFindingStatus.queued);
    unawaited(_enqueueAiClassification(session.id, findingId));
  }

  // ---- commercial: estimate/approve (see docs/commercial_model.md) ----

  /// The price-check step shown before the inspector ever sees an
  /// "Analyse" action they can actually approve — purely informational,
  /// never queues or charges anything. Returns null if there's no
  /// active session or [findingId] doesn't exist in it.
  Future<AnalysisEstimate?> estimateFindingAnalysis(
    String findingId, {
    AiLevel? aiLevel,
  }) async {
    final session = state;
    if (session == null) return null;
    final finding = session.findings.firstWhereOrNull((f) => f.id == findingId);
    if (finding == null) return null;
    // The backend prices only a finding it can see under the caller's
    // own inspection (ownership check). A finding saved with Auto Analyse
    // off is local-only until something syncs it, so register it first;
    // otherwise pricing always answers permission-denied. This writes
    // only the session and finding documents, so it is quick.
    if (ref.read(firebaseReadyProvider)) {
      if (ref.read(authServiceProvider).currentUser == null) {
        throw const BillingCallException(
          'unauthenticated',
          'Sign in to use this.',
        );
      }
      final registered = await ref
          .read(syncCoordinatorProvider)
          .registerFinding(session.id, findingId);
      if (!registered.isSuccess) {
        AppLogger.warning(
          'Could not register finding $findingId before pricing: '
          '${registered.outcome.name}',
        );
        throw BillingCallException(
          registered.outcome == SyncOutcome.unauthenticated
              ? 'unauthenticated'
              : 'unavailable',
          'Could not reach the server.',
          reason: 'findingNotSynced',
        );
      }
    }
    return ref
        .read(billingServiceProvider)
        .estimateFindingAnalysis(
          inspectionId: session.id,
          findingId: findingId,
          aiLevel: aiLevel ?? await _preferredAiLevel(),
        );
  }

  /// The inspector's saved AI level (Profile → AI Analysis Preference),
  /// or Smart when none is saved. Every analysis path resolves its level
  /// here, so the choice applies silently and consistently.
  Future<AiLevel> _preferredAiLevel() async {
    try {
      final profile = await _repository.loadUserProfile();
      return profile.defaultAiLevel ?? kFieldAnalysisAiLevel;
    } catch (error) {
      AppLogger.warning('Could not read the AI preference', error);
      return kFieldAnalysisAiLevel;
    }
  }

  /// The explicit approval action — the **only** way a finding that's
  /// `awaitingApproval` ever actually starts spending Credits. Only
  /// valid for a finding that's currently `awaitingApproval` or
  /// `failed` (a manual retry after approval already happened once);
  /// a no-op for any other status.
  Future<void> approveAndRunAnalysis(
    String findingId, {
    AiLevel? aiLevel,
  }) async {
    final session = state;
    if (session == null) return;
    final finding = session.findings.firstWhereOrNull((f) => f.id == findingId);
    if (finding == null) return;
    if (finding.aiStatus != AiFindingStatus.awaitingApproval &&
        finding.aiStatus != AiFindingStatus.failed) {
      return;
    }
    // AI never starts without a quick defect note (QA #16).
    if (!finding.hasDefectNote) return;
    _setFindingAiStatusLocal(findingId, AiFindingStatus.queued);
    unawaited(
      _enqueueAiClassification(session.id, findingId, aiLevel: aiLevel),
    );
  }

  /// Runs one finding's classification in the background: never awaited
  /// by a caller, and safe to call redundantly (idempotent — a finding
  /// already in flight, or already terminal, is skipped). This is what
  /// lets AI work through Section A's findings while the inspector is
  /// already physically inspecting Section B — nothing here blocks the
  /// UI thread or any other provider call.
  ///
  /// The `analyzing` status (together with the request's idempotency
  /// key) is persisted by the coordinator immediately before the request
  /// is sent — never earlier — so a persisted `analyzing` always has a
  /// replayable key; see [processQueuedAiClassifications].
  Future<void> _enqueueAiClassification(
    String sessionId,
    String findingId, {
    AiLevel? aiLevel,
    bool reanalyse = false,
  }) async {
    if (!_classifyingFindingIds.add(findingId)) return;
    try {
      // The notifier (and its `ref`) may already be disposed by the
      // time this actually runs — it's always kicked off un-awaited.
      if (!ref.mounted) return;
      _ensureQueueWatchdog();

      // AI needs a quick defect note (QA #16). A finding queued without
      // one (e.g. by an older build) waits for the inspector instead.
      final pending = state?.id == sessionId
          ? state?.findings.firstWhereOrNull((f) => f.id == findingId)
          : null;
      if (pending != null && !pending.hasDefectNote) {
        _setFindingAiStatusDurable(
          sessionId,
          findingId,
          AiFindingStatus.awaitingApproval,
        );
        return;
      }

      // An outstanding request that may still be running server-side:
      // wait until a replay can't overlap it (no upload, no status
      // churn meanwhile — the finding keeps showing its real state).
      final outstanding = state?.id == sessionId
          ? state?.findings
                .firstWhereOrNull((f) => f.id == findingId)
                ?.aiAttempt
          : null;
      if (outstanding != null && !outstanding.isReplaySafeAt(DateTime.now())) {
        _scheduleAiReplay(sessionId, findingId, outstanding.replaySafeAt);
        return;
      }

      final firebaseReady = ref.read(firebaseReadyProvider);
      if (firebaseReady) {
        if (ref.read(authServiceProvider).currentUser == null) {
          // Not signed in (or Firebase Auth hasn't restored the user
          // yet) — nothing can be sent. Shown as "Waiting for
          // connection"; it wakes itself, and sign-in drains it too.
          _parkAndRetry(sessionId, findingId, 'signedOut');
          return;
        }
        // A fresh check right now, not the (occasionally momentarily
        // stale, right after a reconnect event) cached stream value —
        // this is the one place correctness actually matters, since a
        // wrong "online" read here would otherwise cost an attempted
        // (and safely-failed) upload rather than just a UI label.
        final connectivity = await ref
            .read(connectivityServiceProvider)
            .checkStatus();
        if (!ref.mounted) return;
        final conflictingReadings = _parkedWaits[findingId] ?? 0;
        if (connectivity == ConnectivityStatus.offline &&
            !(ref.read(isOnlineForAiProvider) &&
                conflictingReadings >= _maxConflictingOfflineReadings)) {
          // Offline per the fresh check — stays/returns to `queued`
          // without showing `uploading`/`analyzing`, and wakes itself
          // on a bounded backoff (reconnect also drains it). If the
          // app's own connectivity signal keeps saying online, the
          // request is tried anyway after a couple of readings; a real
          // network failure then takes the bounded failure path below.
          _parkAndRetry(sessionId, findingId, 'offline');
          return;
        }
        _setFindingAiStatusDurable(
          sessionId,
          findingId,
          AiFindingStatus.uploading,
        );
        AppLogger.info('upload_started finding=$findingId');
        final upload = Stopwatch()..start();
        try {
          // Only this finding's photos, with no session-wide lock: a
          // second or third finding never waits behind (or gets
          // parked by) another finding's upload (QA #27). Bounded, so a
          // stalled transfer is retried rather than hanging forever.
          final syncResult = await ref
              .read(syncCoordinatorProvider)
              .syncFindingEvidence(sessionId, findingId)
              .timeout(_evidenceUploadTimeout);
          if (!ref.mounted) return;
          if (!syncResult.isSuccess) {
            // Nothing about the classification was attempted yet: back
            // to `queued`, with a self-waking retry (never parked until
            // a reconnect or reopen), then `failed` after a few tries.
            _onEvidenceUploadFailed(
              sessionId,
              findingId,
              syncResult.outcome.name,
            );
            return;
          }
          _uploadFailures.remove(findingId);
          _parkedWaits.remove(findingId);
          _parkedSince.remove(findingId);
          AppLogger.info(
            'upload_completed finding=$findingId '
            'ms=${upload.elapsedMilliseconds}',
          );
        } catch (error) {
          AppLogger.warning(
            'Evidence sync before AI classification failed',
            error,
          );
          if (!ref.mounted) return;
          _onEvidenceUploadFailed(
            sessionId,
            findingId,
            error is TimeoutException ? 'timeout' : 'exception',
          );
          return;
        }
      } else {
        _parkedWaits.remove(findingId);
      }

      // Display only; the coordinator persists `analyzing` together with
      // the idempotency key right before the request is sent.
      _setFindingAiStatusLocal(findingId, AiFindingStatus.analyzing);

      final analysis = Stopwatch()..start();
      // A replay keeps its original level (stored on the attempt); a new
      // job uses the inspector's saved preference.
      final level = aiLevel ?? await _preferredAiLevel();
      if (!ref.mounted) return;
      _noteDiagnostic(findingId, level: level);
      AppLogger.info('ai_started finding=$findingId level=${level.name}');
      final result = await ref
          .read(aiClassificationCoordinatorProvider)
          .classifyFinding(
            sessionId,
            findingId,
            aiLevel: level,
            reanalyse: reanalyse,
          );
      AppLogger.info(
        'ai_finished finding=$findingId level=${level.name} '
        'outcome=${result.outcome.name} ms=${analysis.elapsedMilliseconds}',
      );
      if (result.outcome == AiClassificationOutcome.failure) {
        _noteDiagnostic(findingId, errorCode: 'ai_failure');
        _failureReasons[findingId] =
            'AI could not analyse this photo. Retry, or choose the defect '
            'yourself.';
      } else {
        _failureReasons.remove(findingId);
      }

      if (!ref.mounted) return;
      // Reload from the durable store rather than patching in-memory
      // fields by hand — the coordinator already persisted the
      // suggestion/status/attempt; this just brings this notifier's
      // mirror back in sync with it. Only if this is still the active
      // session (the inspector may have navigated away/opened another
      // session while this was in flight).
      if (result.outcome == AiClassificationOutcome.deferred) {
        // Nothing was sent (the earlier request may still be running
        // server-side): show it as waiting, not as a stale "uploading".
        await _repository.setFindingAiStatus(
          sessionId,
          findingId,
          AiFindingStatus.queued,
        );
        if (!ref.mounted) return;
      }
      if (state?.id == sessionId) {
        final reloaded = await _repository.loadSession(sessionId);
        if (ref.mounted && state?.id == sessionId && reloaded != null) {
          state = _completeAiReviewIfSettled(reloaded);
          ref.invalidate(sessionSummariesProvider);
          AppLogger.info(
            'ui_refreshed finding=$findingId status='
            '${reloaded.findings.firstWhereOrNull((f) => f.id == findingId)?.aiStatus.name ?? 'deleted'}',
          );
          final attempt = reloaded.findings
              .firstWhereOrNull((f) => f.id == findingId)
              ?.aiAttempt;
          final retryAt = result.outcome == AiClassificationOutcome.deferred
              ? result.retryAt
              : null;
          final finding = reloaded.findings.firstWhereOrNull(
            (f) => f.id == findingId,
          );
          if (retryAt != null) {
            _scheduleAiReplay(sessionId, findingId, retryAt);
          } else if (attempt != null &&
              finding?.aiStatus == AiFindingStatus.queued) {
            // First submission ended with an unknown outcome: one
            // automatic replay of the same key once it's safe.
            _scheduleAiReplay(sessionId, findingId, attempt.replaySafeAt);
          }
        }
      }
      // The run may have just charged real Credits — never leave
      // Wallet/Home showing a stale balance.
      ref.invalidate(walletBalanceProvider);
    } catch (error, stackTrace) {
      AppLogger.error(
        'AI classification failed unexpectedly',
        error,
        stackTrace,
      );
      if (!ref.mounted) return;
      AppLogger.info('job_failed finding=$findingId reason=unexpected');
      _noteDiagnostic(findingId, errorCode: 'unexpected');
      // Keeps any outstanding attempt, so a Retry replays its key.
      _failFinding(
        sessionId,
        findingId,
        'Something went wrong while analysing this photo. Retry, or '
        'choose the defect yourself.',
      );
    } finally {
      _classifyingFindingIds.remove(findingId);
      _stopQueueWatchdogIfIdle();
    }
  }

  /// A finding that can't be sent right now (offline/signed out) shows
  /// `queued` ("Waiting for connection" while offline) instead of a
  /// stale `uploading`/`analyzing` left over from before a restart. Its
  /// outstanding attempt, if any, is untouched.
  void _markWaitingIfInFlight(String sessionId, String findingId) {
    final status = state?.findings
        .firstWhereOrNull((f) => f.id == findingId)
        ?.aiStatus;
    if (status == AiFindingStatus.uploading ||
        status == AiFindingStatus.analyzing) {
      _setFindingAiStatusDurable(sessionId, findingId, AiFindingStatus.queued);
    }
  }

  // ---- inspector review of AI classifications ----

  /// Approves the AI's own suggestion as-is.
  void acceptSuggestion(String suggestionId) {
    _reviewSuggestion(
      suggestionId,
      status: AiSuggestionStatus.accepted,
      finalCatalogueEntryId: (s) => s.suggestedCatalogueEntryId ?? '',
    );
  }

  /// The inspector picks a different (or, for a `needsReview` finding,
  /// the first) catalogue entry via the searchable picker — this is the
  /// only way free text ever becomes the record; the inspector always
  /// selects from the controlled catalogue, never types a defect name.
  void changeSuggestion(String suggestionId, String catalogueEntryId) {
    _reviewSuggestion(
      suggestionId,
      status: AiSuggestionStatus.edited,
      finalCatalogueEntryId: (_) => catalogueEntryId,
    );
  }

  /// The inspector disagrees with the AI (or there was nothing to
  /// agree/disagree with) and leaves this finding without a final
  /// classification — "reject / mark unresolved". Still a *reviewed*,
  /// resolved state; the report renders it as an explicit "Unresolved"
  /// line. The inspector can still return later and call
  /// [changeSuggestion] to resolve it.
  void rejectSuggestion(String suggestionId) {
    _reviewSuggestion(
      suggestionId,
      status: AiSuggestionStatus.rejected,
      finalCatalogueEntryId: (_) => '',
    );
  }

  /// The inspector chooses [catalogueEntryId] for [findingId] by hand
  /// (Recommended / Other possible defects / search) — whatever state the
  /// finding is in: waiting, failed, needs review, accepted or rejected.
  /// Zero provider calls, zero AI usage. The previous AI result stays in
  /// the suggestion; any queued retry for the finding is cancelled so a
  /// later answer cannot replace the choice. Returns false when a request
  /// is running right now (a late answer could overwrite the choice) or
  /// the finding doesn't exist.
  bool selectDefectForFinding(String findingId, String catalogueEntryId) {
    final session = state;
    if (session == null) return false;
    final finding = session.findings.firstWhereOrNull((f) => f.id == findingId);
    if (finding == null || !FindingResolution.canPickManually(finding)) {
      return false;
    }
    if (!DefectCatalogue.instance.isValidEntryId(catalogueEntryId)) {
      return false;
    }
    _aiReplayTimers.remove(findingId)?.cancel();
    _parkedTimerFindingIds.remove(findingId);
    _failureReasons.remove(findingId);
    _parkedSince.remove(findingId);
    final suggestion = session.aiSuggestions.firstWhereOrNull(
      (s) => s.findingId == findingId,
    );
    if (suggestion == null) {
      manuallyClassifyFinding(findingId, catalogueEntryId);
      return true;
    }
    if (finding.aiStatus != AiFindingStatus.completed) {
      _setFindingAiStatusDurable(
        session.id,
        findingId,
        AiFindingStatus.completed,
      );
    }
    changeSuggestion(suggestion.id, catalogueEntryId);
    return true;
  }

  /// Classifies a finding that has **no** `AiSuggestion` yet — the
  /// `failed` case, where the classification attempt itself errored
  /// before AI ever returned anything to review. This is the "Classify
  /// Manually" fallback alongside "Retry": the inspector is never
  /// blocked from finishing an inspection just because AI couldn't run.
  /// A no-op if a suggestion already exists for [findingId] (the
  /// `needsReview`/`completed` cases already have one to Change
  /// instead — see `ai_suggestion_review_dialog.dart`).
  void manuallyClassifyFinding(String findingId, String catalogueEntryId) {
    final session = state;
    if (session == null) return;
    if (session.aiSuggestions.any((s) => s.findingId == findingId)) return;

    final now = DateTime.now();
    final suggestion = AiSuggestion(
      id: 'suggestion_$findingId',
      sessionId: session.id,
      findingId: findingId,
      providerId: 'manual',
      generatedAt: now,
      finalCatalogueEntryId: catalogueEntryId,
      status: AiSuggestionStatus.edited,
      reviewedAt: now,
    );

    final findings = [
      for (final finding in session.findings)
        if (finding.id == findingId)
          finding.copyWith(aiStatus: AiFindingStatus.completed)
        else
          finding,
    ];
    final suggestions = [...session.aiSuggestions, suggestion];
    // Settled only when every active finding is (the shared readiness
    // rule) — not merely when no suggestion is pending.
    final allResolved = ReportReadiness.of(
      session.copyWith(aiSuggestions: suggestions),
    ).isReady;

    state = session.copyWith(
      findings: findings,
      aiSuggestions: suggestions,
      updatedAt: now,
      aiReviewState: allResolved
          ? AiReviewState.completed
          : session.aiReviewState,
      status: allResolved ? InspectionStatus.aiReviewComplete : session.status,
    );
    unawaited(
      _persist(
        () async {
          await _repository.setFindingAiStatus(
            session.id,
            findingId,
            AiFindingStatus.completed,
          );
          await _repository.saveAiSuggestion(suggestion);
        },
        previous: session,
        action: 'classify finding manually',
      ),
    );
    ref.invalidate(sessionSummariesProvider);
  }

  /// Auto-accepted results can settle the whole review without a tap:
  /// once physical inspection is complete, nothing is still analysing
  /// and no suggestion is pending, the session moves to AI review
  /// complete exactly as if the inspector had resolved the last one.
  InspectionSession _completeAiReviewIfSettled(InspectionSession session) {
    if (session.status != InspectionStatus.physicalInspectionComplete ||
        activeSuggestionsOf(session).isEmpty ||
        !ReportReadiness.of(session).isReady) {
      return session;
    }
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
    return session.copyWith(
      aiReviewState: AiReviewState.completed,
      status: InspectionStatus.aiReviewComplete,
    );
  }

  void _reviewSuggestion(
    String suggestionId, {
    required AiSuggestionStatus status,
    required String Function(AiSuggestion suggestion) finalCatalogueEntryId,
  }) {
    final session = state;
    if (session == null) return;
    final now = DateTime.now();

    AiSuggestion? updated;
    final suggestions = [
      for (final suggestion in session.aiSuggestions)
        if (suggestion.id == suggestionId)
          (updated = suggestion.copyWith(
            status: status,
            reviewedAt: now,
            finalCatalogueEntryId: finalCatalogueEntryId(suggestion),
          ))
        else
          suggestion,
    ];
    final finalUpdated = updated;
    if (finalUpdated == null) return;

    // Settled only when every active finding is (the shared readiness
    // rule) — not merely when no suggestion is pending.
    final allResolved = ReportReadiness.of(
      session.copyWith(aiSuggestions: suggestions),
    ).isReady;
    state = session.copyWith(
      aiSuggestions: suggestions,
      updatedAt: now,
      aiReviewState: allResolved
          ? AiReviewState.completed
          : AiReviewState.readyForReview,
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

  // ---- notes / report metadata (P0 workflow-closure pass) ----

  /// Records the whole-inspection contextual note. Pass null/blank to
  /// clear it. Not a defect, never sent through AI classification.
  void setInspectionNote(String? note) {
    final session = state;
    if (session == null) return;
    final trimmed = note?.trim();
    final normalized = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    state = session.copyWith(
      inspectionNote: normalized,
      clearInspectionNote: normalized == null,
      updatedAt: DateTime.now(),
    );
    unawaited(
      _persist(
        () => _repository.saveInspectionNote(session.id, normalized),
        previous: session,
        action: 'update inspection note',
      ),
    );
  }

  /// Records the inspector's post-setup choice to switch this
  /// inspection to House Pass — called once from `HousePassScreen`
  /// when a purchase is actually initiated, never during New
  /// Inspection setup (see the QA/QC simplification pass, which
  /// removed the Choose AI Plan step). A session already on
  /// `housePass` is left untouched (idempotent).
  void setCommercialMode(CommercialMode mode) {
    final session = state;
    if (session == null || session.commercialMode == mode) return;
    state = session.copyWith(commercialMode: mode, updatedAt: DateTime.now());
    unawaited(
      _persist(
        () => _repository.setCommercialMode(session.id, mode),
        previous: session,
        action: 'update commercial mode',
      ),
    );
  }

  /// Records that [sessionId] now has a House Pass — used by the House
  /// Pass screen, which can be opened from the Wallet for any open
  /// inspection, not only the active one. (AI analysis is always
  /// automatic, with or without a pass.) Updates the in-memory session
  /// too when it is the active one.
  Future<void> applyHousePassToSession(
    String sessionId, {
    required bool passActive,
  }) async {
    final session = state;
    if (session?.id == sessionId) {
      setCommercialMode(CommercialMode.housePass);
      return;
    }
    try {
      await _repository.setCommercialMode(sessionId, CommercialMode.housePass);
      if (ref.mounted) ref.invalidate(sessionSummariesProvider);
    } catch (error, stackTrace) {
      AppLogger.error(
        'Failed to record House Pass on $sessionId',
        error,
        stackTrace,
      );
    }
  }

  /// Confirms/edits the report's cover-page metadata (the Report
  /// Details step) — deliberately never touches [PropertyDetails], the
  /// original New Inspection setup record; see `ReportMetadata`'s doc
  /// comment.
  void setReportMetadata(ReportMetadata metadata) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      reportMetadata: metadata,
      updatedAt: DateTime.now(),
    );
    unawaited(
      _persist(
        () => _repository.saveReportMetadata(session.id, metadata),
        previous: session,
        action: 'update report details',
      ),
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
