import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';
import 'package:prodefact/data/remote/remote_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/ai_analysis_approval_dialog.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/ai_review_overview_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/inspection_queue_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/report_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';
import 'package:go_router/go_router.dart';

import '../support/fake_auth_service.dart';
import '../support/fake_cloud_inspection_repository.dart';
import '../support/scripted_billing_service.dart';
import '../support/test_repository.dart';

/// Real-device P0 pass: QA #26/#27 (queue drains by itself), #29
/// (provider failures reach a visible terminal state), #32/#33
/// (completion and the screens after it are never a dead end).

typedef _Setup = ({
  ProviderContainer container,
  ScriptedBillingService billing,
  FakeCloudInspectionRepository cloud,
  DriftInspectionRepository repo,
});

/// Signed in, online, Firebase-ready: the real upload-then-analyse path.
Future<_Setup> _online({ScriptedBillingService? billing}) async {
  final repo = createInMemoryRepository();
  final resolvedBilling = billing ?? ScriptedBillingService();
  final cloud = FakeCloudInspectionRepository();
  final container = ProviderContainer(
    overrides: testOverridesWithSync(
      repository: repo,
      billingService: resolvedBilling,
      authService: FakeAuthService(initialUser: testAuthUser),
      cloudRepository: cloud,
    ),
  );
  await container
      .read(activeSessionProvider.notifier)
      .startNew(PropertyType.highRise);
  container.read(activeSessionProvider.notifier).setAutoAnalyseEnabled(true);
  return (
    container: container,
    billing: resolvedBilling,
    cloud: cloud,
    repo: repo,
  );
}

Future<Finding> _save(
  ProviderContainer container,
  String note, {
  int area = 0,
}) async {
  final notifier = container.read(activeSessionProvider.notifier);
  final photo = await notifier.captureFindingPhoto(
    source: EvidenceSource.camera,
  );
  return notifier.saveCameraFinding(
    sectionId: container.read(inspectionQueueProvider)[area].id,
    photo: photo!,
    note: note,
  );
}

List<Finding> _findings(ProviderContainer c) =>
    c.read(activeSessionProvider)!.findings;

/// Drains async work on the test clock (so timers stay controllable).
Future<void> _drain(WidgetTester tester) async {
  for (var i = 0; i < 60; i++) {
    await tester.pump();
  }
}

bool _terminal(AiFindingStatus s) =>
    s == AiFindingStatus.completed || s == AiFindingStatus.needsReview;

