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
/// the AI provider is never even *reached* during physical inspection
/// work, not merely that its result is ignored. See Part 12 of the
/// live-testing fix pass: "AI MUST NOT automatically analyze findings/
/// photos while the inspector is physically inspecting."
class _SpyAiInspectionService implements AiInspectionService {
  int callCount = 0;

  @override
  Future<AiAnalysisResponse> analyze(AiAnalysisRequest request) async {
    callCount++;
    return AiAnalysisResponse(providerId: 'spy', suggestions: const []);
  }
}

void main() {
  test('capturing a photo does not call the AI provider', () async {
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
    final finding = notifier.addFinding(
      sectionId: queue.first.id,
      elementId: queue.first.elements.first.id,
    );

    await notifier.addEvidence(
      findingId: finding.id,
      source: EvidenceSource.camera,
    );

    expect(spy.callCount, 0);
  });

  test(
    'saving a finding (add or edit) does not call the AI provider',
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
      final queue = container.read(inspectionQueueProvider);

      final finding = notifier.addFinding(
        sectionId: queue.first.id,
        elementId: queue.first.elements.first.id,
        description: 'Cracked tile',
      );
      notifier.updateFinding(
        findingId: finding.id,
        description: 'Cracked tile, updated',
        notes: null,
      );

      expect(spy.callCount, 0);
    },
  );

  test('marking an area (or every area) completed does not call the AI '
      'provider — only the explicit AI Review action may', () async {
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

    // Even the explicit "physical inspection complete" transition —
    // one step short of the actual AI Review action — must not call
    // the provider.
    await notifier.markPhysicalInspectionComplete();
    expect(spy.callCount, 0);
  });

  test('only the explicit startAiAnalysis() call ever reaches the AI '
      'provider', () async {
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
    notifier.addFinding(
      sectionId: queue.first.id,
      elementId: queue.first.elements.first.id,
      description: 'Cracked tile',
    );
    for (final section in queue) {
      statusNotifier.setStatus(section.id, SectionStatus.completed);
    }
    await notifier.markPhysicalInspectionComplete();
    expect(spy.callCount, 0);

    await notifier.startAiAnalysis();

    expect(spy.callCount, 1);
  });
}
