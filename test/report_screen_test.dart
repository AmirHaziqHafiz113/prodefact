import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:prodefact/app/app.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import 'support/fake_report_services.dart';
import 'support/test_repository.dart';

Finder _within(Finder matching) =>
    find.descendant(of: find.byType(Scaffold).last, matching: matching);

/// Pumps the app all the way to the Report screen in its "not
/// generated" state (AI review complete, report not yet generated) —
/// this never mounts `PdfPreview`, so it stays safe to pump in a
/// headless test environment.
Future<ProviderContainer> _pumpToReportScreen(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  final container = ProviderContainer(overrides: overrides);
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
  // Auto Analyse on so saving a finding queues AI immediately — this
  // suite is about report generation, not the separate estimate/
  // approval gate (covered by `ai_gating_regression_test.dart`).

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

  final suggestion = container
      .read(activeSessionProvider)!
      .aiSuggestions
      .single;
  // A confident result is accepted automatically — nothing to resolve.
  if (!suggestion.isResolved) {
    final resolveLabel = suggestion.needsReview ? 'Change' : 'Accept';
    await tester.scrollUntilVisible(
      _within(find.text(resolveLabel)),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // The bottom nav bar floats over the tail of the scrollable body —
    // nudge further so the button clears it before tapping.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(_within(find.text(resolveLabel)));
    await tester.pumpAndSettle();
    if (suggestion.needsReview) {
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();
    }
  }

  await tester.tap(
    _within(find.widgetWithText(FilledButton, 'Continue to Report')),
  );
  await tester.pumpAndSettle();

  expect(find.text('Report'), findsOneWidget);
  return container;
}

void main() {
  testWidgets('the report screen starts in the not-generated state with a '
      'Generate Report button', (tester) async {
    await _pumpToReportScreen(tester, overrides: testOverrides());

    expect(_within(find.text('Generate Report')), findsOneWidget);
  });

  testWidgets('tapping Generate Report shows a failure banner when generation '
      'fails, without losing the underlying inspection data', (tester) async {
    final renderer = FakeReportRenderer()
      ..failNextRenderWith = Exception('disk full');
    final container = await _pumpToReportScreen(
      tester,
      overrides: testOverrides(reportRenderer: renderer),
    );
    container.read(activeSessionProvider.notifier).setReportMetadata(
      const ReportMetadata(
        title: 'Test Property',
        contactNumber: '+60123456789',
      ),
    );

    await tester.tap(_within(find.text('Generate Report')));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.textContaining('Report generation failed'), findsOneWidget);
    // The report screen falls back to the not-generated view again —
    // Generate Report is still offered, PdfPreview is never mounted.
    expect(_within(find.text('Generate Report')), findsOneWidget);

    final session = container.read(activeSessionProvider)!;
    expect(session.report, isNull);
    expect(session.findings, hasLength(1));
  });
}