void main() {
  group('QA #26/#27: the queue drains by itself', () {
    test('1 + 4. an online finding leaves "Queued for AI" and completes, '
        'with no reconnect or reopen', () async {
      final setup = await _online();
      addTearDown(setup.container.dispose);

      final finding = await _save(setup.container, 'Tile holo');
      await pumpEventQueue(times: 400);

      final stored = _findings(setup.container).single;
      expect(stored.id, finding.id);
      expect(_terminal(stored.aiStatus), isTrue, reason: '${stored.aiStatus}');
      expect(setup.billing.calls, hasLength(1));
    });

    test('2. three findings saved back to back all upload and complete '
        'independently: no session-wide lock parks any of them', () async {
      final setup = await _online();
      addTearDown(setup.container.dispose);

      await _save(setup.container, 'Tile holo');
      await _save(setup.container, 'Win frem gap', area: 1);
      await _save(setup.container, 'Poor skim finish', area: 2);
      await pumpEventQueue(times: 800);

      final findings = _findings(setup.container);
      expect(findings, hasLength(3));
      for (final f in findings) {
        expect(_terminal(f.aiStatus), isTrue, reason: '${f.id} ${f.aiStatus}');
        expect(
          f.evidence.every((e) => e.syncStatus == SyncStatus.synced),
          isTrue,
        );
      }
      expect(setup.billing.calls, hasLength(3), reason: 'one job per finding');
      expect(setup.billing.providerRuns, 3, reason: 'no duplicate charge');
    });

    testWidgets('3. an upload that fails while online retries by itself on '
        'a timer and completes; no reconnect is needed', (tester) async {
      final setup = await _online();
      addTearDown(setup.container.dispose);
      setup.cloud.failEveryCallWith = Exception('Storage unavailable');
      await _save(setup.container, 'Tile holo');
      await _drain(tester);
      expect(
        _findings(setup.container).single.aiStatus,
        AiFindingStatus.queued,
        reason: 'waiting for its automatic retry',
      );
      expect(setup.billing.calls, isEmpty);

      setup.cloud.failEveryCallWith = null;
      // The first retry fires after 5 seconds on its own.
      await tester.pump(const Duration(seconds: 7));
      await _drain(tester);

      expect(_terminal(_findings(setup.container).single.aiStatus), isTrue);
      expect(setup.billing.calls, hasLength(1));
    });

    testWidgets('5 + 12. an upload that keeps failing reaches "failed" '
        '(Retry offered) after bounded retries: never an endless spinner', (
      tester,
    ) async {
      final setup = await _online();
      addTearDown(setup.container.dispose);
      setup.cloud.failEveryCallWith = Exception('Storage unavailable');
      await _save(setup.container, 'Tile holo');
      await _drain(tester);

      for (final wait in [5, 15, 45, 120]) {
        expect(
          _findings(setup.container).single.aiStatus,
          AiFindingStatus.queued,
        );
        await tester.pump(Duration(seconds: wait + 2));
        await _drain(tester);
      }

      final finding = _findings(setup.container).single;
      expect(finding.aiStatus, AiFindingStatus.failed);
      expect(setup.billing.calls, isEmpty, reason: 'nothing was charged');

      // Retry works once the upload can succeed.
      setup.cloud.failEveryCallWith = null;
      await setup.container
          .read(activeSessionProvider.notifier)
          .retryAiClassification(finding.id);
      await _drain(tester);
      expect(_terminal(_findings(setup.container).single.aiStatus), isTrue);
    });
  });

  group('QA #29: provider failures are visible and final', () {
    test('11. a definite provider failure (e.g. exhausted quota) shows as '
        'failed at once, not parked as queued for minutes', () async {
      final billing = ScriptedBillingService(
        steps: [ScriptedAnalysisStep.rejectDefinitively],
      );
      final setup = await _online(billing: billing);
      addTearDown(setup.container.dispose);

      await _save(setup.container, 'Tile holo');
      await pumpEventQueue(times: 400);

      final finding = _findings(setup.container).single;
      expect(finding.aiStatus, AiFindingStatus.failed);
      expect(finding.aiAttempt, isNull, reason: 'Retry starts a fresh job');
    });

    test('the backend codes for a failed-and-refunded job are ones the app '
        'treats as final; deadline-exceeded stays "outcome unknown"', () {
      expect(
        analyseFindingOutcomeUnknownForCode('resource-exhausted'),
        isFalse,
      );
      expect(analyseFindingOutcomeUnknownForCode('internal'), isFalse);
      expect(analyseFindingOutcomeUnknownForCode('deadline-exceeded'), isTrue);
    });
  });

  group('QA #32: physical completion never waits for AI', () {
    Future<void> expectCanComplete(
      ProviderContainer container,
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: InspectionQueueScreen()),
        ),
      );
      await tester.pump();
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Complete Physical Inspection'),
      );
      expect(button.onPressed, isNotNull);
    }

    testWidgets('13 + 15. enabled while AI is queued, with untouched '
        'suggested areas', (tester) async {
      late _Setup setup;
      await tester.runAsync(() async {
        setup = await _online();
        // Keep it queued: the upload can't finish.
        setup.cloud.failEveryCallWith = Exception('offline-ish');
        await _save(setup.container, 'Tile holo');
        await pumpEventQueue(times: 200);
      });
      addTearDown(setup.container.dispose);
      expect(
        _findings(setup.container).single.aiStatus,
        AiFindingStatus.queued,
      );
      final session = setup.container.read(activeSessionProvider)!;
      expect(PhysicalProgress.of(session).untouchedSuggested, greaterThan(0));

      await expectCanComplete(setup.container, tester);
    });

    testWidgets('14 + 16. enabled while AI is analysing; completing works, '
        'and the report still waits for AI', (tester) async {
      final billing = ScriptedBillingService()..gate = Completer<void>();
      late _Setup setup;
      await tester.runAsync(() async {
        setup = await _online(billing: billing);
        await _save(setup.container, 'Tile holo');
        await pumpEventQueue(times: 400);
      });
      addTearDown(setup.container.dispose);
      expect(billing.calls, hasLength(1));
      expect(
        aiFindingStatusIsInFlight(_findings(setup.container).single.aiStatus),
        isTrue,
      );

      await expectCanComplete(setup.container, tester);

      await tester.runAsync(() async {
        final notifier = setup.container.read(activeSessionProvider.notifier);
        expect(await notifier.markPhysicalInspectionComplete(), isTrue);
        final report = await notifier.generateReport();
        expect(report.outcome, ReportGenerationOutcome.aiReviewIncomplete);
        billing.gate!.complete();
        await pumpEventQueue(times: 400);
      });
    });
  });

  group('QA #33: no page becomes untappable', () {
    testWidgets('17. AI Review lists findings still with AI and failed ones '
        '(with Retry), and Continue to Report stays tappable while AI runs', (
      tester,
    ) async {
      final billing = ScriptedBillingService(
        steps: [ScriptedAnalysisStep.rejectDefinitively],
      );
      // Everything on the test clock: a database opened in real time
      // can't complete work started later on the fake clock.
      final setup = await _online(billing: billing);
      await _save(setup.container, 'Tile holo');
      await _drain(tester);
      setup.cloud.failEveryCallWith = Exception('slow network');
      await _save(setup.container, 'Win frem gap', area: 1);
      await _drain(tester);
      final statuses = _findings(setup.container).map((f) => f.aiStatus);
      expect(
        statuses,
        containsAll([AiFindingStatus.failed, AiFindingStatus.queued]),
      );

      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const AiReviewOverviewScreen(),
          ),
          GoRoute(
            path: ReportScreen.routePath,
            builder: (context, state) => const ReportScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: setup.container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();

      expect(find.textContaining('Waiting on AI (2)'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Classify Manually'), findsOneWidget);
      expect(
        find.textContaining('AI is still working on 1 finding'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(FilledButton, 'Continue to Report'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportScreen), findsOneWidget);

      // The report page scrolls, and Generate Report is reachable and
      // answers (the report still waits for AI).
      await tester.scrollUntilVisible(
        find.widgetWithText(FilledButton, 'Generate Report'),
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('report-scroll')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Generate Report'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Generate Report'));
      await _drain(tester);
      await tester.pumpAndSettle();
      // The banner sits at the top of the page, scrolled above the button.
      expect(
        find.textContaining('Report generation failed', skipOffstage: false),
        findsOneWidget,
      );
      final generate = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Generate Report'),
      );
      expect(generate.onPressed, isNotNull, reason: 'not stuck generating');

      // The queued finding still has a pending upload retry; disposing
      // the session cancels it, as leaving the app would.
      await tester.pumpWidget(const SizedBox());
      setup.container.dispose();
    });

    testWidgets('18. the pricing spinner closes even if the widget that '
        'opened it is rebuilt away mid-load: no invisible barrier remains', (
      tester,
    ) async {
      final billing = ScriptedBillingService()
        ..estimateGate = Completer<void>();
      final container = ProviderContainer(
        overrides: testOverrides(billingService: billing),
      );
      addTearDown(container.dispose);
      late String findingId;
      await tester.runAsync(() async {
        await container
            .read(activeSessionProvider.notifier)
            .startNew(PropertyType.highRise);
        findingId = (await _save(container, 'Tile holo')).id;
        await pumpEventQueue();
      });
      final showOpener = ValueNotifier(true);
      var taps = 0;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: showOpener,
                    builder: (context, show, _) => show
                        ? Consumer(
                            builder: (context, ref, _) => ElevatedButton(
                              onPressed: () => showAnalyseApprovalDialog(
                                context: context,
                                ref: ref,
                                findingId: findingId,
                              ),
                              child: const Text('open'),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                  ElevatedButton(
                    onPressed: () => taps++,
                    child: const Text('other action'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Background AI rebuilds the list and the opener disappears.
      showOpener.value = false;
      await tester.pump();
      billing.estimateGate!.complete();
      await tester.runAsync(() => pumpEventQueue(times: 100));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('other action'));
      expect(taps, 1, reason: 'the page accepts taps again');
    });
  });

  test('connectivity provider is available for the queue (sanity)', () {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    expect(container.read(isOnlineForAiProvider), isTrue);
  });
}
