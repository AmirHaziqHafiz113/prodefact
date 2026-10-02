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
/// inspection: it's still saved, and since analysis is automatic the
/// card says it's waiting for Credits (with Top Up) —
/// see docs/commercial_model.md ("Physical inspection is never blocked
/// by commercial state").
void main() {
  testWidgets('a saved finding on a zero-balance Flex Credits inspection: '
      'its automatic analysis cannot run, so the card shows "AI: Waiting '
      'for Credits" with Top Up (and Retry), never a bare failure', (
    tester,
  ) async {
    final billing = FakeBillingService(initialBalanceCredits: 0);
    final container = ProviderContainer(
      overrides: testOverrides(billingService: billing),
    );
    addTearDown(container.dispose);
    await container
        .read(activeSessionProvider.notifier)
        .startNew(
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
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('AI analysis failed'), findsNothing);
  });

  testWidgets('a zero Credit balance never blocks a House Pass inspection: '
      'the finding is analysed under the pass and never shows the '
      'zero-Credits card', (tester) async {
    final billing = FakeBillingService(initialBalanceCredits: 0);
    final container = ProviderContainer(
      overrides: testOverrides(billingService: billing),
    );
    addTearDown(container.dispose);
    await container
        .read(activeSessionProvider.notifier)
        .startNew(
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

    expect(find.text('AI: Waiting for Credits'), findsNothing);
    expect(
      container.read(activeSessionProvider)!.findings.single.aiStatus,
      AiFindingStatus.completed,
    );
  });
}
