import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/router/app_shell_screen.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/areas_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/finding_detail_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/inspection_overview_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/past_inspection_screens.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/report_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

Finder _top(Finder matching) =>
    find.descendant(of: find.byType(Scaffold).last, matching: matching);

/// One completed (reported) inspection with a finding, plus one active
/// inspection.
Future<(ProviderContainer, String, String)> _seed(WidgetTester tester) async {
  late ProviderContainer container;
  late String pastId;
  late String activeId;
  await tester.runAsync(() async {
    container = ProviderContainer(overrides: testOverrides());
    final notifier = container.read(activeSessionProvider.notifier);
    await notifier.startNew(
      PropertyType.highRise,
      propertyDetails: const PropertyDetails(
        title: 'Residensi Vista',
        clientName: 'Aisyah',
        inspectorName: 'Hafiz',
      ),
    );
    pastId = container.read(activeSessionProvider)!.id;
    final section = container.read(inspectionQueueProvider).first.id;
    final captured = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: section,
      photo: captured!,
      note: 'Hollow tile',
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await container
        .read(inspectionRepositoryProvider)
        .setSessionStatus(pastId, InspectionStatus.reported);

    await notifier.startNew(
      PropertyType.landed,
      propertyDetails: const PropertyDetails(title: 'Taman Sinar House'),
    );
    activeId = container.read(activeSessionProvider)!.id;
    notifier.clear();
  });
  addTearDown(container.dispose);
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ProDefactApp()),
  );
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(AppBottomNav),
      matching: find.text('Inspections'),
    ),
  );
  await tester.pumpAndSettle();
  return (container, pastId, activeId);
}

Future<void> _openPast(WidgetTester tester, String pastId) async {
  await tester.tap(find.text('Past (1)'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('past-card-$pastId')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Active and Past are separate: the completed job appears only '
      'under Past, never duplicated in Active', (tester) async {
    final (_, pastId, _) = await _seed(tester);

    expect(find.text('Active (1)'), findsOneWidget);
    expect(find.text('Past (1)'), findsOneWidget);
    expect(find.text('Taman Sinar House'), findsOneWidget);
    expect(find.text('Residensi Vista'), findsNothing);

    await tester.tap(find.text('Past (1)'));
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('past-card-$pastId')), findsOneWidget);
    expect(find.text('Residensi Vista'), findsOneWidget);
    expect(find.text('Taman Sinar House'), findsNothing);
    // Inspector/client summary on the card.
    expect(find.textContaining('Inspector Hafiz'), findsOneWidget);
    expect(find.textContaining('Client Aisyah'), findsOneWidget);
  });

  testWidgets('a completed inspection opens Past Inspection Detail (not the '
      'editable Overview) with its history facts', (tester) async {
    final (_, pastId, _) = await _seed(tester);
    await _openPast(tester, pastId);

    final detail = tester.widget<PastInspectionDetailScreen>(
      find.byType(PastInspectionDetailScreen),
    );
    expect(detail.sessionId, pastId);
    expect(find.byType(InspectionOverviewScreen), findsNothing);
    expect(_top(find.text('Residensi Vista')), findsOneWidget);
    expect(_top(find.text('Inspector: Hafiz')), findsOneWidget);
    expect(_top(find.text('Client / purchaser: Aisyah')), findsOneWidget);
    expect(_top(find.byKey(const ValueKey('past-report-status'))), findsOne);
    for (final key in [
      'past-view-areas',
      'past-view-findings',
      'past-view-report',
      'past-view-photos',
    ]) {
      expect(_top(find.byKey(ValueKey(key))), findsOneWidget, reason: key);
    }
  });

  testWidgets('the past view is read-only: areas, area findings and finding '
      'detail offer no capture, edit, reanalyse, reject or delete', (
    tester,
  ) async {
    final (container, pastId, _) = await _seed(tester);
    await _openPast(tester, pastId);
    expect(container.read(inspectionReadOnlyProvider), isTrue);

    await tester.tap(_top(find.byKey(const ValueKey('past-view-areas'))));
    await tester.pumpAndSettle();
    expect(find.byType(AreasScreen), findsOneWidget);
    expect(_top(find.text('Add Newly Discovered Area')), findsNothing);

    final firstArea = container.read(inspectionQueueProvider).first;
    await tester.tap(_top(find.text(firstArea.name)));
    await tester.pumpAndSettle();
    expect(find.byType(AreaInspectionScreen), findsOneWidget);
    expect(_top(find.text('Take Another Defect Photo')), findsNothing);
    expect(_top(find.text('Take Defect Photo')), findsNothing);
    expect(_top(find.byIcon(Icons.more_vert)), findsNothing);
    expect(_top(find.text('Mark Area Complete')), findsNothing);
    expect(_top(find.textContaining('Reanalyse')), findsNothing);
    expect(_top(find.text('Delete')), findsNothing);
    expect(_top(find.text('Completed inspection — view only.')), findsOne);

    final finding = container.read(activeSessionProvider)!.findings.single;
    await tester.tap(_top(find.byKey(ValueKey('finding-details-${finding.id}'))));
    await tester.pumpAndSettle();
    expect(find.byType(FindingDetailScreen), findsOneWidget);
    expect(find.byTooltip('Edit note'), findsNothing);
    expect(_top(find.byKey(ValueKey('reanalyse-finding-${finding.id}'))),
        findsNothing);
    expect(_top(find.byKey(ValueKey('delete-finding-${finding.id}'))),
        findsNothing);
    expect(_top(find.text('Hollow tile')), findsWidgets);
  });

  testWidgets('View Report opens the existing Report screen; View Findings '
      'and View Photos list the historical record', (tester) async {
    final (_, pastId, _) = await _seed(tester);
    await _openPast(tester, pastId);

    await tester.tap(_top(find.byKey(const ValueKey('past-view-report'))));
    await tester.pumpAndSettle();
    expect(find.byType(ReportScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(_top(find.byKey(const ValueKey('past-view-findings'))));
    await tester.pumpAndSettle();
    expect(find.byType(PastFindingsScreen), findsOneWidget);
    expect(_top(find.byType(ListTile)), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(_top(find.byKey(const ValueKey('past-view-photos'))));
    await tester.pumpAndSettle();
    expect(find.byType(PastPhotosScreen), findsOneWidget);
    expect(_top(find.text('Photos (1)')), findsOneWidget);
  });

  testWidgets('an active inspection still opens its editable Overview', (
    tester,
  ) async {
    await _seed(tester);
    await tester.tap(find.text('Taman Sinar House'));
    await tester.pumpAndSettle();
    expect(find.byType(InspectionOverviewScreen), findsOneWidget);
    expect(find.byType(PastInspectionDetailScreen), findsNothing);
  });
}
