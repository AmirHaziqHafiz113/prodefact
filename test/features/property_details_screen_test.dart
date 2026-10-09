import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';

import '../support/test_repository.dart';

Future<void> _pumpToBasicDetails(WidgetTester tester) async {
  // A tall surface so every grouped field section is actually built
  // (not just scrolled past) by the lazy list — the default test
  // surface is too short to fit the wizard stepper plus all three
  // section cards at once.
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(
    ProviderScope(overrides: testOverrides(), child: const ProDefactApp()),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Capture'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('High Rise'));
  await tester.pumpAndSettle();

  expect(find.text('Basic Details'), findsOneWidget);
}

/// New Inspection setup, step 2: Basic Details, between property type
/// selection and area configuration — see `PropertyDetailsScreen`. Only
/// Unit No. is required (the QA/QC setup-simplification pass);
/// everything else captured here later shows on the Review Setup
/// summary, the dashboard card, and the report cover page, or can be
/// completed later via Report Details.
void main() {
  testWidgets('Continue is blocked until the required Unit No. is filled '
      'in', (tester) async {
    await _pumpToBasicDetails(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Validation failed — still on Basic Details, never reached area
    // configuration.
    expect(find.text('Basic Details'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets(
    'every field other than Unit No. can be left blank — "Skip optional '
    'details / Complete later" reaches area configuration exactly like '
    'Continue',
    (tester) async {
      await _pumpToBasicDetails(tester);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Unit No. *'),
        'A-12-08',
      );
      await tester.tap(
        find.text('Skip optional details / Complete later'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Configure Areas'), findsOneWidget);
    },
  );

  testWidgets('filling in Unit No. (and other fields) continues to area '
      'configuration, and the values appear on the Review Setup summary '
      '— with no AI Plan/commercial step in between', (tester) async {
    await _pumpToBasicDetails(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Unit No. *'),
      'A-12-08',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Inspection / Property title'),
      'Residensi Vista',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Property address'),
      '1 Jalan Test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Client / Agent Name'),
      'Jane Client',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Configure Areas'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Straight to Review Setup — no "Choose AI Plan"/commercial step.
    expect(find.text('Choose AI Plan'), findsNothing);
    expect(find.text('Review Setup'), findsOneWidget);
    expect(find.text('Residensi Vista'), findsOneWidget);
    expect(find.text('1 Jalan Test'), findsOneWidget);
    expect(find.text('A-12-08'), findsOneWidget);
    expect(find.text('Jane Client'), findsOneWidget);
  });
}
