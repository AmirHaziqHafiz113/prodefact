import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/theme/design_system.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/report_details_screen.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';

import '../support/test_repository.dart';

/// Report Details is grouped into the same Property/Client &
/// Inspector/Dates sections as Property Details, so its report-only
/// metadata reads as a distinct, structured form rather than a long
/// unstructured field list (mission "REPORT DETAILS").
void main() {
  testWidgets(
    'report metadata is prefilled from Property Details and grouped into '
    'sections',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      container
          .read(newInspectionDraftProvider.notifier)
          .updatePropertyDetails(
            const PropertyDetails(
              title: 'Residensi Vista',
              clientName: 'Jane Client',
            ),
          );
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();

      // A tall surface so every grouped section is actually built (not
      // just scrolled past) by the lazy list.
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ReportDetailsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Residence / Unit Photo (optional, page 1) + the three data cards.
      expect(find.byType(AppFormSectionCard), findsNWidgets(4));
      expect(find.text('Residence / Unit Photo'), findsOneWidget);
      expect(find.text('Property'), findsOneWidget);
      expect(find.text('Client & Inspector'), findsOneWidget);
      expect(find.text('Dates'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Property / Inspection title'),
        findsOneWidget,
      );
      expect(find.text('Residensi Vista'), findsOneWidget);
      expect(find.text('Jane Client'), findsOneWidget);
    },
  );
}
