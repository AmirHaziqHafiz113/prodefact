import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/theme/design_system.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/inspection_queue_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import 'support/test_repository.dart';

/// Inspection Overview (`InspectionQueueScreen`): each area card must
/// show physical/AI/review as three distinct, real (never fabricated)
/// counts — see `docs/home_inspection_product_flow.md`. Pumps the
/// screen directly (no router/navigation involved) since only its
/// rendering is under test here.
void main() {
  testWidgets(
    'an area with a reviewed finding shows real AI/review counts, and a '
    'zero-finding area shows "No findings"/"Not required" rather than a '
    'fake 0/0',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);

      // The provider setup below awaits real (non-widget) async work —
      // session/finding persistence and the fake AI classification
      // pipeline — which needs `runAsync` to actually progress under
      // `testWidgets`'s fake-time test binding, unlike a plain `test()`.
      await tester.runAsync(() async {
        container
            .read(newInspectionDraftProvider.notifier)
            .begin(PropertyType.highRise);
        await container
            .read(newInspectionDraftProvider.notifier)
            .startInspection();
        final notifier = container.read(activeSessionProvider.notifier);
        notifier.setAutoAnalyseEnabled(true);
        final sections = container.read(inspectionQueueProvider);
        // Plumbing areas are ordered first — the first one is a
        // bathroom, which the deterministic fake AI resolves to a real
        // sanitary-fitting catalogue entry (never `needsReview`) from
        // its name alone.
        final bathroom = sections.first;

        final photo = await notifier.captureFindingPhoto(
          source: EvidenceSource.camera,
        );
        notifier.saveCameraFinding(sectionId: bathroom.id, photo: photo!);
        await Future<void>.delayed(Duration.zero);

        final suggestion = container
            .read(activeSessionProvider)!
            .aiSuggestions
            .single;
        notifier.acceptSuggestion(suggestion.id);
      });

      // A tall surface so every area card in the queue — plus the Auto
      // Analyse toggle and any House Pass banner above them — is
      // actually built (not just scrolled past) by the lazy
      // `ListView`; the default test surface is too short to fit all
      // of highRise's areas at once.
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionQueueScreen()),
        ),
      );
      await tester.pump();

      // Real, distinct AI and Review mini-progress fills — never a
      // single fake combined percentage.
      final miniProgress = tester
          .widgetList<AppMiniProgressLine>(find.byType(AppMiniProgressLine))
          .toList();
      expect(
        miniProgress.where((p) => p.label == 'AI' && p.fractionLabel == '1/1'),
        hasLength(1),
      );
      expect(
        miniProgress.where(
          (p) => p.label == 'Review' && p.fractionLabel == '1/1',
        ),
        hasLength(1),
      );
      // At least one other included area has no findings at all.
      expect(find.text('AI: No findings · Review: Not required'), findsWidgets);
    },
  );
}
