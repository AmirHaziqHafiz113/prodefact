import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';

import 'support/test_repository.dart';

void main() {
  testWidgets(
    'the sessions screen lists a saved inspection and can resume it',
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

      await tester.tap(find.text('Start Home Inspection'));
      await tester.pumpAndSettle();
      expect(find.text('No saved inspections yet.'), findsOneWidget);

      // Create a High Rise inspection, then back out to the list.
      await tester.tap(find.text('New Inspection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('High Rise'));
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pop();
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('No saved inspections yet.'), findsNothing);
      expect(find.text('High Rise'), findsOneWidget);
      expect(find.text('Unfinished'), findsOneWidget);

      await tester.tap(find.text('High Rise'));
      await tester.pumpAndSettle();

      expect(find.text('Physical Inspection'), findsOneWidget);
    },
  );
}
