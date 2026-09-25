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
  await tester.tap(find.text('Camera'));
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
  testWidgets('opening an area without recording anything leaves it Not '
      'started: suggested areas are optional (QA #13/#21)', (tester) async {
    final container = await _pumpToInspectionQueue(tester);
    final firstAreaName = container.read(inspectionQueueProvider).first.name;

    await tester.tap(_within(find.text(firstAreaName)));
    await tester.pumpAndSettle();
    _popRoute(tester);
    await tester.pumpAndSettle();

    expect(_within(find.text('In progress')), findsNothing);
    final session = container.read(activeSessionProvider)!;
    expect(PhysicalProgress.of(session).totalAreas, 0);
  });

  testWidgets('recording a finding moves an area to In progress', (
    tester,
  ) async {
    final container = await _pumpToInspectionQueue(tester);
    final firstAreaName = container.read(inspectionQueueProvider).first.name;

    await tester.tap(_within(find.text(firstAreaName)));
    await tester.pumpAndSettle();
    await _takePhotoAndSave(tester, 'Cracked tile');
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
    '"Add angle" attaches a second photo of the same defect to the '
    'existing finding (QA #20), shown as a second thumbnail',
    (tester) async {
      final container = await _pumpToInspectionQueue(tester);
      final firstAreaName = container.read(inspectionQueueProvider).first.name;

      await tester.tap(_within(find.text(firstAreaName)));
      await tester.pumpAndSettle();

      await _takePhotoAndSave(tester, 'Leaking tap');

      await tester.tap(_within(find.text('Add angle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();

      final finding = container
          .read(activeSessionProvider)!
          .findings
          .singleWhere((f) => f.description == 'Leaking tap');
      expect(finding.evidence, hasLength(2));
      for (final photo in finding.evidence) {
        expect(
          _within(find.byKey(ValueKey('finding-photo-${photo.id}'))),
          findsOneWidget,
        );
      }
      expect(container.read(activeSessionProvider)!.findings, hasLength(1));
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

    // Edit note/Remove now live behind the finding card's overflow menu
    // — only "Add another photo" stays a direct icon button.
    await tester.tap(_within(find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Edited text');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(_within(find.text('Edited text')), findsOneWidget);
    expect(find.text('Original text'), findsNothing);

    await tester.tap(_within(find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Edited text'), findsNothing);
    expect(
      _within(find.textContaining('No findings recorded yet')),
      findsOneWidget,
    );
  });

  testWidgets('"No Defects · Mark Area Complete" completes an area with no '
      'findings, and it shows as Completed in the queue', (tester) async {
    final container = await _pumpToInspectionQueue(tester);
    final firstAreaName = container.read(inspectionQueueProvider).first.name;

    await tester.tap(_within(find.text(firstAreaName)));
    await tester.pumpAndSettle();

    await tester.tap(_within(find.text('No Defects · Mark Area Complete')));
    await tester.pumpAndSettle();
    expect(_within(find.text('Reopen Area')), findsOneWidget);

    _popRoute(tester);
    await tester.pumpAndSettle();

    expect(_within(find.text('Completed')), findsOneWidget);
  });

  testWidgets(
    'Complete Physical Inspection is disabled only until one area has been '
    'inspected; untouched suggested areas never block it (QA #13/#21)',
    (tester) async {
      final container = await _pumpToInspectionQueue(tester);

      var button = tester.widget<FilledButton>(
        _within(
          find.widgetWithText(FilledButton, 'Complete Physical Inspection'),
        ),
      );
      expect(button.onPressed, isNull);

      final queue = container.read(inspectionQueueProvider);
      container
          .read(sectionStatusesProvider.notifier)
          .setStatus(queue.first.id, SectionStatus.completed);
      await tester.pumpAndSettle();

      button = tester.widget<FilledButton>(
        _within(
          find.widgetWithText(FilledButton, 'Complete Physical Inspection'),
        ),
      );
      expect(button.onPressed, isNotNull);
      expect(queue.length, greaterThan(1), reason: 'others stay untouched');
    },
  );

  testWidgets(
    'completing the physical inspection with untouched suggested areas '
    'confirms what is left out, completes, and navigates to AI review',
    (tester) async {
      final container = await _pumpToInspectionQueue(tester);
      final queue = container.read(inspectionQueueProvider);
      final firstAreaName = queue.first.name;

      await tester.tap(_within(find.text(firstAreaName)));
      await tester.pumpAndSettle();
      await _takePhotoAndSave(tester, 'Hollow tile');
      _popRoute(tester);
      await tester.pumpAndSettle();

      await tester.tap(
        _within(
          find.widgetWithText(FilledButton, 'Complete Physical Inspection'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('${queue.length - 1} suggested areas not visited'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
      await tester.pumpAndSettle();

      final session = container.read(activeSessionProvider)!;
      expect(session.status, InspectionStatus.physicalInspectionComplete);
      expect(
        session.sectionStatuses[queue.first.id],
        SectionStatus.completed,
        reason: 'the started area is closed on completion',
      );
      expect(
        session.sectionStatuses[queue.last.id] ?? SectionStatus.notStarted,
        SectionStatus.notStarted,
        reason: 'untouched areas stay untouched',
      );
      expect(find.text('AI Review'), findsWidgets);
    },
  );
}
