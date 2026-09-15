import 'package:collection/collection.dart';

import '../../core/inspection/inspection_domain.dart';

/// Orchestrates one AI analysis run for a session: enforces the AI
/// timing gate, builds the structured request from local data, calls
/// the AI backend, and persists suggestions — all through the same
/// [InspectionRepository] every other write in the app goes through, so
/// physical inspection data is never at risk from an AI failure.
///
/// See `docs/ai_review.md` for the full state machine and retry policy.
class DefaultAiReviewCoordinator implements AiReviewCoordinator {
  DefaultAiReviewCoordinator({
    required InspectionRepository localRepository,
    required AiInspectionService aiService,
  }) : _local = localRepository,
       _ai = aiService;

  final InspectionRepository _local;
  final AiInspectionService _ai;

  String _newId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  @override
  Future<AiAnalysisResult> runAnalysis(String sessionId) async {
    final session = await _local.loadSession(sessionId);
    if (session == null) return const AiAnalysisResult.sessionNotFound();

    // ---- the AI gate: enforced here, not just by hiding a button ----
    if (session.status == InspectionStatus.inProgress) {
      return const AiAnalysisResult.notReady();
    }

    switch (session.aiReviewState) {
      case AiReviewState.readyForReview:
      case AiReviewState.completed:
        // Suggestions already exist and review is underway/done —
        // never regenerate over an inspector's in-progress review.
        return const AiAnalysisResult.alreadyReviewed();
      case AiReviewState.notStarted:
      case AiReviewState.analyzing:
      case AiReviewState.failed:
        // `analyzing` here means a previous run was interrupted (e.g. a
        // crash) without ever reaching readyForReview/failed — safe,
        // and expected, to retry.
        break;
    }

    await _local.setAiReviewState(sessionId, AiReviewState.analyzing);

    // Only findings that don't already have a suggestion are sent —
    // this is what makes retry-after-partial-failure not duplicate
    // already-successful suggestion records.
    final alreadySuggestedFindingIds = session.aiSuggestions
        .map((s) => s.findingId)
        .toSet();
    final findingsNeedingSuggestions = session.findings
        .where((f) => !alreadySuggestedFindingIds.contains(f.id))
        .toList();

    if (findingsNeedingSuggestions.isEmpty) {
      final state = session.aiSuggestions.isEmpty
          ? AiReviewState.completed
          : AiReviewState.readyForReview;
      await _local.setAiReviewState(sessionId, state);
      return const AiAnalysisResult.success();
    }

    final request = AiAnalysisRequest(
      sessionId: session.id,
      industry: session.industry.name,
      assetTypeId: session.assetTypeId,
      findings: findingsNeedingSuggestions
          .map((finding) => _contextFor(session, finding))
          .toList(),
    );

    final AiAnalysisResponse response;
    try {
      response = await _ai.analyze(request);
    } catch (error) {
      await _local.setAiReviewState(sessionId, AiReviewState.failed);
      return AiAnalysisResult.failure(error.toString());
    }

    final now = DateTime.now();
    for (final suggestion in response.suggestions) {
      await _local.saveAiSuggestion(
        AiSuggestion(
          id: _newId('suggestion'),
          sessionId: session.id,
          findingId: suggestion.findingId,
          providerId: response.providerId,
          generatedAt: now,
          suggestedElementId: suggestion.elementId,
          suggestedComponentId: suggestion.componentId,
          suggestedDefectType: suggestion.defectType,
          suggestedRecommendation: suggestion.recommendation,
          suggestedNotes: suggestion.notes,
          // Final fields start out equal to the AI's own suggestion —
          // Accept keeps them as-is; Edit/Reject change them later.
          finalElementId: suggestion.elementId,
          finalComponentId: suggestion.componentId,
          finalDefectType: suggestion.defectType,
          finalRecommendation: suggestion.recommendation,
          finalNotes: suggestion.notes,
        ),
      );
    }

    await _local.setAiReviewState(sessionId, AiReviewState.readyForReview);
    return const AiAnalysisResult.success();
  }

  AiFindingContext _contextFor(InspectionSession session, Finding finding) {
    final section = session.sections.firstWhere(
      (s) => s.id == finding.sectionId,
      orElse: () => throw StateError(
        'Finding ${finding.id} references missing section '
        '${finding.sectionId}',
      ),
    );
    final element = section.elements.firstWhere(
      (e) => e.id == finding.elementId,
      orElse: () => throw StateError(
        'Finding ${finding.id} references missing element '
        '${finding.elementId} in section ${section.id}',
      ),
    );
    final component = finding.componentId == null
        ? null
        : element.components.firstWhereOrNull(
            (c) => c.id == finding.componentId,
          );

    return AiFindingContext(
      findingId: finding.id,
      sectionId: section.id,
      sectionName: section.name,
      sectionIsPlumbing: section.isPlumbing,
      elementId: element.id,
      elementName: element.name,
      componentId: component?.id,
      componentName: component?.name,
      description: finding.description,
      notes: finding.notes,
      evidenceFilePaths: finding.evidence.map((e) => e.filePath).toList(),
    );
  }
}
