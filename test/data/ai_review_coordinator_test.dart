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
  Future<AiFindingClassification> classifyFinding(
    AiFindingClassificationRequest request,
  ) {
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

/// A camera-first finding with one photo — the only kind of finding
/// progressive AI classification ever acts on (`Finding.isAiEligible`).
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
    description: description,
    createdAt: now,
    updatedAt: now,
  );
  await repository.saveFinding(sessionId, finding);
  await repository.addEvidence(
    sessionId,
    Evidence(
      id: '${id}_evidence',
      findingId: id,
      filePath: '/fake/$id.jpg',
      createdAt: now,
    ),
  );
  return finding;
}

void main() {
  late DriftInspectionRepository local;

  setUp(() {
    local = createInMemoryRepository();
  });

  tearDown(() => local.close());

  test('classifying a finding with no evidence reports noEvidence', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    final now = DateTime.now();
    await local.saveFinding(
      session.id,
      Finding(
        id: 'finding_1',
        sectionId: 'master_bathroom',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final coordinator = DefaultAiClassificationCoordinator(
      localRepository: local,
      aiService: FakeAiInspectionService(),
    );

    final result = await coordinator.classifyFinding(session.id, 'finding_1');

    expect(result.outcome, AiClassificationOutcome.noEvidence);
    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.aiSuggestions, isEmpty);
  });

  test('classifying an eligible finding succeeds and persists a '
      'suggestion', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    await _addFinding(local, session.id);
    final coordinator = DefaultAiClassificationCoordinator(
      localRepository: local,
      aiService: FakeAiInspectionService(),
    );

    final result = await coordinator.classifyFinding(session.id, 'finding_1');

    expect(result.isSuccess, isTrue);
    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.aiSuggestions, hasLength(1));
    expect(
      reloaded.findings.single.aiStatus,
      anyOf(AiFindingStatus.completed, AiFindingStatus.needsReview),
    );
  });

  test(
    'the fake AI produces a suggestion referencing the correct '
    'session/finding, resolved against the real controlled catalogue',
    () async {
      final session = await local.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_bathroomSection()],
      );
      final finding = await _addFinding(local, session.id);
      final coordinator = DefaultAiClassificationCoordinator(
        localRepository: local,
        aiService: FakeAiInspectionService(),
      );

      await coordinator.classifyFinding(session.id, finding.id);

      final reloaded = await local.loadSession(session.id);
      final suggestion = reloaded!.aiSuggestions.single;
      expect(suggestion.sessionId, session.id);
      expect(suggestion.findingId, finding.id);
      expect(suggestion.providerId, isNotEmpty);
      expect(suggestion.status, AiSuggestionStatus.pending);
      // "Master Bathroom" (a plumbing area) deterministically matches the
      // fake AI's sanitary_fitting keyword — a genuinely valid catalogue
      // entry, never a fabricated one.
      expect(suggestion.suggestedCatalogueEntryId, isNotNull);
      expect(
        DefectCatalogue.instance.isValidEntryId(
          suggestion.suggestedCatalogueEntryId!,
        ),
        isTrue,
      );
    },
  );

  test('a missing session reports sessionNotFound', () async {
    final coordinator = DefaultAiClassificationCoordinator(
      localRepository: local,
      aiService: FakeAiInspectionService(),
    );
    final result = await coordinator.classifyFinding(
      'does-not-exist',
      'finding_1',
    );
    expect(result.outcome, AiClassificationOutcome.sessionNotFound);
  });

  test('a missing finding reports findingNotFound', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    final coordinator = DefaultAiClassificationCoordinator(
      localRepository: local,
      aiService: FakeAiInspectionService(),
    );
    final result = await coordinator.classifyFinding(
      session.id,
      'does-not-exist',
    );
    expect(result.outcome, AiClassificationOutcome.findingNotFound);
  });

  test('a failed classification preserves all physical inspection data '
      'and marks the finding failed', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    await _addFinding(local, session.id, description: 'Original finding');
    final coordinator = DefaultAiClassificationCoordinator(
      localRepository: local,
      aiService: _ThrowingAiInspectionService(),
    );

    final result = await coordinator.classifyFinding(session.id, 'finding_1');

    expect(result.outcome, AiClassificationOutcome.failure);
    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.aiSuggestions, isEmpty);
    expect(reloaded.findings.single.aiStatus, AiFindingStatus.failed);
    // Physical inspection data itself is completely untouched.
    expect(reloaded.findings, hasLength(1));
    expect(reloaded.findings.single.description, 'Original finding');
  });

  test('a failed classification can be retried and then succeeds, '
      'without duplicating suggestions (idempotent retry)', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    await _addFinding(local, session.id);

    final failingCoordinator = DefaultAiClassificationCoordinator(
      localRepository: local,
      aiService: _ThrowingAiInspectionService(),
    );
    final firstAttempt = await failingCoordinator.classifyFinding(
      session.id,
      'finding_1',
    );
    expect(firstAttempt.isSuccess, isFalse);

    final workingCoordinator = DefaultAiClassificationCoordinator(
      localRepository: local,
      aiService: FakeAiInspectionService(),
    );
    final secondAttempt = await workingCoordinator.classifyFinding(
      session.id,
      'finding_1',
    );
    expect(secondAttempt.isSuccess, isTrue);

    final reloaded = await local.loadSession(session.id);
    // Exactly one suggestion — the failed attempt saved nothing, and
    // the suggestion id is deterministic (keyed by findingId), so the
    // retry upserts rather than duplicating.
    expect(reloaded!.aiSuggestions, hasLength(1));
  });

  test('classifying an already-completed finding again does not '
      'duplicate/re-run (idempotent, no duplicates)', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    await _addFinding(local, session.id);
    final coordinator = DefaultAiClassificationCoordinator(
      localRepository: local,
      aiService: FakeAiInspectionService(),
    );

    final first = await coordinator.classifyFinding(session.id, 'finding_1');
    expect(first.isSuccess, isTrue);
    final second = await coordinator.classifyFinding(session.id, 'finding_1');
    expect(second.outcome, AiClassificationOutcome.alreadyInFlight);

    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.aiSuggestions, hasLength(1));
  });
}
