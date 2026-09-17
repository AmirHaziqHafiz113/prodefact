import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// The "Found another issue?" tip duplicated the sticky primary
/// action's own instruction — removed. The primary action itself now
/// carries that information: "Take Defect Photo" before any finding
/// exists, "Take Another Defect Photo" once at least one does.
void main() {
  testWidgets(
    'the redundant tip is gone, and the primary action label reflects '
    'whether a finding already exists',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      final section = container.read(inspectionQueueProvider).first;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: AreaInspectionScreen(sectionId: section.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Found another issue?'), findsNothing);
      expect(find.text('Take Defect Photo'), findsOneWidget);
      expect(find.text('Take Another Defect Photo'), findsNothing);

      final notifier = container.read(activeSessionProvider.notifier);
      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      notifier.saveCameraFinding(
        sectionId: section.id,
        photo: photo!,
        note: 'Cracked tile',
      );
      await tester.pumpAndSettle();

      expect(find.text('Found another issue?'), findsNothing);
      expect(find.text('Take Another Defect Photo'), findsOneWidget);
      expect(find.text('Take Defect Photo'), findsNothing);
    },
  );
}
