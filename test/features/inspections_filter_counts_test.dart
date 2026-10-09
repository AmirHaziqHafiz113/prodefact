import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/router/app_shell_screen.dart';
import 'package:prodefact/app/theme/design_system.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database_providers.dart';

import '../support/test_repository.dart';

/// The Inspections screen has no separate metric strip any more — its
/// filter chips already carry the real counts, so the same numbers are
/// never shown twice (docs/ux_architecture.md).
void main() {
  testWidgets(
    'the filter chips carry real counts, and no duplicate metric strip is '
    'shown',
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

      await tester.tap(
        find.descendant(
          of: find.byType(AppBottomNav),
          matching: find.text('Inspections'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppMetricCard), findsNothing);
      // Two real in-progress inspections (both still drafts — nothing
      // recorded), none needing review, one real completed inspection.
      for (final label in [
        'All (3)',
        'Draft (2)',
        'Active (2)',
        'Needs Review (0)',
        'Report Ready (0)',
        'Completed (1)',
      ]) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
      }
    },
  );
}
