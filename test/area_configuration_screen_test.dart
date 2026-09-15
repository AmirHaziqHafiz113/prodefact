import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';

Future<void> _startHighRiseSetup(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: ProDefactApp()));
  await tester.pumpAndSettle();

  await tester.tap(find.text('Start Home Inspection'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('High Rise'));
  await tester.pumpAndSettle();
}

Future<void> _revealAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable),
  );
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('toggling an area include/exclude switch works', (tester) async {
    await _startHighRiseSetup(tester);

    final kitchenTile = find.widgetWithText(ListTile, 'Kitchen');
    await tester.scrollUntilVisible(
      kitchenTile,
      200,
      scrollable: find.byType(Scrollable),
    );

    final kitchenSwitch = find.descendant(
      of: kitchenTile,
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(kitchenSwitch).value, isTrue);

    await tester.tap(kitchenSwitch);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(kitchenSwitch).value, isFalse);
  });

  testWidgets('renaming an area updates its displayed name', (tester) async {
    await _startHighRiseSetup(tester);

    final editButton = find.descendant(
      of: find.widgetWithText(ListTile, 'Bedroom 2'),
      matching: find.byIcon(Icons.edit),
    );
    await _revealAndTap(tester, editButton);

    await tester.enterText(find.byType(TextField), "Son's Room");
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text("Son's Room"), findsOneWidget);
    expect(find.text('Bedroom 2'), findsNothing);
  });

  testWidgets('adding a custom area appends it to the list', (tester) async {
    await _startHighRiseSetup(tester);

    await tester.tap(find.text('Add area'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Home Office');
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Home Office'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Home Office'), findsOneWidget);
  });

  testWidgets('removing an area deletes it from the list', (tester) async {
    await _startHighRiseSetup(tester);

    final removeButton = find.descendant(
      of: find.widgetWithText(ListTile, 'Bedroom 4'),
      matching: find.byIcon(Icons.delete_outline),
    );
    await _revealAndTap(tester, removeButton);

    expect(find.text('Bedroom 4'), findsNothing);
  });

  testWidgets('Continue navigates to the inspection placeholder screen', (
    tester,
  ) async {
    await _startHighRiseSetup(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('Physical inspection starts here (coming in Phase 3).'),
      findsOneWidget,
    );
  });

  testWidgets('configuration survives navigating to the placeholder and back', (
    tester,
  ) async {
    await _startHighRiseSetup(tester);

    final kitchenTile = find.widgetWithText(ListTile, 'Kitchen');
    await tester.scrollUntilVisible(
      kitchenTile,
      200,
      scrollable: find.byType(Scrollable),
    );
    final kitchenSwitch = find.descendant(
      of: kitchenTile,
      matching: find.byType(Switch),
    );
    await tester.tap(kitchenSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(kitchenSwitch).value, isFalse);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pop();
    await tester.pumpAndSettle();

    final kitchenTileAfter = find.widgetWithText(ListTile, 'Kitchen');
    await tester.scrollUntilVisible(
      kitchenTileAfter,
      200,
      scrollable: find.byType(Scrollable),
    );
    final kitchenSwitchAfter = find.descendant(
      of: kitchenTileAfter,
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(kitchenSwitchAfter).value, isFalse);
  });
}
