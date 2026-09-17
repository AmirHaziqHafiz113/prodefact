import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/top_up_screen.dart';

import '../support/test_repository.dart';

/// Top Up shows real, backend-configured packages (never hardcoded/
/// invented amounts — see `FakeBillingService`'s package list), a
/// clear selected state, and "Proceed to Payment" as the one primary
/// action.
void main() {
  testWidgets(
    'real configured packages are shown, selecting one shows a checked '
    'ChoiceChip and enables Proceed to Payment, which shows the intent '
    'summary',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TopUpScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Real packages from FakeBillingService's CommercialConfig — never
      // an invented amount.
      expect(find.text('RM10 · 1000 Credits'), findsOneWidget);
      expect(find.text('RM30 · 3000 Credits'), findsOneWidget);
      expect(find.text('RM50 · 5000 Credits'), findsOneWidget);
      expect(find.text('RM100 · 10000 Credits'), findsOneWidget);

      final proceedButtonBefore = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Proceed to Payment'),
      );
      expect(proceedButtonBefore.onPressed, isNull);

      final rm30Chip = find.widgetWithText(ChoiceChip, 'RM30 · 3000 Credits');
      await tester.tap(rm30Chip);
      await tester.pumpAndSettle();

      expect(tester.widget<ChoiceChip>(rm30Chip).selected, isTrue);
      final proceedButtonAfter = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Proceed to Payment'),
      );
      expect(proceedButtonAfter.onPressed, isNotNull);

      await tester.tap(find.text('Proceed to Payment'));
      await tester.pumpAndSettle();

      expect(find.text('RM30 top-up'), findsOneWidget);
      expect(find.text('You will receive 3000 Credits'), findsOneWidget);
    },
  );
}
