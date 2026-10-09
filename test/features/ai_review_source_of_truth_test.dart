import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/ai_review_overview_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// AI Review shows the session's CURRENT findings only — never a stale
/// "Queued for AI", a failed job shown as queued, or a deleted finding.

class _Backend extends FakeBillingService {
  _Backend() : super(initialBalanceCredits: 100000);

  final Set<String> fail = {};

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    if (fail.contains(request.findingId)) throw Exception('provider failed');
    return super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
  }
}

Future<(ProviderContainer, List<String>)> _setup(
  WidgetTester tester, {
  required void Function(_Backend backend, List<String> ids) arrange,
}) async {
  late ProviderContainer container;
  final ids = <String>[];
  final backend = _Backend();
  await tester.runAsync(() async {
    container = ProviderContainer(
      overrides: testOverrides(billingService: backend),
    );
    final notifier = container.read(activeSessionProvider.notifier);
    await notifier.startNew(PropertyType.highRise);
    final section = container.read(inspectionQueueProvider).first.id;
    final photos = [
      for (var i = 0; i < 3; i++)
        (await notifier.captureFindingPhoto(source: EvidenceSource.camera))!,
    ];
    ids.addAll(photos.map((p) => p.pendingFindingId));
    arrange(backend, ids);
    for (final (i, photo) in photos.indexed) {
      notifier.saveCameraFinding(
        sectionId: section,
        photo: photo,
        note: 'Note $i',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  });
  addTearDown(container.dispose);
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: AiReviewOverviewScreen()),
    ),
  );
  await tester.pump();
  return (container, ids);
}

void main() {
  testWidgets('38 + 39. finished findings are not "Waiting on AI"; a '
      'failed one shows as failed (with Retry), never "Queued for AI"', (
    tester,
  ) async {
    final (container, ids) = await _setup(
      tester,
      arrange: (backend, ids) => backend.fail.add(ids[1]),
    );

    // Exceptions only: the failed finding is the one needing a decision.
    expect(find.textContaining('Needs your decision (1)'), findsOneWidget);
    expect(find.byKey(ValueKey('pending-finding-${ids[0]}')), findsNothing);
    expect(find.byKey(ValueKey('pending-finding-${ids[2]}')), findsNothing);
    expect(find.byKey(ValueKey('pending-finding-${ids[1]}')), findsOneWidget);
    expect(find.text('AI analysis failed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Queued for AI'), findsNothing);
    expect(container.read(activeSessionProvider)!.aiSuggestions, hasLength(2));
  });

  testWidgets('40 + 41. deleting a finding removes its card from AI Review '
      'and from the totals at once', (tester) async {
    final (container, ids) = await _setup(tester, arrange: (_, _) {});
    expect(container.read(activeSessionProvider)!.aiSuggestions, hasLength(3));

    container.read(activeSessionProvider.notifier).removeFinding(ids[0]);
    await tester.pump();

    final session = container.read(activeSessionProvider)!;
    expect(session.aiSuggestions.map((s) => s.findingId), [ids[1], ids[2]]);
    expect(find.text('Note 0'), findsNothing);
    expect(find.textContaining('2 of 2'), findsWidgets);
  });

  test('the report prints ONE concrete defect for a multi-defect entry', () {
    final entry = DefectCatalogue.instance.byId('wall.wall_tile.04')!;
    final now = DateTime(2026, 10, 2);
    final session = InspectionSession(
      id: 's',
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      sections: const [Section(id: 'a', name: 'Kitchen', elements: [])],
      sectionStatuses: const {'a': SectionStatus.completed},
      findings: [
        Finding(
          id: 'f',
          sectionId: 'a',
          description: 'jubin holo',
          createdAt: now,
          updatedAt: now,
          aiStatus: AiFindingStatus.completed,
          evidence: [
            Evidence(id: 'e', findingId: 'f', filePath: '/x', createdAt: now),
          ],
        ),
      ],
      aiSuggestions: [
        AiSuggestion(
          id: 'sg',
          sessionId: 's',
          findingId: 'f',
          providerId: 'ai',
          generatedAt: now,
          suggestedCatalogueEntryId: entry.id,
          suggestedDefectTerm: 'hollow',
          finalCatalogueEntryId: entry.id,
          status: AiSuggestionStatus.accepted,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    final finding = buildReportModel(
      session: session,
      propertyTypeLabel: 'High Rise',
      generatedAt: now,
    ).areas.single.findings.single;
    expect(finding.defectType, 'Wall Tile - hollow');
    expect(finding.defectType, isNot(contains('/')));
  });
}
