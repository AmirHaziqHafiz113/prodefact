import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/theme/design_system.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/wallet_screen.dart';

import '../support/test_repository.dart';

/// Wallet's "Recent activity" is a grouped transaction list — one
/// bordered container, not a stack of individually-carded rows
/// (docs/prodefact_design_system.md §9/§17/§19).
void main() {
  testWidgets(
    'recent activity renders inside one grouped list, not a per-row card',
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

      // Wallet opens from Home's credits card (no longer a tab).
      await tester.tap(find.byKey(const ValueKey('home-credits')));
      await tester.pumpAndSettle();

      expect(find.byType(WalletScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Starting balance'),
        200,
        scrollable: find.byType(Scrollable),
      );

      // The fake wallet's default "Starting balance" transaction lives
      // inside a single AppGroupedList, not its own Card.
      expect(find.byType(AppGroupedList), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppGroupedList),
          matching: find.text('Starting balance'),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('Starting balance'),
          matching: find.byType(Card),
        ),
        findsNothing,
      );
    },
  );
}
