import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';
import 'package:prodefact/data/report/default_report_coordinator.dart';

import '../support/fake_report_services.dart';
import '../support/test_repository.dart';

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

/// A camera-first finding (has evidence, so it's AI-eligible) whose AI
/// classification has completed and been accepted by the inspector.
Future<Finding> _addResolvedFinding(
  DriftInspectionRepository local,
  String sessionId, {
  String findingId = 'finding_1',
}) async {
  final now = DateTime.now();
  final finding = Finding(
    id: findingId,
    sectionId: 'master_bathroom',
    description: 'Cracked tile',
    aiStatus: AiFindingStatus.completed,
    createdAt: now,
    updatedAt: now,
  );
  await local.saveFinding(sessionId, finding);
  await local.addEvidence(
    sessionId,
    Evidence(
      id: '${findingId}_evidence',
      findingId: findingId,
      filePath: '/fake/$findingId.jpg',
      createdAt: now,
    ),
  );
  final entryId = DefectCatalogue.instance.entries.first.id;
  await local.saveAiSuggestion(
    AiSuggestion(
      id: 'suggestion_for_$findingId',
      sessionId: sessionId,
      findingId: findingId,
      providerId: 'fake-demo-v1',
      generatedAt: now,
      suggestedCatalogueEntryId: entryId,
      finalCatalogueEntryId: entryId,
      status: AiSuggestionStatus.accepted,
      reviewedAt: now,
    ),
  );
  return finding;
}

/// A camera-first finding with evidence but no AI suggestion yet — used
/// to exercise the "AI review incomplete" gate.
Future<Finding> _addUnprocessedFinding(
  DriftInspectionRepository local,
  String sessionId, {
  String findingId = 'finding_1',
}) async {
  final now = DateTime.now();
  final finding = Finding(
    id: findingId,
    sectionId: 'master_bathroom',
    createdAt: now,
    updatedAt: now,
  );
  await local.saveFinding(sessionId, finding);
  await local.addEvidence(
    sessionId,
    Evidence(
      id: '${findingId}_evidence',
      findingId: findingId,
      filePath: '/fake/$findingId.jpg',
      createdAt: now,
    ),
  );
  return finding;
}

