import 'package:collection/collection.dart';

import '../../core/inspection/inspection_domain.dart';
import '../../core/logging/app_logger.dart';

/// Orchestrates one finding's progressive AI classification through
/// the **priced** protocol — this is what
/// `aiClassificationCoordinatorProvider` resolves to since the
/// commercial pass, replacing the unpriced `classifyFinding` callable
/// path `DefaultAiClassificationCoordinator` used. See
/// docs/commercial_model.md ("The estimate -> approval -> reservation
/// -> settlement protocol").
///
/// Structurally this mirrors `DefaultAiClassificationCoordinator`
/// closely (same idempotency guard, same session/finding/section
/// lookup, same catalogue-id defense-in-depth, same persistence) — the
/// only real difference is the source of the classification:
/// [BillingService.analyseFinding] (which reserves/settles real
/// Credits server-side) instead of the unpriced
/// `AiInspectionService.classifyFinding`. Both coordinator
/// implementations are kept (rather than merging them with a runtime
/// flag) so the pre-existing, unpriced `classifyFinding` callable path
/// stays intact and independently testable — see
/// `docs/ai_provider_architecture.md`.
class PricedAiClassificationCoordinator implements AiClassificationCoordinator {
  PricedAiClassificationCoordinator({
    required InspectionRepository localRepository,
    required BillingService billingService,
    DateTime Function()? clock,
  }) : _local = localRepository,
       _billing = billingService,
       _clock = clock ?? DateTime.now;

  final InspectionRepository _local;
  final BillingService _billing;
  final DateTime Function() _clock;

  /// Guards against two concurrent `classifyFinding` calls for the
  /// same finding racing each other.
  final Set<String> _inFlight = {};

  String _suggestionIdFor(String findingId) => 'suggestion_$findingId';

