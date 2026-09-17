import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/theme/design_system.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database_providers.dart';

import '../support/test_repository.dart';

/// The Inspections summary strip is one grouped/bordered row of inline
/// metrics, not three separate count cards
/// (docs/prodefact_design_system.md §9, mission §8 "SUMMARY").
void main() {
  testWidgets(
    'the summary strip shows real active/needs-review/completed counts',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      final repository = container.read(inspectionRepositoryProvider);

      await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: const [],
        propertyDetails: const PropertyDetails(title: 'Active One'),
      );
      await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        initialSections: const [],
        propertyDetails: const PropertyDetails(title: 'Active Two'),
      );
      final completed = await repository.createSession(
        industry: Industry.homeInspection,
        assetTypeId: 'landed',
        initialSections: const [],
        propertyDetails: const PropertyDetails(title: 'Completed One'),
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

      // The dashboard tab is the initial landing screen. The strip is
      // one bordered container of three inline metrics — never three
      // separate count cards.
      final metrics = tester
          .widgetList<AppMetricCard>(find.byType(AppMetricCard))
          .toList();
      expect(metrics.map((m) => m.label), [
        'Active',
        'Needs Review',
        'Completed',
      ]);
      // Two real active inspections, zero needing review, one real
      // completed inspection — never a fabricated count.
      expect(metrics.map((m) => m.value), ['2', '0', '1']);

      expect(
        find.ancestor(
          of: find.byType(AppMetricCard).first,
          matching: find.byType(Card),
        ),
        findsNothing,
      );
    },
  );
}
