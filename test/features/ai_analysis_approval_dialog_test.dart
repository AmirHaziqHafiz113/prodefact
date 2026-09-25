import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/ai_analysis_approval_dialog.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/scripted_billing_service.dart';
import '../support/test_repository.dart';

/// Starts a highRise inspection under the given commercial plan and
/// saves one camera-first finding in its first area — the setup every
/// test in this file needs before it can open the approval dialog for
/// a real, existing finding.
Future<String> _startSessionWithFinding(
  ProviderContainer container, {
  required CommercialMode commercialMode,
  required AiLevel selectedAiLevel,
}) async {
  await container.read(activeSessionProvider.notifier).startNew(
        PropertyType.highRise,
        commercialMode: commercialMode,
        selectedAiLevel: selectedAiLevel,
      );
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
  return finding.id;
}

Future<void> _pumpDialogHarness(
  WidgetTester tester,
  ProviderContainer container,
  String findingId,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => showAnalyseApprovalDialog(
                context: context,
                ref: ref,
                findingId: findingId,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a Flex Credits estimate dialog shows "Smart AI", "Up to N Credits", '
    'its RM equivalent, the balance, and "Not Now"/"Analyse", with no '
    'Fast/Smart/Expert choice (QA #24) and no billing choice (QA #23)',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      final findingId = await _startSessionWithFinding(
        container,
        commercialMode: CommercialMode.flexCredits,
        selectedAiLevel: AiLevel.smart,
      );

      await _pumpDialogHarness(tester, container, findingId);

      expect(find.text('Smart AI'), findsOneWidget);
      // The evidence photo for this finding renders as context above
      // the estimate — never a bare pricing dialog with no idea which
      // finding it's about.
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Up to 300 Credits'), findsOneWidget);
      expect(find.text('≈ RM3.00'), findsOneWidget);
      expect(find.text('Balance: 500 Credits'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);
      expect(find.text('Analyse'), findsOneWidget);

      expect(find.byType(SegmentedButton<AiLevel>), findsNothing);
      expect(find.text('Fast'), findsNothing);
      expect(find.text('Expert'), findsNothing);
      expect(find.textContaining('Flex Credits'), findsNothing);
      expect(find.textContaining('House Pass'), findsNothing);
    },
  );

  testWidgets(
    'with an active House Pass the dialog says the analysis is included, '
    'without ever asking the inspector to choose House Pass',
    (tester) async {
      final billing = FakeBillingService(initialBalanceCredits: 10000);
      final container = ProviderContainer(
        overrides: testOverrides(billingService: billing),
      );
      addTearDown(container.dispose);
      final findingId = await _startSessionWithFinding(
        container,
        commercialMode: CommercialMode.housePass,
        selectedAiLevel: AiLevel.smart,
      );
      final sessionId = container.read(activeSessionProvider)!.id;
      final intent = await billing.purchaseHousePass(sessionId);
      await billing.confirmSandboxPayment(intent.intentId);

      await _pumpDialogHarness(tester, container, findingId);

      expect(find.text('Smart AI'), findsOneWidget);
      expect(
        find.text('Included with this inspection. No Credits charged.'),
        findsOneWidget,
      );
      expect(find.byType(SegmentedButton<AiLevel>), findsNothing);
    },
  );

  testWidgets(
    'approving always runs Smart, even for an inspection created with '
    'Expert selected',
    (tester) async {
      final billing = ScriptedBillingService();
      final container = ProviderContainer(
        overrides: testOverrides(billingService: billing),
      );
      addTearDown(container.dispose);
      final findingId = await _startSessionWithFinding(
        container,
        commercialMode: CommercialMode.flexCredits,
        selectedAiLevel: AiLevel.expert,
      );

      await _pumpDialogHarness(tester, container, findingId);
      await tester.tap(find.widgetWithText(FilledButton, 'Analyse'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 20; i++) {
        await tester.pump();
      }

      expect(billing.calls.single.aiLevel, AiLevel.smart);
    },
  );

  testWidgets(
    'an insufficient-balance estimate shows the exact Credits required '
    'and available, and "Not Now"/"Top Up to Analyse" actions',
    (tester) async {
      final billing = FakeBillingService(initialBalanceCredits: 50);
      final container = ProviderContainer(
        overrides: testOverrides(billingService: billing),
      );
      addTearDown(container.dispose);
      final findingId = await _startSessionWithFinding(
        container,
        commercialMode: CommercialMode.flexCredits,
        selectedAiLevel: AiLevel.smart,
      );

      await _pumpDialogHarness(tester, container, findingId);

      expect(
        find.text(
          '300 Credits required, 50 Credits available. Physical '
          'inspection is never affected — you can still classify this '
          'finding manually.',
        ),
        findsOneWidget,
      );
      expect(find.text('Not Now'), findsOneWidget);
      expect(find.text('Top Up to Analyse'), findsOneWidget);
    },
  );
}
