import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import 'support/test_repository.dart';

/// go_router pushes keep every previous screen mounted (for back-swipe /
/// transition support), so several of these screens are simultaneously in
/// the widget tree at once (e.g. the area configuration screen still has
/// a row for "Kitchen" while the inspection queue screen also shows
/// "Kitchen"). All lookups below are scoped to the topmost screen via
/// [_within] to avoid matching a stale widget further down the stack.
Finder _within(Finder matching) =>
    find.descendant(of: find.byType(Scaffold).last, matching: matching);

Finder _dialogTextFieldAt(int index) => find
    .descendant(of: find.byType(AlertDialog), matching: find.byType(TextField))
    .at(index);

Finder _dialogButton(String label) =>
    find.descendant(of: find.byType(AlertDialog), matching: find.text(label));

Future<ProviderContainer> _pumpToInspectionQueue(WidgetTester tester) async {
  final container = ProviderContainer(overrides: testOverrides());
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ProDefactApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(_within(find.text('Start Home Inspection')));
  await tester.pumpAndSettle();

  await tester.tap(_within(find.text('New Inspection')));
  await tester.pumpAndSettle();

  await tester.tap(_within(find.text('High Rise')));
  await tester.pumpAndSettle();

  await tester.tap(_within(find.text('Continue')));
  await tester.pumpAndSettle();

  expect(find.text('Physical Inspection'), findsOneWidget);
  return container;
}

void _popRoute(WidgetTester tester) {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.pop();
}

void main() {
  testWidgets('opening an area moves it from Not started to In progress', (
    tester,
  ) async {
    final container = await _pumpToInspectionQueue(tester);
    final firstAreaName = container.read(inspectionQueueProvider).first.name;

    await tester.tap(_within(find.text(firstAreaName)));
    await tester.pumpAndSettle();

    _popRoute(tester);
    await tester.pumpAndSettle();

    expect(_within(find.text('In progress')), findsOneWidget);
  });

  testWidgets(
    'a finding added against an element/component survives navigating '
    'back to the queue and forward again (in-memory state preserved)',
    (tester) async {
      final container = await _pumpToInspectionQueue(tester);
      final firstAreaName = container.read(inspectionQueueProvider).first.name;
      final firstElementName = container
          .read(inspectionQueueProvider)
          .first
          .elements
          .first
          .name;

      await tester.tap(_within(find.text(firstAreaName)));
      await tester.pumpAndSettle();
      await tester.tap(_within(find.text(firstElementName)));
      await tester.pumpAndSettle();

      await tester.tap(_within(find.text('Add finding')).first);
      await tester.pumpAndSettle();
      await tester.enterText(_dialogTextFieldAt(0), 'Cracked tile');
      await tester.tap(_dialogButton('Add'));
      await tester.pumpAndSettle();

      expect(_within(find.text('Cracked tile')), findsOneWidget);

      // Navigate back to the queue, then forward again.
      _popRoute(tester);
      await tester.pumpAndSettle();
      _popRoute(tester);
      await tester.pumpAndSettle();
      expect(find.text('Physical Inspection'), findsOneWidget);

      await tester.tap(_within(find.text(firstAreaName)));
      await tester.pumpAndSettle();

      expect(_within(find.text('Cracked tile')), findsOneWidget);
    },
  );

  testWidgets('a finding can be edited and then removed', (tester) async {
    final container = await _pumpToInspectionQueue(tester);
    final firstAreaName = container.read(inspectionQueueProvider).first.name;
    final firstElementName = container
        .read(inspectionQueueProvider)
        .first
        .elements
        .first
        .name;

    await tester.tap(_within(find.text(firstAreaName)));
    await tester.pumpAndSettle();
    await tester.tap(_within(find.text(firstElementName)));
    await tester.pumpAndSettle();

    await tester.tap(_within(find.text('Add finding')).first);
    await tester.pumpAndSettle();
    await tester.enterText(_dialogTextFieldAt(0), 'Original text');
    await tester.tap(_dialogButton('Add'));
    await tester.pumpAndSettle();
    expect(_within(find.text('Original text')), findsOneWidget);

    await tester.tap(_within(find.byIcon(Icons.edit)));
    await tester.pumpAndSettle();
    await tester.enterText(_dialogTextFieldAt(0), 'Edited text');
    await tester.tap(_dialogButton('Save'));
    await tester.pumpAndSettle();
    expect(_within(find.text('Edited text')), findsOneWidget);
    expect(find.text('Original text'), findsNothing);

    await tester.tap(_within(find.byIcon(Icons.delete_outline)));
    await tester.pumpAndSettle();
    expect(find.text('Edited text'), findsNothing);
    expect(_within(find.text('No findings recorded yet.')), findsOneWidget);
  });

  testWidgets('marking an area completed is reflected in the queue', (
    tester,
  ) async {
    final container = await _pumpToInspectionQueue(tester);
    final firstAreaName = container.read(inspectionQueueProvider).first.name;

    await tester.tap(_within(find.text(firstAreaName)));
    await tester.pumpAndSettle();

    await tester.tap(_within(find.text('Completed')));
    await tester.pumpAndSettle();

    _popRoute(tester);
    await tester.pumpAndSettle();

    expect(_within(find.text('Completed')), findsOneWidget);
  });

  testWidgets(
    'Complete Physical Inspection stays disabled until every included '
    'area is completed',
    (tester) async {
      final container = await _pumpToInspectionQueue(tester);

      var button = tester.widget<FilledButton>(
        _within(
          find.widgetWithText(FilledButton, 'Complete Physical Inspection'),
        ),
      );
      expect(button.onPressed, isNull);

      final queue = container.read(inspectionQueueProvider);
      final statusNotifier = container.read(sectionStatusesProvider.notifier);
      for (final section in queue.skip(1)) {
        statusNotifier.setStatus(section.id, SectionStatus.completed);
      }
      await tester.pumpAndSettle();

      button = tester.widget<FilledButton>(
        _within(
          find.widgetWithText(FilledButton, 'Complete Physical Inspection'),
        ),
      );
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'Complete Physical Inspection is enabled once every included area is '
    'completed, and navigates to the next-stage placeholder',
    (tester) async {
      final container = await _pumpToInspectionQueue(tester);

      final queue = container.read(inspectionQueueProvider);
      final statusNotifier = container.read(sectionStatusesProvider.notifier);
      for (final section in queue) {
        statusNotifier.setStatus(section.id, SectionStatus.completed);
      }
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(
        _within(
          find.widgetWithText(FilledButton, 'Complete Physical Inspection'),
        ),
      );
      expect(button.onPressed, isNotNull);

      await tester.tap(
        _within(
          find.widgetWithText(FilledButton, 'Complete Physical Inspection'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Physical Inspection Complete'), findsOneWidget);
    },
  );
}
