import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/router/app_shell_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/home_dashboard_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/wallet_screen.dart';

import '../support/test_repository.dart';

/// Home's Credits summary is compact and secondary to the active
/// inspection hero (docs/prodefact_design_system.md §19/§31 via the
/// mission's "AI CREDITS" section): tapping the row opens Wallet, with
/// a single "Top Up" button rather than two competing filled actions.
void main() {
  testWidgets(
    'tapping the Credits summary opens Wallet, and Top Up is the only '
    'button on the row',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ProDefactApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text('Home'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeDashboardScreen), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Top Up'), findsOneWidget);
      expect(find.text('Usage'), findsNothing);
      expect(find.text('View Usage'), findsNothing);

      await tester.tap(find.text('500 credits'));
      await tester.pumpAndSettle();

      expect(find.byType(WalletScreen), findsOneWidget);
    },
  );
}
