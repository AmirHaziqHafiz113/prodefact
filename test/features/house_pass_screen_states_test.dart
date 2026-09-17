import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/house_pass_screen.dart';
import 'package:prodefact/features/home_inspection/providers/house_pass_providers.dart';

import '../support/test_repository.dart';

const _inspectionId = 'test-inspection';

Future<void> _pump(WidgetTester tester, HousePassSummary summary) async {
  final container = ProviderContainer(
    overrides: [
      ...testOverrides(),
      housePassStatusProvider(_inspectionId)
          .overrideWith((ref) async => summary),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: HousePassScreen(inspectionId: _inspectionId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// House Pass is a fixed RM30/property package, never a subscription —
/// every state shows that price and a friendly (never raw enum) label,
/// with exactly one clear primary action.
void main() {
  testWidgets(
    'purchase-required: shows RM30/property, no subscription wording, '
    'and a single Purchase action',
    (tester) async {
      await _pump(
        tester,
        const HousePassSummary(
          status: HousePassLifecycleStatus.purchaseRequired,
          priceMyr: 30,
          includedAiLevel: AiLevel.smart,
          allowanceLimit: 5,
          isProductionReady: true,
        ),
      );

      expect(find.text('Purchase Required'), findsOneWidget);
      expect(find.text('RM30'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Purchase House Pass'),
        findsOneWidget,
      );
      expect(find.textContaining('/month'), findsNothing);
      expect(find.textContaining('subscription'), findsNothing);
      expect(find.textContaining('HousePassLifecycleStatus'), findsNothing);
    },
  );

  testWidgets('active: shows House Pass Active and a single Done action', (
    tester,
  ) async {
    await _pump(
      tester,
      const HousePassSummary(
        status: HousePassLifecycleStatus.active,
        priceMyr: 30,
        includedAiLevel: AiLevel.smart,
        allowanceUsed: 2,
        allowanceLimit: 5,
        isProductionReady: true,
      ),
    );

    expect(find.text('House Pass Active'), findsOneWidget);
    expect(find.text('2 / 5 findings'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
  });

  testWidgets('allowance reached: explains Flex Credits fallback with one '
      'Continue action', (tester) async {
    await _pump(
      tester,
      const HousePassSummary(
        status: HousePassLifecycleStatus.allowanceReached,
        priceMyr: 30,
        includedAiLevel: AiLevel.smart,
        allowanceUsed: 5,
        allowanceLimit: 5,
        isProductionReady: true,
      ),
    );

    expect(find.text('Allowance Reached'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Continue with AI Credits'),
      findsOneWidget,
    );
  });

  testWidgets('payment failed: shows Try Again as the one primary action', (
    tester,
  ) async {
    await _pump(
      tester,
      const HousePassSummary(
        status: HousePassLifecycleStatus.paymentFailed,
        priceMyr: 30,
        isProductionReady: true,
      ),
    );

    expect(find.text('Payment Failed'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Try Again'), findsOneWidget);
  });

  testWidgets('no longer active: a friendly unavailable state with a way back, '
      'never a dead end', (tester) async {
    await _pump(
      tester,
      const HousePassSummary(
        status: HousePassLifecycleStatus.expiredOrCancelled,
        priceMyr: 30,
        isProductionReady: true,
      ),
    );

    expect(find.text('No Longer Active'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Back'), findsOneWidget);
  });
}
