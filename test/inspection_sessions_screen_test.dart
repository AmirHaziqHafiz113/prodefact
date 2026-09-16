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

      expect(find.text('No saved inspections yet.'), findsOneWidget);

      // Pick a property type, then back out *without* tapping
      // "Start Inspection" — this used to leave a phantom inspection
      // on the dashboard; it must not anymore.
      await tester.tap(find.text('New Inspection'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('High Rise'));
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pop(); // property details -> property type selection
      navigator.pop(); // property type selection -> dashboard
      await tester.pumpAndSettle();

      expect(find.text('No saved inspections yet.'), findsOneWidget);
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

    expect(find.text('No saved inspections yet.'), findsOneWidget);

    await tester.tap(find.text('New Inspection'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('High Rise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Test Property');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review & Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Inspection'));
    await tester.pumpAndSettle();

    expect(find.text('Physical Inspection'), findsOneWidget);

    // Back out of the created inspection to the dashboard — property
    // type -> property details -> area configuration -> review setup ->
    // queue is 5 pushes deep from the dashboard.
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    for (var i = 0; i < 5; i++) {
      navigator.pop();
    }
    await tester.pumpAndSettle();

    expect(find.text('No saved inspections yet.'), findsNothing);
    expect(find.text('Test Property'), findsOneWidget);
    expect(find.text('Unfinished'), findsOneWidget);

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
      await tester.tap(find.widgetWithText(ChoiceChip, 'In Progress'));
      await tester.pumpAndSettle();

      expect(find.text('Residensi Vista'), findsOneWidget);
      expect(find.text('Taman Sinar House'), findsNothing);
    },
  );
}