void main() {
  late DriftInspectionRepository local;
  late FakeReportRenderer renderer;
  late FakeReportFileStore fileStore;
  late DefaultReportCoordinator coordinator;

  setUp(() {
    local = createInMemoryRepository();
    renderer = FakeReportRenderer();
    fileStore = FakeReportFileStore();
    coordinator = DefaultReportCoordinator(
      localRepository: local,
      renderer: renderer,
      fileStore: fileStore,
    );
  });

  tearDown(() => local.close());

  test(
    'report cannot generate before physical inspection completion',
    () async {
      final session = await local.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: [_bathroomSection()],
      );

      final result = await coordinator.generateReport(
        session.id,
        propertyTypeLabel: 'High Rise',
      );

      expect(
        result.outcome,
        ReportGenerationOutcome.physicalInspectionIncomplete,
      );
      expect(renderer.renderCalls, 0);
      final reloaded = await local.loadSession(session.id);
      expect(reloaded!.report, isNull);
    },
  );

  test('report cannot generate while AI review is incomplete', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    await local.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    // A camera-first finding (with a photo) exists, but AI has not
    // processed it at all yet — still `notQueued`/no suggestion.
    await _addUnprocessedFinding(local, session.id);

    final result = await coordinator.generateReport(
      session.id,
      propertyTypeLabel: 'High Rise',
    );

    expect(result.outcome, ReportGenerationOutcome.aiReviewIncomplete);
    expect(renderer.renderCalls, 0);
  });

  test('report cannot generate while a suggestion remains pending, even if '
      'aiReviewState is otherwise advanced', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
    );
    await local.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    final finding = await _addUnprocessedFinding(local, session.id);
    await local.setFindingAiStatus(
      session.id,
      finding.id,
      AiFindingStatus.completed,
    );
    await local.saveAiSuggestion(
      AiSuggestion(
        id: 'suggestion_1',
        sessionId: session.id,
        findingId: finding.id,
        providerId: 'fake-demo-v1',
        generatedAt: DateTime.now(),
        suggestedCatalogueEntryId: DefectCatalogue.instance.entries.first.id,
      ), // still pending — no final entry, no review
    );
    await local.setAiReviewState(session.id, AiReviewState.readyForReview);

    final result = await coordinator.generateReport(
      session.id,
      propertyTypeLabel: 'High Rise',
    );

    expect(result.outcome, ReportGenerationOutcome.aiReviewIncomplete);
  });

  test('report can generate once physical inspection and AI review are both '
      'complete', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
      propertyDetails: const PropertyDetails(
        contactNumber: '+60123456789',
      ),
    );
    await _addResolvedFinding(local, session.id);
    await local.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    await local.setAiReviewState(session.id, AiReviewState.completed);

    final result = await coordinator.generateReport(
      session.id,
      propertyTypeLabel: 'High Rise',
    );

    expect(result.isSuccess, isTrue);
    expect(renderer.renderCalls, 1);
    expect(fileStore.exists(result.report!.filePath), isTrue);

    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.report, isNotNull);
    expect(reloaded.report!.sessionId, session.id);
  });

  test('a missing session reports sessionNotFound', () async {
    final result = await coordinator.generateReport(
      'does-not-exist',
      propertyTypeLabel: 'High Rise',
    );
    expect(result.outcome, ReportGenerationOutcome.sessionNotFound);
  });

  test('a render failure surfaces as failure and leaves inspection data '
      'untouched', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
      propertyDetails: const PropertyDetails(
        contactNumber: '+60123456789',
      ),
    );
    await _addResolvedFinding(local, session.id);
    await local.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    await local.setAiReviewState(session.id, AiReviewState.completed);
    renderer.failNextRenderWith = Exception('render boom');

    final result = await coordinator.generateReport(
      session.id,
      propertyTypeLabel: 'High Rise',
    );

    expect(result.outcome, ReportGenerationOutcome.failure);
    expect(result.message, contains('render boom'));

    final reloaded = await local.loadSession(session.id);
    expect(reloaded!.report, isNull);
    // The finding is completely unaffected by the failed report run.
    expect(reloaded.findings, hasLength(1));
    expect(reloaded.findings.single.description, 'Cracked tile');
  });

  test('regeneration replaces the previous report metadata and deletes the '
      'old file — "latest report per inspection"', () async {
    final session = await local.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
      propertyDetails: const PropertyDetails(
        contactNumber: '+60123456789',
      ),
    );
    await _addResolvedFinding(local, session.id);
    await local.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    await local.setAiReviewState(session.id, AiReviewState.completed);

    final first = await coordinator.generateReport(
      session.id,
      propertyTypeLabel: 'High Rise',
    );
    expect(first.isSuccess, isTrue);
    final firstPath = first.report!.filePath;

    // Simulate the underlying data changing, forcing a different
    // filename (a new day) so the coordinator must clean up the old
    // file rather than leaving it behind as an orphan.
    final secondCoordinator = DefaultReportCoordinator(
      localRepository: local,
      renderer: renderer,
      fileStore: fileStore,
    );
    await local.saveFinding(
      session.id,
      (await local.loadSession(session.id))!.findings.single.copyWith(
        notes: 'updated',
        updatedAt: DateTime.now().add(const Duration(days: 1)),
      ),
    );
    final second = await secondCoordinator.generateReport(
      session.id,
      propertyTypeLabel: 'High Rise',
    );

    expect(second.isSuccess, isTrue);
    final reloaded = await local.loadSession(session.id);
    // Exactly one report row for this session — never accumulates.
    expect(reloaded!.report, isNotNull);
    expect(reloaded.report!.id, second.report!.id);
    if (firstPath != second.report!.filePath) {
      expect(fileStore.deletedPaths, contains(firstPath));
      expect(fileStore.exists(firstPath), isFalse);
    }
  });

  test('a generated report survives a fresh repository instance (simulated '
      'app restart)', () async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    addTearDown(
      () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = false,
    );

    final tempDir = await Directory.systemTemp.createTemp(
      'prodefact_report_test',
    );
    addTearDown(() => tempDir.delete(recursive: true));
    final dbFile = File(p.join(tempDir.path, 'test.sqlite'));

    final firstRepository = DriftInspectionRepository(
      AppDatabase(NativeDatabase(dbFile)),
    );
    final session = await firstRepository.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: [_bathroomSection()],
      propertyDetails: const PropertyDetails(
        contactNumber: '+60123456789',
      ),
    );
    await _addResolvedFinding(firstRepository, session.id);
    await firstRepository.setSessionStatus(
      session.id,
      InspectionStatus.physicalInspectionComplete,
    );
    await firstRepository.setAiReviewState(session.id, AiReviewState.completed);
    final firstCoordinator = DefaultReportCoordinator(
      localRepository: firstRepository,
      renderer: renderer,
      fileStore: fileStore,
    );
    final generated = await firstCoordinator.generateReport(
      session.id,
      propertyTypeLabel: 'High Rise',
    );
    expect(generated.isSuccess, isTrue);
    await firstRepository.close();

    final secondRepository = DriftInspectionRepository(
      AppDatabase(NativeDatabase(dbFile)),
    );
    addTearDown(secondRepository.close);

    final reloaded = await secondRepository.loadSession(session.id);
    expect(reloaded!.report, isNotNull);
    expect(reloaded.report!.fileName, generated.report!.fileName);
  });
}
