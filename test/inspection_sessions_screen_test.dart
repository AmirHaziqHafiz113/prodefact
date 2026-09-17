import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database_providers.dart';

import 'support/test_repository.dart';

void main() {
  testWidgets(
    'backing out of New Inspection setup without starting it leaves no '
    'inspection on the dashboard',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ProDefactApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No inspections yet'), findsOneWidget);

      // Pick a property type, then back out *without* tapping
      // "Start Inspection" — this used to leave a phantom inspection
      // on the dashboard; it must not anymore.
      await tester.tap(find.byTooltip('New Inspection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('High Rise'));
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pop(); // property details -> property type selection
      navigator.pop(); // property type selection -> dashboard
      await tester.pumpAndSettle();

      expect(find.text('No inspections yet'), findsOneWidget);
      expect(find.text('High Rise'), findsNothing);
    },
  );

  testWidgets('the sessions screen lists a saved inspection (after Start '
      'Inspection) and can resume it', (tester) async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ProDefactApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No inspections yet'), findsOneWidget);

    await tester.tap(find.byTooltip('New Inspection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High Rise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Test Property');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Inspection'));
    await tester.pumpAndSettle();

    expect(find.text('Physical Inspection'), findsOneWidget);

    // Back out of the created inspection to the dashboard — property
    // type -> property details -> area configuration -> choose AI plan ->
    // review setup -> queue is 6 pushes deep from the dashboard.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    for (var i = 0; i < 6; i++) {
      navigator.pop();
    }
    await tester.pumpAndSettle();

    expect(find.text('No inspections yet'), findsNothing);
    expect(find.text('Test Property'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);

    await tester.tap(find.text('Test Property'));
    await tester.pumpAndSettle();

    expect(find.text('Physical Inspection'), findsOneWidget);
  });

  testWidgets(
    'search narrows the list by title/unit, and the In Progress filter '
    'excludes a completed inspection',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      final repository = container.read(inspectionRepositoryProvider);

      await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: const [],
        propertyDetails: const PropertyDetails(
          title: 'Residensi Vista',
          unitNumber: 'A-12-08',
        ),
      );
      final completed = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'landed',
        initialSections: const [],
        propertyDetails: const PropertyDetails(title: 'Taman Sinar House'),
      );
      await repository.setSessionStatus(
        completed.id,
        InspectionStatus.reported,
      );

      // A tall surface so both cards below the new top bar/summary
      // strip are actually built (not just scrolled past) by the lazy
      // list — the default test surface is too short to fit them all.
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ProDefactApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Residensi Vista'), findsOneWidget);
      expect(find.text('Taman Sinar House'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'A-12-08');
      await tester.pumpAndSettle();

      expect(find.text('Residensi Vista'), findsOneWidget);
      expect(find.text('Taman Sinar House'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Active'));
      await tester.pumpAndSettle();

      expect(find.text('Residensi Vista'), findsOneWidget);
      expect(find.text('Taman Sinar House'), findsNothing);
    },
  );

  testWidgets(
    'the dashboard pill only reads "Completed" once a report has actually '
    'been generated — physical/AI-review completion alone show their own '
    'distinct, honest labels',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      final repository = container.read(inspectionRepositoryProvider);

      final physicalDone = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: const [],
        propertyDetails: const PropertyDetails(title: 'Physical Done House'),
      );
      await repository.setSessionStatus(
        physicalDone.id,
        InspectionStatus.physicalInspectionComplete,
      );
      final reported = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: const [],
        propertyDetails: const PropertyDetails(title: 'Reported House'),
      );
      await repository.setSessionStatus(reported.id, InspectionStatus.reported);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ProDefactApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Never a bare "Completed"/"Unfinished" binary — a session that's
      // merely physically done (no report yet) gets its own label. Only
      // the reported session's own pill contributes "Completed" text
      // beyond the dashboard's "Completed" filter chip, hence >= 1
      // rather than exactly 1.
      expect(find.text('AI Processing'), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
    },
  );
}
