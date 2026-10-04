import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import 'support/test_repository.dart';
import 'support/photo_guide_helper.dart';
import 'support/uncertain_ai_billing_service.dart';

Finder _within(Finder matching) =>
    find.descendant(of: find.byType(Scaffold).last, matching: matching);

Future<ProviderContainer> _pumpToAiReview(WidgetTester tester) async {
  // An uncertain AI result: never auto-accepted, so it waits for review.
  final container = ProviderContainer(
    overrides: testOverrides(billingService: UncertainAiBillingService()),
  );
  addTearDown(container.dispose);

  // A tall surface so every area card is actually built (not just
  // scrolled past) by the lazy list on the inspection queue screen
  // this flow passes through.
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
  await passPhotoGuide(tester);
  // Auto Analyse on so saving a finding queues AI immediately — this
  // suite is about AI review, not the separate estimate/approval gate
  // (covered by `ai_gating_regression_test.dart`).

  // Add one camera-first finding (with a photo) so there's something
  // for progressive AI to classify.
  final queue = container.read(inspectionQueueProvider);
  final section = queue.first;
  await tester.tap(_within(find.text(section.name)));
  await tester.pumpAndSettle();
  await tester.tap(_within(find.text('Take Defect Photo')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Camera'));
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
  // Confirm the completion summary dialog.
  await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
  await tester.pumpAndSettle();

  expect(find.text('AI Review'), findsOneWidget);
  return container;
}

void main() {
  testWidgets(
    'Continue to Report is never a dead end (QA #32/#33): it stays '
    'tappable while a note explains the pending review, and review state '
    'survives navigating away and back',
    (tester) async {
      final container = await _pumpToAiReview(tester);

      final session = container.read(activeSessionProvider)!;
      expect(session.aiSuggestions, hasLength(1));

      var continueButton = tester.widget<FilledButton>(
        _within(find.widgetWithText(FilledButton, 'Continue to Report')),
      );
      expect(continueButton.onPressed, isNotNull);
      expect(
        _within(find.textContaining('1 finding to review')),
        findsOneWidget,
      );

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
      // Confirm the completion summary dialog.
      await tester.tap(find.widgetWithText(FilledButton, 'Complete'));
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
      expect(find.textContaining('to review'), findsNothing);

      await tester.tap(
        _within(find.widgetWithText(FilledButton, 'Continue to Report')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Report'), findsOneWidget);
    },
  );
}
