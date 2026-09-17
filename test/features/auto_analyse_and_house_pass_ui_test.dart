import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/inspection_queue_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';

import '../support/test_repository.dart';

/// A fake AI classification request payload — only the fields
/// `FakeBillingService.analyseFinding` actually reads (`sessionId`,
/// `findingId`) need to be real for these tests.
AiFindingClassificationRequest _request({
  required String sessionId,
  required String findingId,
}) {
  return AiFindingClassificationRequest(
    sessionId: sessionId,
    findingId: findingId,
    sectionName: 'Master Bathroom',
    sectionIsPlumbing: true,
    note: 'Cracked tile',
  );
}

void main() {
  testWidgets(
    'the Auto Analyse toggle defaults off for a Flex Credits inspection, '
    'and tapping it calls setAutoAnalyseEnabled and flips the switch',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();

      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionQueueScreen()),
        ),
      );
      await tester.pump();

      expect(
        container.read(activeSessionProvider)!.autoAnalyseEnabled,
        isFalse,
      );
      final toggleFinder = find.byType(SwitchListTile);
      expect(toggleFinder, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggleFinder).value, isFalse);

      await tester.tap(toggleFinder);
      await tester.pump();

      expect(container.read(activeSessionProvider)!.autoAnalyseEnabled, isTrue);
      expect(tester.widget<SwitchListTile>(toggleFinder).value, isTrue);
    },
  );

  testWidgets(
    'once a House Pass allowance is reached while Auto Analyse is on, '
    'the queue screen turns Auto Analyse back off and shows "House Pass '
    'AI allowance reached." with a "Continue with AI Credits" action '
    'that re-enables it',
    (tester) async {
      final billing = FakeBillingService(initialBalanceCredits: 10000);
      final container = ProviderContainer(
        overrides: testOverrides(billingService: billing),
      );
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      container
          .read(newInspectionDraftProvider.notifier)
          .chooseCommercialPlan(
            commercialMode: CommercialMode.housePass,
            selectedAiLevel: AiLevel.smart,
          );
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      final sessionId = container.read(activeSessionProvider)!.id;

      final intent = await billing.purchaseHousePass(sessionId);
      await billing.confirmSandboxPayment(intent.intentId);
      // Exhaust the fake's 5-finding allowance directly against the
      // billing service — faster than driving 5 real findings through
      // the full capture/save/approve UI flow.
      for (var i = 0; i < 5; i++) {
        await billing.analyseFinding(
          request: _request(sessionId: sessionId, findingId: 'finding_$i'),
          aiLevel: AiLevel.smart,
          idempotencyKey: 'idem_$i',
        );
      }
      container
          .read(activeSessionProvider.notifier)
          .setAutoAnalyseEnabled(true);
      expect(container.read(activeSessionProvider)!.autoAnalyseEnabled, isTrue);

      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionQueueScreen()),
        ),
      );
      // Let the async housePassStatusProvider resolve and the
      // ref.listen side effect (turning Auto Analyse back off) run.
      await tester.pumpAndSettle();

      expect(
        container.read(activeSessionProvider)!.autoAnalyseEnabled,
        isFalse,
      );
      expect(find.text('House Pass AI allowance reached.'), findsOneWidget);
      final resumeButton = find.text('Continue with AI Credits');
      expect(resumeButton, findsOneWidget);

      await tester.tap(resumeButton);
      await tester.pump();

      expect(container.read(activeSessionProvider)!.autoAnalyseEnabled, isTrue);
    },
  );
}
