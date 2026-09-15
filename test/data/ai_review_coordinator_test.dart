import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/ai/default_ai_review_coordinator.dart';
import 'package:prodefact/data/ai/fake_ai_inspection_service.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';

import '../support/test_repository.dart';

/// Always throws — simulates an AI backend failure without any network
/// access.
class _ThrowingAiInspectionService implements AiInspectionService {
  @override
  Future<AiAnalysisResponse> analyze(AiAnalysisRequest request) {
    throw Exception('simulated AI backend failure');
  }
}

Section _bathroomSection() {
  return const Section(
    id: 'master_bathroom',
    name: 'Master Bathroom',
    isPlumbing: true,
    elements: [
      InspectionElement(
        id: 'floor',
        name: 'Floor',
        components: [Component(id: 'floor_tile', name: 'Floor tile')],
      ),
    ],
  );
}

Future<Finding> _addFinding(
  DriftInspectionRepository repository,
  String sessionId, {
  String id = 'finding_1',
  String? description = 'Cracked tile near the drain',
}) async {
  final now = DateTime.now();
  final finding = Finding(
    id: id,
    sectionId: 'master_bathroom',
    elementId: 'floor',
    componentId: 'floor_tile',
    description: description,
    createdAt: now,
    updatedAt: now,
  );
  await repository.saveFinding(sessionId, finding);
  return finding;
}

void main() {
  late DriftInspectionRepository local;

  setUp(() {
    local = createInMemoryRepository();
  });

  tearDown(() => local.close());

  test(
    'AI cannot run before physical inspection completion (the gate)',
    () async {
      final session = await local.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_bathroomSection()],
      );
      await _addFinding(local, session.id);
      final coordinator = DefaultAiReviewCoordinator(
        localRepository: local,
        aiService: FakeAiInspectionService(),
      );

      final result = await coordinator.runAnalysis(session.id);

      expect(result.outcome, AiAnalysisOutcome.notReady);
      final reloaded = await local.loadSession(session.id);
      expect(reloaded!.aiSuggestions, isEmpty);
      expect(reloaded.aiReviewState, AiReviewState.notStarted);
    },
  );

  test('AI can run once physical inspection is complete', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    await _addFinding(local, session.id);
    await local.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    final coordinator = DefaultAiReviewCoordinator(
      localRepository: local,
      aiService: FakeAiInspectionService(),
    );

    final result = await coordinator.runAnalysis(session.id);

    expect(result.isSuccess, isTrue);
    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.aiReviewState, AiReviewState.readyForReview);
    expect(reloaded.aiSuggestions, hasLength(1));
  });

  test('the fake AI produces a structured suggestion referencing the '
      'correct session/finding, with original output persisted', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    final finding = await _addFinding(local, session.id);
    await local.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    final coordinator = DefaultAiReviewCoordinator(
      localRepository: local,
      aiService: FakeAiInspectionService(),
    );

    await coordinator.runAnalysis(session.id);

    final reloaded = await local.loadSession(session.id);
    final suggestion = reloaded!.aiSuggestions.single;
    expect(suggestion.sessionId, session.id);
    expect(suggestion.findingId, finding.id);
    expect(suggestion.providerId, FakeAiInspectionService.providerId);
    expect(suggestion.suggestedDefectType, 'Cracked/loose floor tile');
    expect(
      suggestion.suggestedRecommendation,
      'Replace the affected tile(s) and reseal grout lines.',
    );
    expect(suggestion.status, AiSuggestionStatus.pending);
    // Notes mention the plumbing area, since Master Bathroom is one.
    expect(suggestion.suggestedNotes, contains('Plumbing-related area'));
  });

  test('a missing session reports sessionNotFound', () async {
    final coordinator = DefaultAiReviewCoordinator(
      localRepository: local,
      aiService: FakeAiInspectionService(),
    );
    final result = await coordinator.runAnalysis('does-not-exist');
    expect(result.outcome, AiAnalysisOutcome.sessionNotFound);
  });

  test('a failed analysis preserves all physical inspection data and marks '
      'the session failed', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    await _addFinding(local, session.id, description: 'Original finding');
    await local.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    final coordinator = DefaultAiReviewCoordinator(
      localRepository: local,
      aiService: _ThrowingAiInspectionService(),
    );

    final result = await coordinator.runAnalysis(session.id);

    expect(result.outcome, AiAnalysisOutcome.failure);
    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.aiReviewState, AiReviewState.failed);
    expect(reloaded.aiSuggestions, isEmpty);
    // Physical inspection data itself is completely untouched.
    expect(reloaded.findings, hasLength(1));
    expect(reloaded.findings.single.description, 'Original finding');
  });

  test('a failed analysis can be retried and then succeeds, without '
      'duplicating suggestions', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    await _addFinding(local, session.id, id: 'finding_1');
    await _addFinding(local, session.id, id: 'finding_2');
    await local.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );

    final failingCoordinator = DefaultAiReviewCoordinator(
      localRepository: local,
      aiService: _ThrowingAiInspectionService(),
    );
    final firstAttempt = await failingCoordinator.runAnalysis(session.id);
    expect(firstAttempt.isSuccess, isFalse);

    final workingCoordinator = DefaultAiReviewCoordinator(
      localRepository: local,
      aiService: FakeAiInspectionService(),
    );
    final secondAttempt = await workingCoordinator.runAnalysis(session.id);
    expect(secondAttempt.isSuccess, isTrue);

    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.aiReviewState, AiReviewState.readyForReview);
    // Exactly one suggestion per finding — the failed attempt saved
    // nothing, so the retry has nothing to duplicate.
    expect(reloaded.aiSuggestions, hasLength(2));
    expect(reloaded.aiSuggestions.map((s) => s.findingId).toSet(), {
      'finding_1',
      'finding_2',
    });
  });

  test('calling runAnalysis again once review is underway does not '
      'regenerate suggestions (idempotent, no duplicates)', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    await _addFinding(local, session.id);
    await local.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    final coordinator = DefaultAiReviewCoordinator(
      localRepository: local,
      aiService: FakeAiInspectionService(),
    );

    final first = await coordinator.runAnalysis(session.id);
    expect(first.isSuccess, isTrue);
    final second = await coordinator.runAnalysis(session.id);
    expect(second.outcome, AiAnalysisOutcome.alreadyReviewed);

    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.aiSuggestions, hasLength(1));
  });
}
