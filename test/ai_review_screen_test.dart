import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import 'support/test_repository.dart';

Finder _within(Finder matching) =>
    find.descendant(of: find.byType(Scaffold).last, matching: matching);

Future<ProviderContainer> _pumpToAiReview(WidgetTester tester) async {
  final container = ProviderContainer(overrides: testOverrides());
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ProDefactApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(_within(find.text('New Inspection')));
  await tester.pumpAndSettle();
  await tester.tap(_within(find.text('High Rise')));
  await tester.pumpAndSettle();
  await tester.enterText(
    _within(find.byType(TextFormField)).first,
    'Test Property',
  );
  await tester.tap(_within(find.text('Continue')));
  await tester.pumpAndSettle();
  await tester.tap(_within(find.text('Review & Start')));
  await tester.pumpAndSettle();
  await tester.tap(_within(find.text('Start Inspection')));
  await tester.pumpAndSettle();

  // Add one camera-first finding (with a photo) so there's something
  // for progressive AI to classify.
  final queue = container.read(inspectionQueueProvider);
  final section = queue.first;
  await tester.tap(_within(find.text(section.name)));
  await tester.pumpAndSettle();
  await tester.tap(_within(find.text('Take Defect Photo')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    ),
    'Cracked tile',
  );
  await tester.tap(
    find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text('Save Finding'),
    ),
  );
  await tester.pumpAndSettle();
  // Let the fire-and-forget AI classification actually run.
  await tester.pump();
  await tester.pump();

  final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
  navigator.pop();
  await tester.pumpAndSettle();
  expect(find.text('Physical Inspection'), findsOneWidget);

  final statusNotifier = container.read(sectionStatusesProvider.notifier);
  for (final s in queue) {
    statusNotifier.setStatus(s.id, SectionStatus.completed);
  }
  await tester.pump();

  await tester.tap(_within(find.text('Complete Physical Inspection')));
  await tester.pumpAndSettle();

  expect(find.text('AI Review'), findsOneWidget);
  return container;
}

void main() {
  testWidgets(
    'Continue to Report is gated until every AI suggestion is resolved, '
    'and review state survives navigating away and back',
    (tester) async {
      final container = await _pumpToAiReview(tester);

      final session = container.read(activeSessionProvider)!;
      expect(session.aiSuggestions, hasLength(1));

      var continueButton = tester.widget<FilledButton>(
        _within(find.widgetWithText(FilledButton, 'Continue to Report')),
      );
      expect(continueButton.onPressed, isNull);

      // Navigate away (back to the inspection queue) and forward again
      // — review state (the generated suggestion) must persist rather
      // than being regenerated or lost.
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Physical Inspection'), findsOneWidget);

      await tester.tap(_within(find.text('Complete Physical Inspection')));
      await tester.pumpAndSettle();

      final reloadedSession = container.read(activeSessionProvider)!;
      expect(reloadedSession.aiSuggestions, hasLength(1));
      expect(
        reloadedSession.aiSuggestions.single.id,
        session.aiSuggestions.single.id,
      );

      // Resolve the suggestion (Accept if confident, otherwise Change)
      // so "Continue to Report" unlocks.
      final suggestion = reloadedSession.aiSuggestions.single;
      if (suggestion.needsReview) {
        // "Change" opens a full-screen catalogue picker — pick the
        // first result.
        await tester.scrollUntilVisible(
          _within(find.text('Change')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        // The bottom nav bar floats over the tail of the scrollable
        // body — nudge further so the button clears it before tapping.
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
        await tester.pumpAndSettle();
        await tester.tap(_within(find.text('Change')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ListTile).first);
        await tester.pumpAndSettle();
      } else {
        await tester.scrollUntilVisible(
          _within(find.text('Accept')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
        await tester.pumpAndSettle();
        await tester.tap(_within(find.text('Accept')));
        await tester.pumpAndSettle();
      }

      continueButton = tester.widget<FilledButton>(
        _within(find.widgetWithText(FilledButton, 'Continue to Report')),
      );
      expect(continueButton.onPressed, isNotNull);

      await tester.tap(
        _within(find.widgetWithText(FilledButton, 'Continue to Report')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Report'), findsOneWidget);
    },
  );
}
