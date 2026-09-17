import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';

import '../support/test_repository.dart';

Future<void> _pumpToPropertyDetails(WidgetTester tester) async {
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

  await tester.tap(find.byTooltip('New Inspection'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('High Rise'));
  await tester.pumpAndSettle();

  expect(find.text('Property Details'), findsOneWidget);
}

/// New Inspection setup, step 2: Property Details, between property type
/// selection and area configuration — see `PropertyDetailsScreen`. Only
/// the title is required; everything captured here later shows on the
/// Review Setup summary, the dashboard card, and the report cover page.
void main() {
  testWidgets('Continue is blocked until the required title is filled in', (
    tester,
  ) async {
    await _pumpToPropertyDetails(tester);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Validation failed — still on Property Details, never reached
    // area configuration.
    expect(find.text('Property Details'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('filling in the title (and other fields) continues to area '
      'configuration, and the values appear on the Review Setup summary', (
    tester,
  ) async {
    await _pumpToPropertyDetails(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Inspection / Property title *'),
      'Residensi Vista',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Property address'),
      '1 Jalan Test',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Unit number'),
      'A-12-08',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Client / Owner name'),
      'Jane Client',
    );
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Configure Areas'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Choose AI Plan'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Review Setup'), findsOneWidget);
    expect(find.text('Residensi Vista'), findsOneWidget);
    expect(find.text('1 Jalan Test'), findsOneWidget);
    expect(find.text('A-12-08'), findsOneWidget);
    expect(find.text('Jane Client'), findsOneWidget);
  });
}