  @override
  Future<AiClassificationResult> classifyFinding(
    String sessionId,
    String findingId, {
    AiLevel? aiLevel,
    bool reanalyse = false,
  }) async {
    final key = '$sessionId/$findingId';
    if (!_inFlight.add(key)) {
      return const AiClassificationResult.alreadyInFlight();
    }
    try {
      return await _classifyFinding(sessionId, findingId, aiLevel, reanalyse);
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<AiClassificationResult> _classifyFinding(
    String sessionId,
    String findingId,
    AiLevel? requestedLevel,
    bool reanalyse,
  ) async {
    final session = await _local.loadSession(sessionId);
    if (session == null) return const AiClassificationResult.sessionNotFound();

    final finding = session.findings.firstWhereOrNull((f) => f.id == findingId);
    if (finding == null) return const AiClassificationResult.findingNotFound();
    if (!finding.isAiEligible) return const AiClassificationResult.noEvidence();

    // A finished finding is only analysed again on an explicit
    // inspector Reanalyse.
    if (!reanalyse &&
        (finding.aiStatus == AiFindingStatus.completed ||
            finding.aiStatus == AiFindingStatus.needsReview)) {
      return const AiClassificationResult.alreadyInFlight();
    }
    final previous = session.aiSuggestions.firstWhereOrNull(
      (s) => s.findingId == finding.id,
    );
    final reanalysisCount = reanalyse
        ? (previous?.reanalysisCount ?? 0) + 1
        : previous?.reanalysisCount ?? 0;

    final section = session.sections.firstWhereOrNull(
      (s) => s.id == finding.sectionId,
    );

    final request = AiFindingClassificationRequest(
      sessionId: session.id,
      findingId: finding.id,
      sectionName: section?.name ?? finding.sectionId,
      sectionIsPlumbing: section?.isPlumbing ?? false,
      // Verbatim (QA #17): shorthand is interpreted server-side, never
      // rewritten here.
      note: finding.defectNote,
      evidenceFilePaths: finding.evidence.map((e) => e.filePath).toList(),
      evidenceIds: finding.evidence.map((e) => e.id).toList(),
      reanalysisAttempt: reanalysisCount,
      // A Reanalyse tells the backend (safely) what the earlier,
      // unaccepted attempt said, so the second look is deliberate.
      previousAttempt: reanalyse && previous != null
          ? PreviousAttemptContext(
              needsReviewReason: previous.needsReviewReason,
              detectedComponent: previous.detectedComponent,
              selectedEntryId: previous.hasFinalEntry
                  ? previous.finalCatalogueEntryId
                  : previous.suggestedCatalogueEntryId,
            )
          : null,
    );

    // Billing identity. An outstanding attempt (persisted before an
    // earlier submission whose outcome never reached this device) is
    // always replayed with its original key and level — the backend is
    // idempotent per key, so a replay returns the stored outcome or
    // finishes the interrupted run without reserving or charging twice.
    // Only a finding with no outstanding attempt mints a fresh key.
    final now = _clock();
    final outstanding = finding.aiAttempt;
    final AiAnalysisAttempt attempt;
    if (outstanding != null) {
      if (!outstanding.isReplaySafeAt(now)) {
        // The original invocation may still be running server-side.
        AppLogger.info(
          'ai_job_deferred finding=${finding.id} '
          'retryAt=${outstanding.replaySafeAt.toIso8601String()}',
        );
        return AiClassificationResult.deferred(outstanding.replaySafeAt);
      }
      attempt = outstanding.resubmittedAt(now);
      AppLogger.info(
        'ai_job_retry finding=${finding.id} key=${attempt.idempotencyKey}',
      );
    } else {
      attempt = AiAnalysisAttempt(
        idempotencyKey: '${findingId}_${now.microsecondsSinceEpoch}',
        aiLevel: requestedLevel ?? kFieldAnalysisAiLevel,
        submittedAt: now,
      );
      AppLogger.info(
        'ai_job_created finding=${finding.id} key=${attempt.idempotencyKey} '
        'level=${attempt.aiLevel.name}',
      );
    }
    // Durable before the request leaves the device: if the app dies
    // mid-call, the restart replays this exact key.
    await _local.beginFindingAiAttempt(session.id, finding.id, attempt);

    final AiFindingClassification classification;
    try {
      AppLogger.info('ai_job_started finding=${finding.id}');
      final result = await _billing.analyseFinding(
        request: request,
        aiLevel: attempt.aiLevel,
        idempotencyKey: attempt.idempotencyKey,
      );
      classification = result.classification;
    } on AnalyseFindingException catch (error) {
      if (error.outcomeUnknown) {
        // The backend may have finished (and charged) this request. Keep
        // the attempt so the next run replays the same key; `queued`
        // lets session reload/reconnect recovery pick it up.
        AppLogger.info(
          'ai_job_outcome_unknown finding=${finding.id} '
          'key=${attempt.idempotencyKey}',
        );
        await _local.setFindingAiStatus(
          session.id,
          finding.id,
          outstanding == null ? AiFindingStatus.queued : AiFindingStatus.failed,
        );
      } else {
        AppLogger.info(
          'ai_job_failed finding=${finding.id} definitive=true error=$error',
        );
        await _local.finishFindingAiAttempt(
          session.id,
          finding.id,
          AiFindingStatus.failed,
        );
      }
      return AiClassificationResult.failure(error.toString());
    } catch (error) {
      // Not a classified backend error (e.g. the local-only fake
      // billing service rejecting for insufficient Credits): nothing
      // outstanding on any backend.
      AppLogger.info(
        'ai_job_failed finding=${finding.id} definitive=true error=$error',
      );
      await _local.finishFindingAiAttempt(
        session.id,
        finding.id,
        AiFindingStatus.failed,
      );
      return AiClassificationResult.failure(error.toString());
    }

    // Defense in depth: never trust a catalogue id at face value, even
    // though the backend gateway already validated it.
    final catalogue = DefectCatalogue.instance;
    final validEntryId =
        classification.catalogueEntryId != null &&
            catalogue.isValidEntryId(classification.catalogueEntryId!)
        ? classification.catalogueEntryId
        : null;
    final validCandidates = classification.candidateEntryIds
        .where(catalogue.isValidEntryId)
        .toList();
    // ONE concrete defect: an entry that words several defects needs a
    // valid term too (the backend enforces this; checked again here).
    final entry = validEntryId == null ? null : catalogue.byId(validEntryId);
    final defectTerm = entry == null
        ? null
        : matchDefectTerm(entry.defectDescription, classification.defectTerm);
    final missingTerm =
        entry != null &&
        defectTermsFor(entry.defectDescription).isNotEmpty &&
        defectTerm == null;
    final needsReview =
        classification.needsReview || validEntryId == null || missingTerm;

    // A finding deleted while its request was in flight must never come
    // back (as an orphan suggestion) when the answer arrives.
    final stillExists = (await _local.loadSession(session.id))?.findings
        .any((f) => f.id == finding.id);
    if (stillExists != true) {
      AppLogger.info('ai_result_discarded finding=${finding.id} deleted=true');
      return const AiClassificationResult.findingNotFound();
    }

    // A confident, valid catalogue match is accepted automatically —
    // report-ready without a tap. The inspector can still Change or
    // Reject it in AI Review. Anything uncertain stays pending.
    await _local.saveAiSuggestion(
      AiSuggestion(
        id: _suggestionIdFor(finding.id),
        sessionId: session.id,
        findingId: finding.id,
        providerId: 'ai',
        generatedAt: _clock(),
        suggestedCatalogueEntryId: validEntryId,
        suggestedConfidence: classification.confidence,
        suggestedShortReason: classification.shortReason,
        suggestedCandidateEntryIds: validCandidates,
        suggestedDefectTerm: defectTerm,
        isRelevantInspectionImage: classification.isRelevantInspectionImage,
        imageUsable: classification.imageUsable,
        qualityIssues: classification.qualityIssues,
        needsReviewReason: needsReview
            ? classification.needsReviewReason ??
                  (missingTerm ? 'ambiguous_candidates' : null)
            : null,
        noteImageAgreement: classification.noteImageAgreement,
        detectedComponent: classification.detectedComponent,
        aiLevel: attempt.aiLevel.name,
        aiJobKey: attempt.idempotencyKey,
        reanalysisCount: reanalysisCount,
        // The result being replaced is kept, so corrections and
        // reanalysis can be evaluated later.
        history: [
          ...?previous?.history,
          if (previous != null) previous.toHistoryEntry(),
        ],
        finalCatalogueEntryId: validEntryId,
        status: needsReview
            ? AiSuggestionStatus.pending
            : AiSuggestionStatus.accepted,
      ),
    );
    await _local.finishFindingAiAttempt(
      session.id,
      finding.id,
      needsReview ? AiFindingStatus.needsReview : AiFindingStatus.completed,
    );
    AppLogger.info(
      'result_saved finding=${finding.id} level=${attempt.aiLevel.name} '
      'reanalysis=$reanalysisCount '
      'needsReview=$needsReview hasTerm=${defectTerm != null}',
    );

    return const AiClassificationResult.success();
  }
}
