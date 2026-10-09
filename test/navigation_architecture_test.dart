import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/router/app_shell_screen.dart';
import 'package:prodefact/app/theme/design_system.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/ai_review_overview_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/areas_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/finding_detail_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/home_dashboard_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/inspection_overview_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/report_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/widgets/finding_status_presentation.dart';
import 'package:prodefact/features/home_inspection/presentation/widgets/session_navigation.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import 'support/test_repository.dart';

/// Screen ownership and "one door, one destination" — see
/// docs/ux_architecture.md. Every CTA here must land on its own,
/// distinct screen, and back must return to where the inspector was.
class _FailingBackend extends FakeBillingService {
  _FailingBackend() : super(initialBalanceCredits: 100000);

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async => throw Exception('provider failed');
}

/// A started High Rise inspection, optionally with one finding saved in
/// queue area [findingArea] (AI fails when [failAi]).
Future<ProviderContainer> _started(
  WidgetTester tester, {
  int? findingArea,
  bool failAi = false,
}) async {
  late ProviderContainer container;
  await tester.runAsync(() async {
    container = ProviderContainer(
      overrides: testOverrides(
        billingService: failAi ? _FailingBackend() : null,
      ),
    );
    final notifier = container.read(activeSessionProvider.notifier);
    await notifier.startNew(PropertyType.highRise);
    if (findingArea != null) {
      final section = container.read(inspectionQueueProvider)[findingArea];
      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      notifier.saveCameraFinding(
        sectionId: section.id,
        photo: photo!,
        note: 'Hollow tile',
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
  });
  addTearDown(container.dispose);
  return container;
}

Future<void> _pumpApp(WidgetTester tester, ProviderContainer container) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const ProDefactApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _top(Finder matching) =>
    find.descendant(of: find.byType(Scaffold).last, matching: matching);

void main() {
  // A path clash silently opens the wrong screen or breaks the
  // navigator (two setup routes once collided with new ones).
  testWidgets('no two routes share a path', (tester) async {
    final container = ProviderContainer(overrides: testOverrides());
    await _pumpApp(tester, container);
    addTearDown(container.dispose);
    final router = GoRouter.of(tester.element(find.byType(AppBottomNav)));
    final paths = <String>[];
    void collect(List<RouteBase> routes) {
      for (final route in routes) {
        if (route is GoRoute) paths.add(route.path);
        collect(route.routes);
      }
    }

    collect(router.configuration.routes);
    expect(paths.toSet().length, paths.length, reason: '$paths');
  });

  testWidgets('Home → Continue Inspection opens that inspection\'s '
      'Overview; back returns to Home', (tester) async {
    final container = await _started(tester);
    await _pumpApp(tester, container);

    await tester.tap(find.byKey(const ValueKey('home-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(InspectionOverviewScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeDashboardScreen), findsOneWidget);
  });

  testWidgets('Inspections card → Overview (never straight to an area)', (
    tester,
  ) async {
    final container = await _started(tester);
    await _pumpApp(tester, container);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Inspections'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppInspectionCard));
    await tester.pumpAndSettle();
    expect(find.byType(InspectionOverviewScreen), findsOneWidget);
    expect(find.byType(AreaInspectionScreen), findsNothing);
  });

  testWidgets('Overview → Continue Inspection opens the area the inspector '
      'was last working in', (tester) async {
    // The finding is in the THIRD queue area, not the first.
    final container = await _started(tester, findingArea: 2);
    final expected = container.read(inspectionQueueProvider)[2];
    await _pumpApp(tester, container);
    await tester.tap(find.byKey(const ValueKey('home-continue')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('overview-primary')));
    await tester.pumpAndSettle();

    final area = tester.widget<AreaInspectionScreen>(
      find.byType(AreaInspectionScreen),
    );
    expect(area.sectionId, expected.id);
    expect(area.autoCapture, isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(InspectionOverviewScreen), findsOneWidget);
  });

  testWidgets('Overview → Areas → an area card opens THAT area\'s findings', (
    tester,
  ) async {
    final container = await _started(tester);
    final target = container.read(inspectionQueueProvider)[3];
    await _pumpApp(tester, container);
    await tester.tap(find.byKey(const ValueKey('home-continue')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('overview-areas')));
    await tester.pumpAndSettle();
    expect(find.byType(AreasScreen), findsOneWidget);

    await tester.tap(_top(find.text(target.name)));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AreaInspectionScreen>(find.byType(AreaInspectionScreen))
          .sectionId,
      target.id,
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AreasScreen), findsOneWidget);
  });

  testWidgets('a finding card\'s Details opens Finding Detail for that '
      'finding', (tester) async {
    final container = await _started(tester, findingArea: 0);
    final finding = container.read(activeSessionProvider)!.findings.single;
    await _pumpApp(tester, container);
    await tester.tap(find.byKey(const ValueKey('home-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('overview-primary')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('finding-details-${finding.id}')));
    await tester.pumpAndSettle();

    final detail = tester.widget<FindingDetailScreen>(
      find.byType(FindingDetailScreen),
    );
    expect(detail.findingId, finding.id);
    expect(_top(find.text('Inspector note')), findsOneWidget);
    expect(_top(find.text('Hollow tile')), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AreaInspectionScreen), findsOneWidget);
  });

  testWidgets('Home "Needs attention" opens that inspection\'s AI Review '
      '(not its Overview), and the Review tab does the same', (tester) async {
    final container = await _started(tester, findingArea: 0, failAi: true);
    final sessionId = container.read(activeSessionProvider)!.id;
    await _pumpApp(tester, container);

    await tester.tap(find.byKey(ValueKey('home-attention-$sessionId')));
    await tester.pumpAndSettle();
    expect(find.byType(AiReviewOverviewScreen), findsOneWidget);
    expect(find.byType(InspectionOverviewScreen), findsNothing);
    expect(find.textContaining('Needs your decision (1)'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Review'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('review-inbox-$sessionId')));
    await tester.pumpAndSettle();
    expect(find.byType(AiReviewOverviewScreen), findsOneWidget);
  });

  testWidgets('a completed inspection\'s Overview makes the report its one '
      'primary action, with no duplicate Report row', (tester) async {
    final container = await _started(tester);
    await tester.runAsync(() async {
      final id = container.read(activeSessionProvider)!.id;
      await container
          .read(inspectionRepositoryProvider)
          .setSessionStatus(id, InspectionStatus.reported);
      await container.read(activeSessionProvider.notifier).resume(id);
    });
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const InspectionOverviewScreen(),
              ),
              GoRoute(
                path: ReportScreen.routePath,
                builder: (context, state) => const ReportScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(FilledButton, 'Generate Report'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('overview-report')), findsNothing);
    expect(find.byKey(const ValueKey('overview-complete')), findsNothing);
    expect(find.byKey(const ValueKey('overview-areas')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('overview-primary')));
    await tester.pumpAndSettle();
    expect(find.byType(ReportScreen), findsOneWidget);
  });

  testWidgets('an in-progress Overview: Continue Inspection is primary and '
      'Report is a quieter row', (tester) async {
    final container = await _started(tester);
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: InspectionOverviewScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(FilledButton, 'Continue Inspection'),
      findsOneWidget,
    );
    expect(find.byType(FilledButton), findsOneWidget, reason: 'one primary');
    expect(find.byKey(const ValueKey('overview-report')), findsOneWidget);
  });

  group('rules behind the doors', () {
    test('continueAreaFor prefers the newest finding\'s open area, then the '
        'first open area in queue order, and is null when all are done', () {
      final a = Section(id: 'a', name: 'A', elements: const []);
      final b = Section(id: 'b', name: 'B', elements: const []);
      final c = Section(id: 'c', name: 'C', elements: const []);
      final queue = [a, b, c];
      Finding finding(String id, String section, int minute) => Finding(
        id: id,
        sectionId: section,
        createdAt: DateTime(2026, 10, 9, 10, minute),
        updatedAt: DateTime(2026, 10, 9, 10, minute),
      );
      InspectionSession session({
        List<Finding> findings = const [],
        Map<String, SectionStatus> statuses = const {},
      }) => InspectionSession(
        id: 's',
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        status: InspectionStatus.inProgress,
        sections: queue,
        findings: findings,
        sectionStatuses: statuses,
        createdAt: DateTime(2026, 10, 9),
        updatedAt: DateTime(2026, 10, 9),
      );

      expect(continueAreaFor(session(), queue), a);
      expect(
        continueAreaFor(
          session(findings: [finding('1', 'a', 1), finding('2', 'c', 2)]),
          queue,
        ),
        c,
      );
      expect(
        continueAreaFor(
          session(
            findings: [finding('2', 'c', 2)],
            statuses: {'c': SectionStatus.completed},
          ),
          queue,
        ),
        a,
      );
      expect(
        continueAreaFor(
          session(
            statuses: {
              'a': SectionStatus.completed,
              'b': SectionStatus.completed,
              'c': SectionStatus.completed,
            },
          ),
          queue,
        ),
        isNull,
      );
    });

    test('AI Review inbox keeps exceptions only', () {
      final photo = Evidence(
        id: 'e',
        findingId: 'f',
        filePath: '/x.jpg',
        source: EvidenceSource.camera,
        createdAt: DateTime(2026),
      );
      Finding f(AiFindingStatus status, {String? note = 'n'}) => Finding(
        id: 'f',
        sectionId: 'a',
        description: note,
        evidence: [photo],
        aiStatus: status,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      expect(findingNeedsAttention(f(AiFindingStatus.failed), null), isTrue);
      expect(
        findingNeedsAttention(f(AiFindingStatus.analyzing), null),
        isFalse,
      );
      expect(findingNeedsAttention(f(AiFindingStatus.queued), null), isFalse);
      expect(
        findingNeedsAttention(
          f(AiFindingStatus.awaitingApproval, note: null),
          null,
        ),
        isTrue,
        reason: 'AI is waiting on the inspector\'s note',
      );
    });
  });
}
