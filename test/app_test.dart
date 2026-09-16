import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';

import 'support/test_repository.dart';

void main() {
  testWidgets('app boots directly to the dashboard and can navigate into '
      'Home Inspection', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: testOverrides(), child: const ProDefactApp()),
    );
    await tester.pumpAndSettle();

    // No industry-picker splash — the dashboard is the app's initial
    // route (see `buildAppRouter`).
    expect(find.text('Inspections'), findsOneWidget);
    expect(find.text('No saved inspections yet.'), findsOneWidget);

    await tester.tap(find.text('New Inspection'));
    await tester.pumpAndSettle();

    expect(find.text('Select property type'), findsOneWidget);
    expect(find.text('High Rise'), findsOneWidget);
    expect(find.text('Landed'), findsOneWidget);
  });

  testWidgets(
    'selecting a property type leads to Property Details, then shows its '
    'default areas, plumbing first',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(overrides: testOverrides(), child: const ProDefactApp()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('New Inspection'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Landed'));
      await tester.pumpAndSettle();

      expect(find.text('Property Details'), findsOneWidget);
      await tester.enterText(
        find.byType(TextFormField).first,
        'Test Landed Property',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Landed Areas'), findsOneWidget);
      expect(find.text('Master Bathroom'), findsOneWidget);
      // Nothing is persisted yet — property type/details setup only
      // edits an in-memory setup draft (see
      // `NewInspectionDraftNotifier`); no inspection exists until
      // "Start Inspection" is tapped.
      expect(find.text('Plumbing area — inspect first'), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('Staircase'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Staircase'), findsOneWidget);
    },
  );
}
