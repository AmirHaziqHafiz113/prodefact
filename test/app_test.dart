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
    // route (see `buildAppRouter`). "Inspections" appears twice now (the
    // page's own headline plus its bottom-nav destination label), so
    // this checks for at least one rather than exactly one.
    expect(find.text('Inspections'), findsWidgets);
    expect(find.text('No inspections yet'), findsOneWidget);

    await tester.tap(find.byTooltip('New Inspection'));
    await tester.pumpAndSettle();

    expect(
      find.text('What type of property are you inspecting?'),
      findsOneWidget,
    );
    expect(find.text('High Rise'), findsOneWidget);
    expect(find.text('Landed'), findsOneWidget);
  });

  testWidgets(
    'selecting a property type leads to Basic Details, then shows its '
    'default areas, plumbing first',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(overrides: testOverrides(), child: const ProDefactApp()),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('New Inspection'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Landed'));
      await tester.pumpAndSettle();

      expect(find.text('Basic Details'), findsOneWidget);
      // The first field is now Unit No. (the only field required to
      // start an inspection) rather than the title.
      await tester.enterText(
        find.byType(TextFormField).first,
        'A-1-1',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Configure Areas'), findsOneWidget);
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
