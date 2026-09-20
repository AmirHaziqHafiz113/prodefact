import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/inspection/inspection_domain.dart';
import '../../../core/logging/app_logger.dart';
import '../../../data/ai/ai_providers.dart';
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
  });

  final String pendingFindingId;
  final String filePath;
  final EvidenceSource source;
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
    // Auto-resume: the moment real device connectivity transitions to
    // online, re-attempt every queued/failed finding — see
    // `processQueuedAiClassifications`, which is already idempotent
    // (an in-flight guard plus a deterministic suggestion id) and only
    // ever touches findings not already in a terminal state, so this
    // can safely fire on every reconnect without risking a duplicate
    // classification or finding. Only relevant once Firebase is
    // configured — local-only/demo mode never needs connectivity at
    // all (AI runs synchronously, offline, via the fake service).
    if (ref.watch(firebaseReadyProvider)) {
      ref.listen(connectivityStatusProvider, (previous, next) {
        final wasOnline = previous?.value == ConnectivityStatus.online;
        final isOnlineNow = next.value == ConnectivityStatus.online;
        if (!wasOnline && isOnlineNow) {
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

    // A new photo can change an already-settled classification — a
    // finding whose AI processing already finished is re-queued so the
    // extra evidence actually gets considered, rather than silently
    // never being looked at by AI at all. Re-queuing never bypasses the
    // approval gate below: a re-analysis costs Credits exactly like the
    // first one did, so it defers to the same `autoAnalyseEnabled`
    // check rather than always auto-running.
    final target = findings.firstWhereOrNull((f) => f.id == findingId);
    if (target != null && !aiFindingStatusIsInFlight(target.aiStatus)) {
      if (session.autoAnalyseEnabled) {
        _setFindingAiStatusLocal(findingId, AiFindingStatus.queued);
        unawaited(_enqueueAiClassification(session.id, findingId));
      } else {
        _setFindingAiStatusLocal(findingId, AiFindingStatus.awaitingApproval);
      }
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

  /// Discards a photo captured via [captureFindingPhoto] that was never
  /// saved — deletes the temp file; nothing else to roll back, since
  /// nothing was ever persisted to the database.
  Future<void> discardCapturedFindingPhoto(CapturedFindingPhoto photo) {
    return ref
        .read(evidenceFileStoreProvider)
        .deleteEvidenceFile(photo.filePath);
  }

  /// Commits a photo captured via [captureFindingPhoto] as a new
  /// camera-first finding: creates the `Finding` row (no pre-chosen
  /// element/component — see `Finding`'s doc comment), attaches the
  /// photo as its first evidence, and persists both. This is the
  /// **only** place a camera-first finding is created — but, since the
  /// commercial pass, saving a finding is purely physical and **never**
  /// spends Credits: AI is only auto-queued here when
  /// `InspectionSession.autoAnalyseEnabled` is on (an active House
  /// Pass's preference); otherwise the finding starts
  /// `awaitingApproval` and the inspector must explicitly see the
  /// estimate and approve via [approveAndRunAnalysis] before anything
  /// runs — see docs/commercial_model.md ("The estimate -> approval ->
  /// reservation -> settlement protocol").
  Finding saveCameraFinding({
    required String sectionId,
    required CapturedFindingPhoto photo,
    String? note,
  }) {
    final session = state;
    if (session == null) {
      throw StateError('Cannot save a finding without an active session');
    }
    final now = DateTime.now();
    final evidence = Evidence(
      id: 'evidence_${now.microsecondsSinceEpoch}',
      findingId: photo.pendingFindingId,
      filePath: photo.filePath,
      createdAt: now,
      source: photo.source,
    );
    final finding = Finding(
      id: photo.pendingFindingId,
      sectionId: sectionId,
      description: _orNull(note),
      createdAt: now,
      updatedAt: now,
      evidence: [evidence],
      aiStatus: session.autoAnalyseEnabled
          ? AiFindingStatus.queued
          : AiFindingStatus.awaitingApproval,
    );

    state = session.copyWith(
      findings: [...session.findings, finding],
      updatedAt: now,
    );
    unawaited(
      _persist(
        () async {
          await _repository.saveFinding(session.id, finding);
          await _repository.addEvidence(session.id, evidence);
        },
        previous: session,
        action: 'save finding',
      ),
    );
    ref.invalidate(sessionSummariesProvider);
    _logAnalytics(AnalyticsEvent.findingSaved);
    if (session.autoAnalyseEnabled) {
      unawaited(_enqueueAiClassification(session.id, finding.id));
    }
    return finding;
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

  // ---- progressive per-finding AI classification ----

  /// Findings currently being classified, so a duplicate trigger (e.g.
  /// resuming a session that already kicked off processing) can never
  /// start two concurrent classification calls for the same finding.
  final Set<String> _classifyingFindingIds = {};

  void _setFindingAiStatusLocal(String findingId, AiFindingStatus status) {
    // The notifier (and its `ref`) may have been disposed while a
    // background classification was still in flight — e.g. the screen
    // was popped, or (in tests) the container was torn down. There's
    // nothing left to update at that point, and touching a disposed
    // `ref`/`state` throws.
    if (!ref.mounted) return;
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

  /// Scans the active session for any finding whose AI processing
  /// hasn't reached a terminal state yet (queued, or failed — safe to
  /// retry) and (re)starts classification for each. Call this when a
  /// session is resumed/reopened so work queued before the app was
  /// closed, or before connectivity returned, actually continues —
  /// closing and reopening the app never loses or corrupts this
  /// progress, since it's driven entirely from the durably-persisted
  /// `aiStatus`/`AiSuggestion` state, not any in-memory-only queue.
  Future<void> processQueuedAiClassifications() async {
    final session = state;
    if (session == null) return;
    final toProcess = session.findings.where(
      (f) =>
          f.isAiEligible &&
          (f.aiStatus == AiFindingStatus.queued ||
              f.aiStatus == AiFindingStatus.failed),
    );
    for (final finding in toProcess) {
      unawaited(_enqueueAiClassification(session.id, finding.id));
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
    return ref
        .read(billingServiceProvider)
        .estimateFindingAnalysis(
          inspectionId: session.id,
          findingId: findingId,
          aiLevel: aiLevel ?? session.selectedAiLevel ?? AiLevel.smart,
        );
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
  Future<void> _enqueueAiClassification(
    String sessionId,
    String findingId, {
    AiLevel? aiLevel,
  }) async {
    if (!_classifyingFindingIds.add(findingId)) return;
    try {
      // The notifier (and its `ref`) may already be disposed by the
      // time this actually runs — it's always kicked off un-awaited.
      if (!ref.mounted) return;
      final firebaseReady = ref.read(firebaseReadyProvider);
      if (firebaseReady) {
        if (ref.read(authServiceProvider).currentUser == null) {
          // Stays `queued` — displayed as "waiting for connection"
          // (not signed in) until the inspector signs in.
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
        if (connectivity == ConnectivityStatus.offline) {
          // Definitively offline (real device connectivity, not just a
          // proxy) — stays `queued` without ever showing `uploading`/
          // `analyzing`. A genuine request failure despite a
          // "connected"/unknown reading is still handled below by the
          // sync try/catch — this is only a fast-path for the common
          // case.
          return;
        }
        _setFindingAiStatusLocal(findingId, AiFindingStatus.uploading);
        unawaited(
          _repository.setFindingAiStatus(
            sessionId,
            findingId,
            AiFindingStatus.uploading,
          ),
        );
        try {
          final syncResult = await ref
              .read(syncCoordinatorProvider)
              .syncSession(sessionId);
          if (!syncResult.isSuccess) {
            // Offline or a transient sync failure — stays queued
            // (displayed as "waiting for connection") rather than
            // `failed`, since nothing about the classification itself
            // was actually attempted yet.
            _setFindingAiStatusLocal(findingId, AiFindingStatus.queued);
            unawaited(
              _repository.setFindingAiStatus(
                sessionId,
                findingId,
                AiFindingStatus.queued,
              ),
            );
            return;
          }
        } catch (error) {
          AppLogger.warning(
            'Evidence sync before AI classification failed',
            error,
          );
          _setFindingAiStatusLocal(findingId, AiFindingStatus.queued);
          unawaited(
            _repository.setFindingAiStatus(
              sessionId,
              findingId,
              AiFindingStatus.queued,
            ),
          );
          return;
        }
      }

      _setFindingAiStatusLocal(findingId, AiFindingStatus.analyzing);
      unawaited(
        _repository.setFindingAiStatus(
          sessionId,
          findingId,
          AiFindingStatus.analyzing,
        ),
      );

      await ref
          .read(aiClassificationCoordinatorProvider)
          .classifyFinding(sessionId, findingId, aiLevel: aiLevel);

      if (!ref.mounted) return;
      // Reload from the durable store rather than patching in-memory
      // fields by hand — the coordinator already persisted the
      // suggestion/status; this just brings this notifier's mirror
      // back in sync with it. Only if this is still the active session
      // (the inspector may have navigated away/opened another session
      // while this was in flight).
      if (state?.id == sessionId) {
        final reloaded = await _repository.loadSession(sessionId);
        if (ref.mounted && state?.id == sessionId) {
          state = reloaded;
          ref.invalidate(sessionSummariesProvider);
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
      _setFindingAiStatusLocal(findingId, AiFindingStatus.failed);
      unawaited(
        _repository.setFindingAiStatus(
          sessionId,
          findingId,
          AiFindingStatus.failed,
        ),
      );
    } finally {
      _classifyingFindingIds.remove(findingId);
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
    final reviewProgress = AiReviewProgress.forSuggestions(suggestions);
    final allResolved = reviewProgress.pending == 0;

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

    final reviewProgress = AiReviewProgress.forSuggestions(suggestions);
    final allResolved = reviewProgress.pending == 0;
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

  /// Records the Auto Analyse preference for this inspection — never
  /// inferred from wallet/House Pass state; see
  /// `InspectionSession.autoAnalyseEnabled`, docs/commercial_model.md.
  void setAutoAnalyseEnabled(bool enabled) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(
      autoAnalyseEnabled: enabled,
      updatedAt: DateTime.now(),
    );
    unawaited(
      _persist(
        () => _repository.setAutoAnalyseEnabled(session.id, enabled),
        previous: session,
        action: 'update Auto Analyse preference',
      ),
    );
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
