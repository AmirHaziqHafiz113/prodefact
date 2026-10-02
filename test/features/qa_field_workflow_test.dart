import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/inspection_queue_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/wallet_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/scripted_billing_service.dart';
import '../support/test_repository.dart';

/// Checkpoint 1 of the QA/QC closure pass: the field inspection flow.
/// QA #13/#21 optional areas, #22 physical completion independent of
/// AI, #23 no billing choice in the field, #24 Smart only, #15 sheets
/// whose actions stay visible, #25 working status filters.

Future<ProviderContainer> _startedContainer({
  BillingService? billing,
  CommercialMode? commercialMode,
}) async {
  final container = ProviderContainer(
    overrides: testOverrides(billingService: billing),
  );
  await container
      .read(activeSessionProvider.notifier)
      .startNew(PropertyType.highRise, commercialMode: commercialMode);
  return container;
}

Future<Finding> _saveFinding(
  ProviderContainer container,
  String sectionId, {
  String note = 'Hollow tile',
}) async {
  final notifier = container.read(activeSessionProvider.notifier);
  final photo = await notifier.captureFindingPhoto(
    source: EvidenceSource.camera,
  );
  return notifier.saveCameraFinding(
    sectionId: sectionId,
    photo: photo!,
    note: note,
  );
}

