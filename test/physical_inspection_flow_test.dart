import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
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

// The photo preview (side note + Save/Discard) is a modal bottom sheet
// — see area_inspection_screen.dart's `_PhotoPreviewSheet`.
Finder _previewNoteField() => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.byType(TextField),
);

Finder _previewButton(String label) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(label));

/// Takes a photo and saves a camera-first finding with [note] against
/// whichever area screen is currently on top.
Future<void> _takePhotoAndSave(WidgetTester tester, String note) async {
  await tester.tap(_within(find.text('Take Defect Photo')));
  await tester.pumpAndSettle();
  await tester.enterText(_previewNoteField(), note);
  await tester.tap(_previewButton('Save Finding'));
  await tester.pumpAndSettle();
}

Future<ProviderContainer> _pumpToInspectionQueue(WidgetTester tester) async {
  final container = ProviderContainer(overrides: testOverrides());
  addTearDown(container.dispose);

  // A tall surface so every area card is actually built (not just
  // scrolled past) by the lazy list — the default test surface is too
  // short to fit the property header, progress hero, and every area at
  // once.
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ProDefactApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('New Inspection'));
  await tester.pumpAndSettle();

  await tester.tap(_within(find.text('High Rise')));
  await tester.pumpAndSettle();

  await tester.enterText(
    _within(find.byType(TextFormField)).first,
    'Test Property',
  );
  await tester.tap(_within(find.text('Continue')));
  await tester.pumpAndSettle();

  await tester.tap(_within(find.text('Continue')));
  await tester.pumpAndSettle();

  await tester.tap(_within(find.text('Continue')));
  await tester.pumpAndSettle();

  await tester.tap(_within(find.text('Start Inspection')));
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
    'a camera-first finding survives navigating back to the queue and '
    'forward again (in-memory state preserved)',
    (tester) async {
      final container = await _pumpToInspectionQueue(tester);
      final firstAreaName = container.read(inspectionQueueProvider).first.name;

      await tester.tap(_within(find.text(firstAreaName)));
      await tester.pumpAndSettle();

      await _takePhotoAndSave(tester, 'Cracked tile');

      expect(_within(find.text('Cracked tile')), findsOneWidget);

      // Navigate back to the queue, then forward again.
      _popRoute(tester);
      await tester.pumpAndSettle();
      expect(find.text('Physical Inspection'), findsOneWidget);

      await tester.tap(_within(find.text(firstAreaName)));
      await tester.pumpAndSettle();

      expect(_within(find.text('Cracked tile')), findsOneWidget);
    },
  );

  testWidgets(
    '"Add another photo" attaches a second photo to an existing finding '
    'and re-queues it for AI',
    (tester) async {
      final container = await _pumpToInspectionQueue(tester);
      final firstAreaName = container.read(inspectionQueueProvider).first.name;

      await tester.tap(_within(find.text(firstAreaName)));
      await tester.pumpAndSettle();

      await _takePhotoAndSave(tester, 'Leaking tap');

      await tester.tap(_within(find.byIcon(Icons.add_a_photo_outlined)));
      await tester.pumpAndSettle();

      expect(_within(find.text('2 photos')), findsOneWidget);

      final finding = container
          .read(activeSessionProvider)!
          .findings
          .singleWhere((f) => f.description == 'Leaking tap');
      expect(finding.evidence, hasLength(2));
    },
  );

  testWidgets('a finding\'s note can be edited and the finding removed', (
    tester,
  ) async {
    final container = await _pumpToInspectionQueue(tester);
    final firstAreaName = container.read(inspectionQueueProvider).first.name;

    await tester.tap(_within(find.text(firstAreaName)));
    await tester.pumpAndSettle();

    await _takePhotoAndSave(tester, 'Original text');
    expect(_within(find.text('Original text')), findsOneWidget);

    await tester.tap(_within(find.byIcon(Icons.edit_outlined)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Edited text');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(_within(find.text('Edited text')), findsOneWidget);
    expect(find.text('Original text'), findsNothing);

    await tester.tap(_within(find.byIcon(Icons.delete_outline)));
    await tester.pumpAndSettle();
    expect(find.text('Edited text'), findsNothing);
    expect(
      _within(find.textContaining('No findings recorded yet')),
      findsOneWidget,
    );
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
    'completed, and navigates to the AI review screen',
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

      expect(find.text('AI Review'), findsOneWidget);
    },
  );
}
