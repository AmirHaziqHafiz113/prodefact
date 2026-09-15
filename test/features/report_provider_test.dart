import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/home_inspection_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/fake_report_services.dart';
import '../support/test_repository.dart';

void main() {
  test(
    'report generation is refused before physical inspection is complete',
    () async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      await container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);

      final result = await container
          .read(activeSessionProvider.notifier)
          .generateReport();

      expect(
        result.outcome,
        ReportGenerationOutcome.physicalInspectionIncomplete,
      );
      expect(container.read(activeSessionProvider)!.report, isNull);
    },
  );

  test('report generation is refused while AI review is incomplete, and '
      'becomes available once every suggestion is resolved', () async {
    final renderer = FakeReportRenderer();
    final fileStore = FakeReportFileStore();
    final container = ProviderContainer(
      overrides: testOverrides(
        reportRenderer: renderer,
        reportFileStore: fileStore,
      ),
    );
    addTearDown(container.dispose);
    await container
        .read(selectedPropertyTypeProvider.notifier)
        .select(PropertyType.highRise);

    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);
    final statusNotifier = container.read(sectionStatusesProvider.notifier);
    for (final section in queue) {
      statusNotifier.setStatus(section.id, SectionStatus.completed);
    }
    final section = queue.first;
    notifier.addFinding(
      sectionId: section.id,
      elementId: section.elements.first.id,
      description: 'Cracked tile',
    );
    await notifier.markPhysicalInspectionComplete();

    final tooEarly = await notifier.generateReport();
    expect(tooEarly.outcome, ReportGenerationOutcome.aiReviewIncomplete);
    expect(renderer.renderCalls, 0);

    await notifier.startAiAnalysis();
    final stillPending = await notifier.generateReport();
    expect(stillPending.outcome, ReportGenerationOutcome.aiReviewIncomplete);

    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    notifier.acceptSuggestion(suggestion.id);

    final result = await notifier.generateReport();
    expect(result.isSuccess, isTrue);
    expect(renderer.renderCalls, 1);

    final session = container.read(activeSessionProvider)!;
    expect(session.report, isNotNull);
    expect(fileStore.exists(session.report!.filePath), isTrue);
  });

  test('shareReport delegates to the ReportShareService abstraction', () async {
    final shareService = FakeReportShareService();
    final container = ProviderContainer(
      overrides: testOverrides(reportShareService: shareService),
    );
    addTearDown(container.dispose);
    await container
        .read(selectedPropertyTypeProvider.notifier)
        .select(PropertyType.highRise);

    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);
    final statusNotifier = container.read(sectionStatusesProvider.notifier);
    for (final section in queue) {
      statusNotifier.setStatus(section.id, SectionStatus.completed);
    }
    final section = queue.first;
    notifier.addFinding(
      sectionId: section.id,
      elementId: section.elements.first.id,
      description: 'Cracked tile',
    );
    await notifier.markPhysicalInspectionComplete();
    await notifier.startAiAnalysis();
    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    notifier.acceptSuggestion(suggestion.id);
    await notifier.generateReport();

    await notifier.shareReport();

    expect(shareService.shareCalls, hasLength(1));
    final session = container.read(activeSessionProvider)!;
    expect(shareService.shareCalls.single.filePath, session.report!.filePath);
  });

  test(
    'report generation requires no Firebase/network — succeeds with '
    'firebaseReadyProvider left at its default (unconfigured) value',
    () async {
      // testOverrides() intentionally does not touch firebaseReadyProvider,
      // authServiceProvider, or cloudInspectionRepositoryProvider — this
      // test proves report generation never depends on any of them.
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      await container
          .read(selectedPropertyTypeProvider.notifier)
          .select(PropertyType.highRise);

      final notifier = container.read(activeSessionProvider.notifier);
      final queue = container.read(inspectionQueueProvider);
      final statusNotifier = container.read(sectionStatusesProvider.notifier);
      for (final section in queue) {
        statusNotifier.setStatus(section.id, SectionStatus.completed);
      }
      final section = queue.first;
      notifier.addFinding(
        sectionId: section.id,
        elementId: section.elements.first.id,
        description: 'Cracked tile',
      );
      await notifier.markPhysicalInspectionComplete();
      await notifier.startAiAnalysis();
      final suggestion = container
          .read(activeSessionProvider)!
          .aiSuggestions
          .single;
      notifier.acceptSuggestion(suggestion.id);

      final result = await notifier.generateReport();

      expect(result.isSuccess, isTrue);
    },
  );
}
