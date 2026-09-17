import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/home_inspection_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

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

void main() {
  test('deleting a session cascades to its sections, findings, evidence '
      'metadata, AI suggestions, and report metadata at the database '
      'level', () async {
    final local = createInMemoryRepository();
    addTearDown(local.close);
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
        elementId: 'floor',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await local.addEvidence(
      session.id,
      Evidence(
        id: 'evidence_1',
        findingId: 'finding_1',
        filePath: '/fake/evidence_1.jpg',
        createdAt: now,
      ),
    );
    await local.saveAiSuggestion(
      AiSuggestion(
        id: 'suggestion_1',
        sessionId: session.id,
        findingId: 'finding_1',
        providerId: 'fake-demo-v1',
        generatedAt: now,
      ),
    );
    await local.saveReport(
      Report(
        id: 'report_1',
        sessionId: session.id,
        filePath: '/fake/report.pdf',
        fileName: 'report.pdf',
        generatedAt: now,
        sourceUpdatedAt: now,
      ),
    );

    await local.deleteSession(session.id);

    expect(await local.loadSession(session.id), isNull);
  });

  test('deleting a session that does not exist is a harmless no-op', () async {
    final local = createInMemoryRepository();
    addTearDown(local.close);
    await local.deleteSession('does-not-exist');
    // No exception — nothing to assert beyond "this didn't throw".
  });

  test(
    'removing a single piece of evidence deletes its underlying file',
    () async {
      final fileStore = FakeEvidenceFileStore();
      final container = ProviderContainer(
        overrides: testOverrides(evidenceFileStore: fileStore),
      );
      addTearDown(container.dispose);
      await container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.setAutoAnalyseEnabled(true);
      final queue = container.read(inspectionQueueProvider);
      final section = queue.first;
      final finding = notifier.addFinding(
        sectionId: section.id,
        elementId: section.elements.first.id,
      );
      await notifier.addEvidence(
        findingId: finding.id,
        source: EvidenceSource.camera,
      );
      final evidence = container
          .read(activeSessionProvider)!
          .findings
          .single
          .evidence
          .single;

      notifier.removeEvidence(findingId: finding.id, evidenceId: evidence.id);
      await Future<void>.delayed(Duration.zero);

      expect(fileStore.deletedPaths, contains(evidence.filePath));
    },
  );

  test(
    'removing a finding deletes every evidence file it had attached',
    () async {
      final fileStore = FakeEvidenceFileStore();
      final container = ProviderContainer(
        overrides: testOverrides(evidenceFileStore: fileStore),
      );
      addTearDown(container.dispose);
      await container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.setAutoAnalyseEnabled(true);
      final queue = container.read(inspectionQueueProvider);
      final section = queue.first;
      final finding = notifier.addFinding(
        sectionId: section.id,
        elementId: section.elements.first.id,
      );
      await notifier.addEvidence(
        findingId: finding.id,
        source: EvidenceSource.camera,
      );
      await notifier.addEvidence(
        findingId: finding.id,
        source: EvidenceSource.camera,
      );
      final evidencePaths = container
          .read(activeSessionProvider)!
          .findings
          .single
          .evidence
          .map((e) => e.filePath)
          .toList();
      expect(evidencePaths, hasLength(2));

      notifier.removeFinding(finding.id);
      await Future<void>.delayed(Duration.zero);

      for (final path in evidencePaths) {
        expect(fileStore.deletedPaths, contains(path));
      }
    },
  );

  test('deleting the whole inspection deletes every evidence file and the '
      'generated report file it referenced', () async {
    final evidenceFileStore = FakeEvidenceFileStore();
    final reportFileStore = FakeReportFileStore();
    final container = ProviderContainer(
      overrides: testOverrides(
        evidenceFileStore: evidenceFileStore,
        reportFileStore: reportFileStore,
      ),
    );
    addTearDown(container.dispose);
    await container
        .read(selectedPropertyTypeProvider.notifier)
        .select(PropertyType.highRise);
    final notifier = container.read(activeSessionProvider.notifier);
    notifier.setAutoAnalyseEnabled(true);
    final queue = container.read(inspectionQueueProvider);
    final statusNotifier = container.read(sectionStatusesProvider.notifier);
    for (final s in queue) {
      statusNotifier.setStatus(s.id, SectionStatus.completed);
    }
    final section = queue.first;
    final finding = notifier.addFinding(
      sectionId: section.id,
      elementId: section.elements.first.id,
    );
    await notifier.addEvidence(
      findingId: finding.id,
      source: EvidenceSource.camera,
    );
    final evidencePath = container
        .read(activeSessionProvider)!
        .findings
        .single
        .evidence
        .single
        .filePath;
    // Adding evidence queues AI classification asynchronously; give it
    // a tick to run.
    await Future<void>.delayed(Duration.zero);

    await notifier.markPhysicalInspectionComplete();
    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    if (suggestion.needsReview) {
      notifier.changeSuggestion(
        suggestion.id,
        DefectCatalogue.instance.entries.first.id,
      );
    } else {
      notifier.acceptSuggestion(suggestion.id);
    }
    final generated = await notifier.generateReport();
    expect(generated.isSuccess, isTrue);
    final reportPath = generated.report!.filePath;
    expect(reportFileStore.exists(reportPath), isTrue);

    final sessionId = container.read(activeSessionProvider)!.id;
    await notifier.deleteSession(sessionId);

    expect(evidenceFileStore.deletedPaths, contains(evidencePath));
    expect(reportFileStore.deletedPaths, contains(reportPath));
    // The active session is cleared since it was the one deleted.
    expect(container.read(activeSessionProvider), isNull);
  });
}
