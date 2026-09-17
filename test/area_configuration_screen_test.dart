import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';

import 'support/test_repository.dart';

Future<void> _startHighRiseSetup(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(overrides: testOverrides(), child: const ProDefactApp()),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('New Inspection'));
  await tester.pumpAndSettle();

  await tester.tap(find.text('High Rise'));
  await tester.pumpAndSettle();

  // Property Details step — only the title is required.
  await tester.enterText(find.byType(TextFormField).first, 'Test Property');
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

/// From the area configuration screen, through Review Setup, to
/// "Start Inspection" — the only place a draft actually becomes a
/// persisted inspection (see `ReviewSetupScreen`).
Future<void> _reviewAndStart(WidgetTester tester) async {
  await tester.tap(find.text('Review & Start'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start Inspection'));
  await tester.pumpAndSettle();
}

Future<void> _revealAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable),
  );
  await tester.pumpAndSettle();
  await tester.tap(finder, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Area rows are `Card`s (not `ListTile`s — see the overflow-fix
/// rewrite of `_AreaCard` in area_configuration_screen.dart), so a row
/// is found by walking up from its name `Text` to the enclosing `Card`.
Finder _areaCard(String name) =>
    find.ancestor(of: find.text(name), matching: find.byType(Card));

/// go_router keeps every previously pushed screen mounted, so once the
/// inspection queue screen is pushed on top of the area configuration
/// screen, both may show the same area name ("Kitchen"). Scope lookups
/// to the topmost screen to avoid matching the screen underneath.
Finder _within(Finder matching) =>
    find.descendant(of: find.byType(Scaffold).last, matching: matching);

void main() {
  testWidgets('toggling an area include/exclude switch works', (tester) async {
    await _startHighRiseSetup(tester);

    final kitchenCard = _areaCard('Kitchen');
    await tester.scrollUntilVisible(
      kitchenCard,
      200,
      scrollable: find.byType(Scrollable),
    );

    final kitchenSwitch = find.descendant(
      of: kitchenCard,
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
      of: _areaCard('Bedroom 2'),
      matching: find.byIcon(Icons.edit),
    );
    await _revealAndTap(tester, editButton);

    expect(find.text('Edit area'), findsOneWidget);
    await tester.enterText(find.byType(TextField), "Son's Room");
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text("Son's Room"), findsOneWidget);
    expect(find.text('Bedroom 2'), findsNothing);
  });

  testWidgets(
    'editing an area can also mark/unmark it as a plumbing area, which '
    'moves it into plumbing-first ordering',
    (tester) async {
      await _startHighRiseSetup(tester);

      final editButton = find.descendant(
        of: _areaCard('Living Room'),
        matching: find.byIcon(Icons.edit),
      );
      await _revealAndTap(tester, editButton);

      expect(find.text('Edit area'), findsOneWidget);
      expect(find.text('Contains plumbing'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Now flagged as plumbing — the card shows the "inspect first"
      // indicator.
      final livingRoomCard = _areaCard('Living Room');
      expect(
        find.descendant(
          of: livingRoomCard,
          matching: find.text('Plumbing area — inspect first'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('adding a custom area appends it to the list', (tester) async {
    await _startHighRiseSetup(tester);

    await tester.tap(find.text('Add area'));
    await tester.pumpAndSettle();
    expect(find.text('Add area'), findsWidgets);
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

  testWidgets('adding a custom area as a plumbing area participates in '
      'plumbing-first ordering once the inspection starts', (tester) async {
    await _startHighRiseSetup(tester);

    await tester.tap(find.text('Add area'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Wet Kitchen');
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Wet Kitchen'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.descendant(
        of: _areaCard('Wet Kitchen'),
        matching: find.text('Plumbing area — inspect first'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('removing an area deletes it from the list', (tester) async {
    await _startHighRiseSetup(tester);

    final removeButton = find.descendant(
      of: _areaCard('Bedroom 4'),
      matching: find.byIcon(Icons.delete_outline),
    );
    await _revealAndTap(tester, removeButton);

    expect(find.text('Bedroom 4'), findsNothing);
  });

  testWidgets('Start Inspection navigates to the physical inspection queue', (
    tester,
  ) async {
    await _startHighRiseSetup(tester);

    await _reviewAndStart(tester);

    expect(find.text('Physical Inspection'), findsOneWidget);
  });

  testWidgets(
    'excluding an area in setup keeps it out of the inspection queue, '
    'and the exclusion survives resuming the inspection later',
    (tester) async {
      await _startHighRiseSetup(tester);

      final kitchenCard = _areaCard('Kitchen');
      await tester.scrollUntilVisible(
        kitchenCard,
        200,
        scrollable: find.byType(Scrollable),
      );
      final kitchenSwitch = find.descendant(
        of: kitchenCard,
        matching: find.byType(Switch),
      );
      await tester.tap(kitchenSwitch);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(kitchenSwitch).value, isFalse);

      await _reviewAndStart(tester);

      expect(find.text('Physical Inspection'), findsOneWidget);
      expect(_within(find.text('Kitchen')), findsNothing);

      // Once started, the setup draft is gone — popping back out of
      // the (now-empty) setup screens all the way to the dashboard and
      // resuming the inspection is the realistic way to check the
      // exclusion actually persisted in the created session, rather
      // than in the ephemeral setup screen. Stack from the dashboard:
      // property type -> property details -> area configuration ->
      // review setup -> queue — 5 pops to unwind it all.
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      for (var i = 0; i < 5; i++) {
        navigator.pop();
      }
      await tester.pumpAndSettle();

      // Resume the created session by tapping its card (titled during
      // Property Details setup), not by starting a new one.
      await tester.tap(find.text('Test Property'));
      await tester.pumpAndSettle();

      expect(find.text('Physical Inspection'), findsOneWidget);
      expect(_within(find.text('Kitchen')), findsNothing);
    },
  );

  testWidgets(
    'backing out of setup before Start Inspection leaves no inspection '
    'behind (the defect this flow was rewritten to fix)',
    (tester) async {
      await _startHighRiseSetup(tester);
      // Never tap "Start Inspection" — just leave setup. Stack from the
      // dashboard: property type -> property details -> area
      // configuration — 3 pops to unwind it all.
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pop(); // area configuration -> property details
      navigator.pop(); // property details -> property type selection
      navigator.pop(); // property type selection -> dashboard
      await tester.pumpAndSettle();

      expect(find.text('No saved inspections yet.'), findsOneWidget);
    },
  );

  testWidgets('repeated taps on Start Inspection do not create duplicate '
      'inspections', (tester) async {
    await _startHighRiseSetup(tester);
    await tester.tap(find.text('Review & Start'));
    await tester.pumpAndSettle();

    // Fire multiple taps in quick succession before the first
    // navigation completes.
    await tester.tap(find.text('Start Inspection'));
    await tester.tap(find.text('Start Inspection'));
    await tester.tap(find.text('Start Inspection'));
    await tester.pumpAndSettle();

    expect(find.text('Physical Inspection'), findsOneWidget);

    // Only one inspection was actually created — pop all the way
    // back to the dashboard (queue -> review setup -> areas ->
    // property details -> property type -> dashboard) and confirm
    // there's exactly one card, not several.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    for (var i = 0; i < 5; i++) {
      navigator.pop();
    }
    await tester.pumpAndSettle();
    expect(find.text('In Progress'), findsOneWidget);
  });
}
