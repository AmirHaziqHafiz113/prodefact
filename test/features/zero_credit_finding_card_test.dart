import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// A zero-balance, Flex-only finding must never block physical
/// inspection: it's still saved, but the card proactively shows it's
/// waiting for Credits rather than the generic "Ready to analyse" —
/// see docs/commercial_model.md ("Physical inspection is never blocked
/// by commercial state").
void main() {
  testWidgets('a saved finding on a zero-balance Flex Credits inspection shows '
      '"AI: Waiting for Credits" and a Top Up action, not "Ready to '
      'analyse"', (tester) async {
    final billing = FakeBillingService(initialBalanceCredits: 0);
    final container = ProviderContainer(
      overrides: testOverrides(billingService: billing),
    );
    addTearDown(container.dispose);
    await container.read(activeSessionProvider.notifier).startNew(
          PropertyType.highRise,
          commercialMode: CommercialMode.flexCredits,
          selectedAiLevel: AiLevel.smart,
        );
    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);
    final section = queue.first;

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: section.id,
      photo: photo!,
      note: 'Cracked tile',
    );
    await tester.pump(); // let walletBalanceProvider resolve

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: AreaInspectionScreen(sectionId: section.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI: Waiting for Credits'), findsOneWidget);
    expect(find.text('Top Up'), findsOneWidget);
    expect(find.text('Ready to analyse'), findsNothing);
  });

  testWidgets('a saved finding on a zero-allowance-remaining House Pass '
      'inspection still shows the normal "Ready to analyse" prompt, not '
      'the zero-Credits card — its allowance may still cover the finding '
      'for 0 Credits, which only the real estimate call knows for sure', (
    tester,
  ) async {
    final billing = FakeBillingService(initialBalanceCredits: 0);
    final container = ProviderContainer(
      overrides: testOverrides(billingService: billing),
    );
    addTearDown(container.dispose);
    await container.read(activeSessionProvider.notifier).startNew(
          PropertyType.highRise,
          commercialMode: CommercialMode.housePass,
          selectedAiLevel: AiLevel.smart,
        );
    final sessionId = container.read(activeSessionProvider)!.id;
    final intent = await billing.purchaseHousePass(sessionId);
    await billing.confirmSandboxPayment(intent.intentId);

    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);
    final section = queue.first;
    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: section.id,
      photo: photo!,
      note: 'Cracked tile',
    );
    await tester.pump();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: AreaInspectionScreen(sectionId: section.id)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ready to analyse'), findsOneWidget);
    expect(find.text('AI: Waiting for Credits'), findsNothing);
  });
}
