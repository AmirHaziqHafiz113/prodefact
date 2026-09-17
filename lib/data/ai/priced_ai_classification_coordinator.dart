import 'package:collection/collection.dart';

import '../../core/inspection/inspection_domain.dart';

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
  }) : _local = localRepository,
       _billing = billingService;

  final InspectionRepository _local;
  final BillingService _billing;

  /// Guards against two concurrent `classifyFinding` calls for the
  /// same finding racing each other.
  final Set<String> _inFlight = {};

  String _suggestionIdFor(String findingId) => 'suggestion_$findingId';

  @override
  Future<AiClassificationResult> classifyFinding(
    String sessionId,
    String findingId, {
    AiLevel? aiLevel,
  }) async {
    final key = '$sessionId/$findingId';
    if (!_inFlight.add(key)) {
      return const AiClassificationResult.alreadyInFlight();
    }
    try {
      return await _classifyFinding(sessionId, findingId, aiLevel);
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<AiClassificationResult> _classifyFinding(
    String sessionId,
    String findingId,
    AiLevel? requestedLevel,
  ) async {
    final session = await _local.loadSession(sessionId);
    if (session == null) return const AiClassificationResult.sessionNotFound();

    final finding = session.findings.firstWhereOrNull((f) => f.id == findingId);
    if (finding == null) return const AiClassificationResult.findingNotFound();
    if (!finding.isAiEligible) return const AiClassificationResult.noEvidence();

    if (finding.aiStatus == AiFindingStatus.completed ||
        finding.aiStatus == AiFindingStatus.needsReview) {
      return const AiClassificationResult.alreadyInFlight();
    }

    final section = session.sections.firstWhereOrNull(
      (s) => s.id == finding.sectionId,
    );

    final request = AiFindingClassificationRequest(
      sessionId: session.id,
      findingId: finding.id,
      sectionName: section?.name ?? finding.sectionId,
      sectionIsPlumbing: section?.isPlumbing ?? false,
      note: finding.description ?? finding.notes,
      evidenceFilePaths: finding.evidence.map((e) => e.filePath).toList(),
      evidenceIds: finding.evidence.map((e) => e.id).toList(),
    );

    final aiLevel = requestedLevel ?? session.selectedAiLevel ?? AiLevel.smart;
    // A fresh key per attempt: safe to reuse across an in-flight call's
    // own transport-level hiccups (there are none at this layer — the
    // callable either succeeds or throws once), and a genuinely new
    // attempt (auto-requeue after a restart, or an explicit inspector
    // Retry) always deserves its own — never replays a stale cached
    // failure. See docs/commercial_model.md.
    final idempotencyKey =
        '${findingId}_${DateTime.now().microsecondsSinceEpoch}';

    final AiFindingClassification classification;
    try {
      final result = await _billing.analyseFinding(
        request: request,
        aiLevel: aiLevel,
        idempotencyKey: idempotencyKey,
      );
      classification = result.classification;
    } catch (error) {
      await _local.setFindingAiStatus(
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
    final needsReview = classification.needsReview || validEntryId == null;

    final now = DateTime.now();
    await _local.saveAiSuggestion(
      AiSuggestion(
        id: _suggestionIdFor(finding.id),
        sessionId: session.id,
        findingId: finding.id,
        providerId: 'ai',
        generatedAt: now,
        suggestedCatalogueEntryId: validEntryId,
        suggestedConfidence: classification.confidence,
        suggestedShortReason: classification.shortReason,
        suggestedCandidateEntryIds: validCandidates,
        finalCatalogueEntryId: validEntryId,
      ),
    );
    await _local.setFindingAiStatus(
      session.id,
      finding.id,
      needsReview ? AiFindingStatus.needsReview : AiFindingStatus.completed,
    );

    return const AiClassificationResult.success();
  }
}
