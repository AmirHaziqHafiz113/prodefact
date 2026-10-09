import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/inspection_overview_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';
import '../support/uncertain_ai_billing_service.dart';

/// Inspection Overview's compact contextual strip — the single
/// highest-priority real state, never more than two at once (mission
/// "INSPECTION OVERVIEW" — "SYNC / AI STATE").
void main() {
  testWidgets('with no findings yet, the strip reads "Synced"', (tester) async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: InspectionOverviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Synced'), findsOneWidget);
  });

  testWidgets(
    'an unresolved AI suggestion surfaces as "1 finding needs review", '
    'ahead of sync state',
    (tester) async {
      final container = ProviderContainer(
        // Uncertain, so it is not auto-accepted.
        overrides: testOverrides(billingService: UncertainAiBillingService()),
      );
      addTearDown(container.dispose);

      await tester.runAsync(() async {
        container
            .read(newInspectionDraftProvider.notifier)
            .begin(PropertyType.highRise);
        await container
            .read(newInspectionDraftProvider.notifier)
            .startInspection();
        final notifier = container.read(activeSessionProvider.notifier);
        final sections = container.read(inspectionQueueProvider);
        final bathroom = sections.first;

        final photo = await notifier.captureFindingPhoto(
          source: EvidenceSource.camera,
        );
        notifier.saveCameraFinding(
          sectionId: bathroom.id,
          photo: photo!,
          // AI needs a quick defect note (QA #16).
          note: 'Hollow tile',
        );
        await Future<void>.delayed(Duration.zero);
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionOverviewScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 finding needs review'), findsOneWidget);
      expect(find.text('Synced'), findsNothing);
    },
  );
}
