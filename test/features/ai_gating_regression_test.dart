import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/ai/ai_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// A spy [AiInspectionService] that records every call — used to prove
/// the AI provider is never even *reached* except after an explicit
/// finding save. Camera-first model: capturing/previewing a photo, or
/// editing a not-yet-saved note, must never queue or call AI — only
/// `saveCameraFinding` (i.e. the inspector tapping "Save Finding") ever
/// does. See `docs/ai_provider_architecture.md` ("Progressive
/// per-finding AI pipeline").
class _SpyAiInspectionService implements AiInspectionService {
  int callCount = 0;

  @override
  Future<AiFindingClassification> classifyFinding(
    AiFindingClassificationRequest request,
  ) async {
    callCount++;
    return AiFindingClassification(
      findingId: request.findingId,
      needsReview: true,
    );
  }
}

void main() {
  test(
    'capturing a photo (before Save) does not call the AI provider',
    () async {
      final spy = _SpyAiInspectionService();
      final container = ProviderContainer(
        overrides: [
          ...testOverrides(),
          aiInspectionServiceProvider.overrideWithValue(spy),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      final notifier = container.read(activeSessionProvider.notifier);

      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );

      expect(photo, isNotNull);
      expect(spy.callCount, 0);
      // Nothing was saved either — capturing alone creates no finding.
      expect(container.read(activeSessionProvider)!.findings, isEmpty);
    },
  );

  test('discarding a captured photo without saving never calls the AI '
      'provider and leaves no finding behind', () async {
    final spy = _SpyAiInspectionService();
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(),
        aiInspectionServiceProvider.overrideWithValue(spy),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    await notifier.discardCapturedFindingPhoto(photo!);

    expect(spy.callCount, 0);
    expect(container.read(activeSessionProvider)!.findings, isEmpty);
  });

  test('saving a camera-first finding queues AI only after the explicit '
      'Save action — never merely from capture', () async {
    final spy = _SpyAiInspectionService();
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(),
        aiInspectionServiceProvider.overrideWithValue(spy),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    expect(spy.callCount, 0);

    notifier.saveCameraFinding(
      sectionId: queue.first.id,
      photo: photo!,
      note: 'Cracked tile',
    );
    // The queue kicks off asynchronously right after save — give the
    // microtask queue a tick.
    await Future<void>.delayed(Duration.zero);

    expect(container.read(activeSessionProvider)!.findings, hasLength(1));
    expect(spy.callCount, 1);
  });

  test('marking an area (or every area) physically complete does not '
      'call the AI provider by itself', () async {
    final spy = _SpyAiInspectionService();
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(),
        aiInspectionServiceProvider.overrideWithValue(spy),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);
    final statusNotifier = container.read(sectionStatusesProvider.notifier);

    for (final section in queue) {
      statusNotifier.setStatus(section.id, SectionStatus.completed);
    }
    expect(spy.callCount, 0);

    await notifier.markPhysicalInspectionComplete();
    expect(spy.callCount, 0);
  });

  test('editing a finding\'s note after saving does not re-trigger AI '
      'by itself (only new evidence does)', () async {
    final spy = _SpyAiInspectionService();
    final container = ProviderContainer(
      overrides: [
        ...testOverrides(),
        aiInspectionServiceProvider.overrideWithValue(spy),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    final finding = notifier.saveCameraFinding(
      sectionId: queue.first.id,
      photo: photo!,
      note: 'Cracked tile',
    );
    await Future<void>.delayed(Duration.zero);
    expect(spy.callCount, 1);

    notifier.updateFinding(
      findingId: finding.id,
      description: 'Cracked tile, updated wording only',
      notes: null,
    );
    await Future<void>.delayed(Duration.zero);

    expect(spy.callCount, 1);
  });
}
