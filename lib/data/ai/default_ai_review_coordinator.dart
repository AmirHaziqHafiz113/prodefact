import 'package:collection/collection.dart';

import '../../core/inspection/inspection_domain.dart';

/// Orchestrates one finding's progressive AI classification: enforces
/// idempotency (never two concurrent runs for the same finding, never
/// re-classifying a finding that's already terminal), builds the
/// structured request from local data, calls the AI backend, validates
/// its response against the controlled catalogue, and persists the
/// result — all through the same [InspectionRepository] every other
/// write in the app goes through, so physical inspection data is never
/// at risk from an AI failure.
///
/// Unlike the old whole-session batch coordinator, there is no "AI
/// timing gate" here at all — this runs the moment it's called
/// (immediately after a finding is saved with a photo), independent of
/// whether the rest of the physical inspection is complete. See
/// `docs/ai_provider_architecture.md`.
class DefaultAiClassificationCoordinator
    implements AiClassificationCoordinator {
  DefaultAiClassificationCoordinator({
    required InspectionRepository localRepository,
    required AiInspectionService aiService,
  }) : _local = localRepository,
       _ai = aiService;

  final InspectionRepository _local;
  final AiInspectionService _ai;

  /// Guards against two concurrent `classifyFinding` calls for the
  /// same finding racing each other — e.g. a retry triggered while a
  /// previous attempt is still in flight. Per-coordinator-instance,
  /// sufficient since the app only ever holds one via
  /// `aiClassificationCoordinatorProvider`.
  final Set<String> _inFlight = {};

  /// Deterministic, not timestamp-based: a retry for the same finding
  /// always resolves to the same suggestion row (upsert), so a retry
  /// after a partial failure can never create a second, duplicate
  /// suggestion for one finding.
  String _suggestionIdFor(String findingId) => 'suggestion_$findingId';

  @override
  Future<AiClassificationResult> classifyFinding(
    String sessionId,
    String findingId,
  ) async {
    final key = '$sessionId/$findingId';
    if (!_inFlight.add(key)) {
      return const AiClassificationResult.alreadyInFlight();
    }
    try {
      return await _classifyFinding(sessionId, findingId);
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<AiClassificationResult> _classifyFinding(
    String sessionId,
    String findingId,
  ) async {
    final session = await _local.loadSession(sessionId);
    if (session == null) return const AiClassificationResult.sessionNotFound();

    final finding = session.findings.firstWhereOrNull((f) => f.id == findingId);
    if (finding == null) return const AiClassificationResult.findingNotFound();
    if (!finding.isAiEligible) return const AiClassificationResult.noEvidence();

    // Already settled — never re-run over an inspector's in-progress
    // review of an existing suggestion. A caller wanting a retry after
    // `failed` should still reach here (failed is not terminal-safe in
    // the sense of blocking retry) — only completed/needsReview (which
    // already has a suggestion row for the inspector to act on) block.
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

    final AiFindingClassification classification;
    try {
      classification = await _ai.classifyFinding(request);
    } catch (error) {
      await _local.setFindingAiStatus(
        session.id,
        finding.id,
        AiFindingStatus.failed,
      );
      return AiClassificationResult.failure(error.toString());
    }

    // Defense in depth: never trust a catalogue id at face value, even
    // though the backend gateway already validated it — a fake/local
    // provider or a future bug shouldn't be able to persist a
    // hallucinated id either.
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
        // A confident match starts out as its own final value —
        // Accept keeps it; Change/Reject replace it later. A
        // needs-review finding starts with no final value at all;
        // the inspector must pick one via the catalogue picker.
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
