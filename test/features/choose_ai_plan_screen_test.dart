import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';

import '../support/test_repository.dart';

/// Choose AI Plan should show the inspector's real current Credit
/// balance (mission "CHOOSE AI PLAN" — "Show current Credit balance
/// where useful"), never a fabricated number.
void main() {
  testWidgets('the current Credits balance is shown while choosing a plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(overrides: testOverrides(), child: const ProDefactApp()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New Inspection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High Rise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Test');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Choose AI Plan'), findsOneWidget);
    // FakeBillingService's default starting balance.
    expect(find.text('500'), findsOneWidget);
    expect(find.text('Credits'), findsOneWidget);
  });
}
