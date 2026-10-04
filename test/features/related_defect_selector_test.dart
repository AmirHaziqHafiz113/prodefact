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

/// The searchable "Other possible defects" selector (2026-10-06): a
/// manual, full-catalogue alternative under the AI suggestion, ranked
/// by relatedness and never another AI call. Its `ListTile`s are keyed
/// `related-defect-<keyId>-<entryId>` (the instance's keyId first, so
/// several of these can live on one screen) — tests below address keys
/// using that exact shape, never a bare entry id.

enum _Mode { confident, fail }

class _Backend extends FakeBillingService {
  _Backend() : super(initialBalanceCredits: 100000);

  _Mode mode = _Mode.confident;
  int calls = 0;

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    calls++;
    if (mode == _Mode.fail) throw Exception('provider failed');
    return super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
  }
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 80));

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _Backend backend,
  required String note,
}) async {
  late ProviderContainer container;
  await tester.runAsync(() async {
    container = ProviderContainer(
      overrides: testOverrides(billingService: backend),
    );
    final notifier = container.read(activeSessionProvider.notifier);
    await notifier.startNew(PropertyType.highRise);
    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    // A non-plumbing area the fake AI's own (area-keyword) guesser
    // doesn't recognise — so its suggestion (if any) never has its own
    // opinion about "wall"/"sliding door", and the selector's ranking
    // is driven purely by the note, as these tests check.
    final section = container
        .read(inspectionQueueProvider)
        .firstWhere((s) => s.name == 'Master Bedroom');
    notifier.saveCameraFinding(
      sectionId: section.id,
      photo: photo!,
      note: note,
    );
    await _settle();
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
  return container;
}

void main() {
  testWidgets(
    '9. related results appear first (no search), the search bar reaches '
    'the full catalogue, Malay/alias search works, choosing a result '
    'updates the finding with the right corrective action, costs no AI '
    'call, and the report uses it',
    (tester) async {
      final backend = _Backend();
      final container = await _pump(
        tester,
        backend: backend,
        note: 'holo wall tile',
      );
      final suggestionId = container
          .read(activeSessionProvider)!
          .aiSuggestions
          .single
          .id;
      expect(backend.calls, 1);

      await tester.tap(find.text('Other possible defects'));
      await tester.pumpAndSettle();

      // Related-first: a Wall Tile entry (not generic/unrelated) is the
      // very first result before any search is typed.
      final listKey = ValueKey('related-defect-results-$suggestionId');
      ListTile firstResultTile() =>
          find
                  .descendant(
                    of: find.byKey(listKey),
                    matching: find.byType(ListTile),
                  )
                  .evaluate()
                  .first
                  .widget
              as ListTile;
      expect(
        (firstResultTile().subtitle! as Text).data,
        startsWith('Wall · Wall Tile'),
      );

      // The search bar reaches the full 222-entry catalogue, not just
      // this finding's own shortlist: "rusty" is nowhere near a wall
      // tile, yet still surfaces real results.
      final searchField = find.byKey(
        ValueKey('related-defect-search-$suggestionId'),
      );
      await tester.enterText(searchField, 'rusty');
      await tester.pumpAndSettle();
      expect(
        (firstResultTile().title! as Text).data!.toLowerCase(),
        contains('rusty'),
      );

      // Malay/alias search ("retak" = crack) finds the same family as
      // the English word would.
      await tester.enterText(searchField, 'retak');
      await tester.pumpAndSettle();
      expect(
        (firstResultTile().title! as Text).data!.toLowerCase(),
        contains('crack'),
      );

      // Search for the sliding-door frame alignment defect and select it.
      await tester.enterText(searchField, 'sliding door frame not aligned');
      await tester.pumpAndSettle();
      const chosenId = 'door.sliding_door_frame.07';
      final chosenEntry = DefectCatalogue.instance.byId(chosenId)!;
      await tester.tap(
        find.byKey(ValueKey('related-defect-$suggestionId-$chosenId')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Use this defect?'), findsOneWidget);
      expect(
        find.text('Element: ${chosenEntry.mainElementName}'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('confirm-related-defect')));
      await tester.pumpAndSettle();

      // No extra provider call for a manual pick.
      expect(backend.calls, 1);

      final session = container.read(activeSessionProvider)!;
      final suggestion = session.aiSuggestions.single;
      expect(suggestion.status, AiSuggestionStatus.edited);
      expect(suggestion.finalCatalogueEntryId, chosenId);

      final reportEntry = buildReportModel(
        session: session,
        propertyTypeLabel: 'High Rise',
        generatedAt: DateTime(2026, 10, 6),
      ).areas.expand((a) => a.findings).single;
      expect(reportEntry.componentName, chosenEntry.componentName);
      expect(reportEntry.recommendation, chosenEntry.correctiveAction);
      expect(ReportReadiness.of(session).isReady, isTrue);
    },
  );

  testWidgets(
    'the selector works for a Failed finding too (no suggestion yet): '
    'choosing a result classifies it manually, with no provider call',
    (tester) async {
      final backend = _Backend()..mode = _Mode.fail;
      final container = await _pump(
        tester,
        backend: backend,
        note: 'holo wall tile',
      );
      expect(
        container.read(activeSessionProvider)!.findings.single.aiStatus,
        AiFindingStatus.failed,
      );
      expect(backend.calls, 1);

      final findingId = container
          .read(activeSessionProvider)!
          .findings
          .single
          .id;
      await tester.tap(find.text('Other possible defects'));
      await tester.pumpAndSettle();

      final searchField = find.byKey(
        ValueKey('related-defect-search-$findingId'),
      );
      await tester.enterText(searchField, 'hollow wall tile');
      await tester.pumpAndSettle();

      const chosenId = 'wall.wall_tile.04';
      await tester.tap(
        find.byKey(ValueKey('related-defect-$findingId-$chosenId')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-related-defect')));
      await tester.pumpAndSettle();

      expect(backend.calls, 1, reason: 'manual classification calls no AI');
      final suggestion = container
          .read(activeSessionProvider)!
          .aiSuggestions
          .single;
      expect(suggestion.findingId, findingId);
      expect(suggestion.finalCatalogueEntryId, chosenId);
      expect(suggestion.providerId, 'manual');
      expect(
        container.read(activeSessionProvider)!.findings.single.aiStatus,
        AiFindingStatus.completed,
      );
    },
  );
}
