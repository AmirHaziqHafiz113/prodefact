import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/data/remote/remote_providers.dart';
import 'package:prodefact/features/auth/presentation/sign_in_screen.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/ai_analysis_approval_dialog.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/house_pass_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/top_up_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import 'support/fake_auth_service.dart';
import 'support/test_repository.dart';

/// Covers the screens/dialogs the main app-flow responsive smoke test
/// (`responsive_smoke_test.dart`) never reaches — House Pass, the
/// House Pass surcharge estimate dialog, Top Up, and Sign In — at the
/// same narrow/standard/large phone widths and text scales, so "every
/// redesigned screen" genuinely means every screen, not just the ones
/// on the default Flex Credits path.
const _phoneWidths = [320.0, 360.0, 390.0, 430.0];

Future<void> _assertNoOverflowAcrossWidths(
  WidgetTester tester, {
  String? screenLabel,
}) async {
  for (final width in _phoneWidths) {
    tester.view.physicalSize = Size(width, 2600);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpAndSettle();
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason:
          '${screenLabel ?? 'screen'} overflowed at width ${width}pt: '
          '$exception',
    );
  }
}

Future<void> _assertNoOverflowAcrossTextScales(
  WidgetTester tester, {
  String? screenLabel,
}) async {
  for (final scale in [1.0, 1.3, 1.6]) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    await tester.pumpAndSettle();
    final exception = tester.takeException();
    expect(
      exception,
      isNull,
      reason:
          '${screenLabel ?? 'screen'} overflowed at text scale $scale: '
          '$exception',
    );
  }
  tester.platformDispatcher.clearTextScaleFactorTestValue();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Sign In never overflows at narrow, standard, or large phone widths',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(390, 2600);
      tester.view.devicePixelRatio = 1.0;

      final auth = FakeAuthService(); // signed out
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [
          ...testOverrides(),
          authServiceProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SignInScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await _assertNoOverflowAcrossWidths(tester, screenLabel: 'Sign In');
      await _assertNoOverflowAcrossTextScales(tester, screenLabel: 'Sign In');
    },
  );

  testWidgets(
    'Top Up never overflows at narrow, standard, or large phone widths',
    (tester) async {
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(390, 2600);
      tester.view.devicePixelRatio = 1.0;

      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TopUpScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await _assertNoOverflowAcrossWidths(tester, screenLabel: 'Top Up');
      await _assertNoOverflowAcrossTextScales(tester, screenLabel: 'Top Up');

      // The "intent created" summary (amount/credits + sandbox/real
      // banner) is a materially different layout — check it too.
      await tester.tap(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Proceed to Payment'));
      await tester.pumpAndSettle();
      await _assertNoOverflowAcrossWidths(
        tester,
        screenLabel: 'Top Up intent summary',
      );
      await _assertNoOverflowAcrossTextScales(
        tester,
        screenLabel: 'Top Up intent summary',
      );
    },
  );

  testWidgets('House Pass (purchase-required state) never overflows at narrow, '
      'standard, or large phone widths', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1.0;

    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    await container.read(activeSessionProvider.notifier).startNew(
          PropertyType.highRise,
          commercialMode: CommercialMode.housePass,
          selectedAiLevel: AiLevel.smart,
        );
    final sessionId = container.read(activeSessionProvider)!.id;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: HousePassScreen(inspectionId: sessionId)),
      ),
    );
    await tester.pumpAndSettle();
    await _assertNoOverflowAcrossWidths(tester, screenLabel: 'House Pass');
    await _assertNoOverflowAcrossTextScales(tester, screenLabel: 'House Pass');
  });

  testWidgets('the House Pass Expert-surcharge estimate dialog never overflows '
      'at narrow, standard, or large phone widths', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(390, 2600);
    tester.view.devicePixelRatio = 1.0;

    final billing = FakeBillingService(initialBalanceCredits: 10000);
    final container = ProviderContainer(
      overrides: testOverrides(billingService: billing),
    );
    addTearDown(container.dispose);
    await container.read(activeSessionProvider.notifier).startNew(
          PropertyType.highRise,
          commercialMode: CommercialMode.housePass,
          selectedAiLevel: AiLevel.smart,
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
    final sessionId = container.read(activeSessionProvider)!.id;
    final intent = await billing.purchaseHousePass(sessionId);
    await billing.confirmSandboxPayment(intent.intentId);

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
                  findingId: finding.id,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expert'));
    await tester.pumpAndSettle();

    await _assertNoOverflowAcrossWidths(
      tester,
      screenLabel: 'House Pass surcharge dialog',
    );
    await _assertNoOverflowAcrossTextScales(
      tester,
      screenLabel: 'House Pass surcharge dialog',
    );
  });
}