void main() {
  group('QA #13 / #21: suggested areas are optional', () {
    test('inspecting only the areas the unit has lets the inspection '
        'complete; nonexistent areas need no finding and no status', () async {
      final container = await _startedContainer();
      addTearDown(container.dispose);
      final queue = container.read(inspectionQueueProvider);
      expect(queue.length, greaterThanOrEqualTo(4));

      // The unit has only the first three suggested areas.
      final real = queue.take(3).toList();
      await _saveFinding(container, real[0].id);
      await _saveFinding(container, real[1].id);
      container
          .read(sectionStatusesProvider.notifier)
          .setStatus(real[2].id, SectionStatus.completed);
      await pumpEventQueue();

      final notifier = container.read(activeSessionProvider.notifier);
      expect(await notifier.markPhysicalInspectionComplete(), isTrue);

      final session = container.read(activeSessionProvider)!;
      expect(session.status, InspectionStatus.physicalInspectionComplete);
      for (final area in real) {
        expect(session.sectionStatuses[area.id], SectionStatus.completed);
      }
      for (final area in queue.skip(3)) {
        expect(
          areaVisitStateOf(session, area),
          AreaVisitState.untouched,
          reason: '${area.name} was never visited and stays that way',
        );
      }
      final progress = PhysicalProgress.of(session);
      expect(progress.totalAreas, 3);
      expect(progress.completed, 3);
      expect(progress.untouchedSuggested, queue.length - 3);
    });

    test('the report covers only inspected areas: an absent area is never '
        'printed as "No defects recorded"', () async {
      final container = await _startedContainer();
      addTearDown(container.dispose);
      final queue = container.read(inspectionQueueProvider);
      await _saveFinding(container, queue[0].id);
      container
          .read(sectionStatusesProvider.notifier)
          .setStatus(queue[1].id, SectionStatus.completed);
      await pumpEventQueue();

      final model = buildReportModel(
        session: container.read(activeSessionProvider)!,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 9, 25),
      );

      expect(model.areas.map((a) => a.name), [queue[0].name, queue[1].name]);
      expect(model.areas[1].findings, isEmpty, reason: 'clean, but inspected');
      expect(model.totalAreas, 2);
    });

    test('completion is refused while nothing has been inspected', () async {
      final container = await _startedContainer();
      addTearDown(container.dispose);

      final completed = await container
          .read(activeSessionProvider.notifier)
          .markPhysicalInspectionComplete();

      expect(completed, isFalse);
      expect(
        container.read(activeSessionProvider)!.status,
        InspectionStatus.inProgress,
      );
    });
  });

  group('QA #22: physical completion is independent of AI', () {
    test('the site visit completes while AI is still analysing; the report '
        'waits for AI, and AI finishes afterwards', () async {
      final billing = ScriptedBillingService()..gate = Completer<void>();
      final container = await _startedContainer(billing: billing);
      addTearDown(container.dispose);
      final notifier = container.read(activeSessionProvider.notifier);
      final queue = container.read(inspectionQueueProvider);

      final finding = await _saveFinding(container, queue.first.id);
      await pumpEventQueue(times: 200);
      expect(billing.calls, hasLength(1), reason: 'analysis is in flight');
      expect(
        aiFindingStatusIsInFlight(
          container.read(activeSessionProvider)!.findings.single.aiStatus,
        ),
        isTrue,
      );

      expect(await notifier.markPhysicalInspectionComplete(), isTrue);
      expect(
        container.read(activeSessionProvider)!.status,
        InspectionStatus.physicalInspectionComplete,
      );

      final early = await notifier.generateReport();
      expect(early.outcome, ReportGenerationOutcome.aiReviewIncomplete);

      billing.gate!.complete();
      await pumpEventQueue(times: 200);
      final after = container.read(activeSessionProvider)!;
      expect(
        after.findings.singleWhere((f) => f.id == finding.id).aiStatus,
        isIn([AiFindingStatus.completed, AiFindingStatus.needsReview]),
      );
      expect(after.status, isNot(InspectionStatus.inProgress));
    });
  });

  group('QA #23: billing is invisible in the field', () {
    testWidgets('the inspection screen offers no House Pass purchase, '
        'banner, or billing choice, even on a House Pass inspection with no '
        'pass bought', (tester) async {
      final container = await _startedContainer(
        commercialMode: CommercialMode.housePass,
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionQueueScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('House Pass'), findsNothing);
      expect(find.textContaining('purchase required'), findsNothing);
      expect(find.textContaining('Flex Credits'), findsNothing);
      expect(find.textContaining('House Pass'), findsNothing);
    });

    testWidgets('House Pass is bought from the Wallet, per open inspection', (
      tester,
    ) async {
      final container = await _startedContainer();
      addTearDown(container.dispose);
      final sessionId = container.read(activeSessionProvider)!.id;
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: WalletScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('house-pass-$sessionId')), findsOneWidget);
    });

    test('recording a House Pass for a non-active inspection updates that '
        'inspection, never the one currently open', () async {
      final billing = FakeBillingService();
      final container = await _startedContainer(billing: billing);
      addTearDown(container.dispose);
      final notifier = container.read(activeSessionProvider.notifier);
      final firstId = container.read(activeSessionProvider)!.id;
      await notifier.startNew(PropertyType.landed);
      final activeId = container.read(activeSessionProvider)!.id;
      expect(activeId, isNot(firstId));

      await notifier.applyHousePassToSession(firstId, passActive: true);

      final active = container.read(activeSessionProvider)!;
      expect(active.commercialMode, isNot(CommercialMode.housePass));
      final stored = await container
          .read(activeSessionProvider.notifier)
          .resume(firstId);
      expect(stored, isTrue);
      final first = container.read(activeSessionProvider)!;
      expect(first.commercialMode, CommercialMode.housePass);
    });
  });

  group('QA #25: area status filters', () {
    testWidgets('each filter visibly selects, narrows the list to real '
        'data, shows a true count, and has an intentional empty state', (
      tester,
    ) async {
      final container = await _startedContainer();
      addTearDown(container.dispose);
      final queue = container.read(inspectionQueueProvider);
      await _saveFinding(container, queue[0].id);
      container
          .read(sectionStatusesProvider.notifier)
          .setStatus(queue[1].id, SectionStatus.completed);
      await tester.runAsync(() => pumpEventQueue());
      tester.view.physicalSize = const Size(800, 6000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionQueueScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final untouched = queue.length - 2;
      expect(find.text('All (${queue.length})'), findsOneWidget);
      expect(find.text('Not started ($untouched)'), findsOneWidget);
      expect(find.text('In progress (1)'), findsOneWidget);
      expect(find.text('Completed (1)'), findsOneWidget);

      Future<void> select(String label) async {
        // The chip row scrolls horizontally, as it does on a phone.
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final chip = tester.widget<ChoiceChip>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(ChoiceChip),
          ),
        );
        expect(chip.selected, isTrue);
      }

      await select('In progress (1)');
      expect(find.text(queue[0].name), findsOneWidget);
      expect(find.text(queue[1].name), findsNothing);

      await select('Completed (1)');
      expect(find.text(queue[1].name), findsOneWidget);
      expect(find.text(queue[0].name), findsNothing);

      await select('Not started ($untouched)');
      expect(find.text(queue[0].name), findsNothing);
      expect(find.text(queue[1].name), findsNothing);
      expect(find.text(queue.last.name), findsOneWidget);

      // Complete the remaining areas: "Not started" becomes an
      // intentional empty state rather than a blank list.
      for (final area in queue.skip(2)) {
        container
            .read(sectionStatusesProvider.notifier)
            .setStatus(area.id, SectionStatus.completed);
      }
      await tester.pumpAndSettle();
      await select('Not started (0)');
      expect(find.text('No not started areas'), findsOneWidget);
    });
  });

  group('QA #15: bottom sheet actions stay visible', () {
    Future<void> openPreviewSheet(
      WidgetTester tester, {
      required Size size,
      double textScale = 1.0,
      double keyboard = 0,
    }) async {
      final container = await _startedContainer();
      addTearDown(container.dispose);
      final sectionId = container.read(inspectionQueueProvider).first.id;
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(bottom: 48);
      tester.view.viewPadding = const FakeViewPadding(bottom: 48);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: AreaInspectionScreen(sectionId: sectionId)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take Defect Photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Camera'));
      await tester.pumpAndSettle();
      if (keyboard > 0) {
        await tester.showKeyboard(find.byType(TextField).last);
        tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
        await tester.pumpAndSettle();
      }
    }

    void expectOnScreen(
      WidgetTester tester,
      String label, {
      double keyboard = 0,
    }) {
      final rect = tester.getRect(find.widgetWithText(FilledButton, label));
      final screen = tester.view.physicalSize;
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(
        rect.bottom,
        lessThanOrEqualTo(screen.height - 48 - keyboard + 0.5),
        reason: '"$label" must sit above the navigation bar and keyboard',
      );
    }

    testWidgets('small phone, large text, Android navigation bar', (
      tester,
    ) async {
      await openPreviewSheet(
        tester,
        size: const Size(320, 540),
        textScale: 1.6,
      );
      expectOnScreen(tester, 'Save Finding');
      await tester.tap(find.widgetWithText(FilledButton, 'Save Finding'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(FilledButton, 'Save Finding'), findsNothing);
    });

    testWidgets('keyboard open on a small phone', (tester) async {
      await openPreviewSheet(tester, size: const Size(360, 640), keyboard: 280);
      expectOnScreen(tester, 'Save Finding', keyboard: 280);
    });
  });
}
