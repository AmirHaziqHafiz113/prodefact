import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/ai_review_overview_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';
import '../support/uncertain_ai_billing_service.dart';

/// AI Review's evidence photo is shown prominently, and Accept/Change/
/// Reject are visually distinct tiers — Accept (primary, filled),
/// Change (strong secondary, outlined), Reject (tertiary, text-only) —
/// never two of them looking equally weighted (mission "AI REVIEW"/§21).
void main() {
  testWidgets(
    'a pending suggestion shows its evidence photo, and Accept/Change/'
    'Reject render as filled/outlined/text respectively',
    (tester) async {
      final container = ProviderContainer(
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
        notifier.setAutoAnalyseEnabled(true);
        final section = container.read(inspectionQueueProvider).first;
        final photo = await notifier.captureFindingPhoto(
          source: EvidenceSource.camera,
        );
        notifier.saveCameraFinding(
          sectionId: section.id,
          photo: photo!,
          // AI needs a quick defect note (QA #16).
          note: 'Hollow tile',
        );
        await Future<void>.delayed(Duration.zero);
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: AiReviewOverviewScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Image), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Accept'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Change'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Reject / Unresolved'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Reject / Unresolved'),
        findsNothing,
      );
    },
  );
}
