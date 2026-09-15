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
  await tester.tap(_within(find.text('Start AI Analysis')));
  await tester.pumpAndSettle();
  await tester.tap(_within(find.text('Accept')));
  await tester.pumpAndSettle();

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
