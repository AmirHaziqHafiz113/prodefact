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

  await tester.tap(_within(find.text('Start Home Inspection')));
  await tester.pumpAndSettle();
  await tester.tap(_within(find.text('New Inspection')));
  await tester.pumpAndSettle();
  await tester.tap(_within(find.text('High Rise')));
  await tester.pumpAndSettle();
  await tester.tap(_within(find.text('Continue')));
  await tester.pumpAndSettle();

  // Add one finding so there's something for AI to analyze.
  final queue = container.read(inspectionQueueProvider);
  final section = queue.first;
  container
      .read(activeSessionProvider.notifier)
      .addFinding(
        sectionId: section.id,
        elementId: section.elements.first.id,
        description: 'Cracked tile',
      );
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

      await tester.tap(_within(find.text('Start AI Analysis')));
      await tester.pumpAndSettle();

      expect(_within(find.text('Accept')), findsOneWidget);

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

      expect(_within(find.text('Accept')), findsOneWidget);
      final session = container.read(activeSessionProvider)!;
      expect(session.aiSuggestions, hasLength(1));

      await tester.tap(_within(find.text('Accept')));
      await tester.pumpAndSettle();

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
