import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/home_inspection_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/fake_report_services.dart';
import '../support/test_repository.dart';

/// Resolves whatever suggestion is pending on the active session,
/// tolerating either a confident (`accept`) or `needsReview`
/// (`changeSuggestion`) classification from the fake AI.
void _resolvePendingSuggestion(
  ProviderContainer container,
  ActiveInspectionSession notifier,
) {
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
}

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
    notifier.setAutoAnalyseEnabled(true);
    final queue = container.read(inspectionQueueProvider);
    final statusNotifier = container.read(sectionStatusesProvider.notifier);
    for (final section in queue) {
      statusNotifier.setStatus(section.id, SectionStatus.completed);
    }

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: queue.first.id,
      photo: photo!,
      note: 'Cracked tile',
    );
    await notifier.markPhysicalInspectionComplete();

    final tooEarly = await notifier.generateReport();
    expect(tooEarly.outcome, ReportGenerationOutcome.aiReviewIncomplete);
    expect(renderer.renderCalls, 0);

    // AI classification is queued asynchronously on save; give it a
    // tick, then it's still pending review.
    await Future<void>.delayed(Duration.zero);
    final stillPending = await notifier.generateReport();
    expect(stillPending.outcome, ReportGenerationOutcome.aiReviewIncomplete);

    _resolvePendingSuggestion(container, notifier);
    notifier.setReportMetadata(
      const ReportMetadata(
        title: 'Test Property',
        contactNumber: '+60123456789',
      ),
    );

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
    notifier.setAutoAnalyseEnabled(true);
    final queue = container.read(inspectionQueueProvider);
    final statusNotifier = container.read(sectionStatusesProvider.notifier);
    for (final section in queue) {
      statusNotifier.setStatus(section.id, SectionStatus.completed);
    }

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: queue.first.id,
      photo: photo!,
      note: 'Cracked tile',
    );
    await notifier.markPhysicalInspectionComplete();
    await Future<void>.delayed(Duration.zero);
    _resolvePendingSuggestion(container, notifier);
    notifier.setReportMetadata(
      const ReportMetadata(
        title: 'Test Property',
        contactNumber: '+60123456789',
      ),
    );
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
      notifier.setAutoAnalyseEnabled(true);
      final queue = container.read(inspectionQueueProvider);
      final statusNotifier = container.read(sectionStatusesProvider.notifier);
      for (final section in queue) {
        statusNotifier.setStatus(section.id, SectionStatus.completed);
      }

      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      notifier.saveCameraFinding(
        sectionId: queue.first.id,
        photo: photo!,
        note: 'Cracked tile',
      );
      await notifier.markPhysicalInspectionComplete();
      await Future<void>.delayed(Duration.zero);
      _resolvePendingSuggestion(container, notifier);
    notifier.setReportMetadata(
      const ReportMetadata(
        title: 'Test Property',
        contactNumber: '+60123456789',
      ),
    );

      final result = await notifier.generateReport();

      expect(result.isSuccess, isTrue);
    },
  );
}
