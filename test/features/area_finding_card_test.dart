import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/ai_review_overview_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// The Area page is the main place a finding is settled: colour state,
/// auto-accept, Recommended top-4, searchable catalogue, Reject, Reanalyse
/// and Delete all work on the card — and AI Review mirrors the same
/// state.

class _Backend extends FakeBillingService {
  _Backend() : super(initialBalanceCredits: 100000);

  bool fail = false;
  bool unsure = false;
  int calls = 0;

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    calls++;
    if (fail) throw Exception('provider failed');
    if (unsure) {
      return AnalyseFindingResult(
        aiLevel: aiLevel,
        creditsCharged: 1,
        newBalance: 1,
        paymentMode: CommercialMode.flexCredits,
        classification: AiFindingClassification(
          findingId: request.findingId,
          needsReview: true,
          needsReviewReason: 'low_confidence',
          candidateEntryIds: const [
            'wall.wall_tile.04',
            'wall.wall_tile.01',
            'wall.wall_tile.02',
            'wall.wall_tile.03',
            'wall.wall_tile.05',
          ],
        ),
      );
    }
    return super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
  }
}

class _Ctx {
  _Ctx(this.container, this.backend, this.findingId, this.sectionId);

  final ProviderContainer container;
  final _Backend backend;
  final String findingId;
  final String sectionId;

  InspectionSession get session => container.read(activeSessionProvider)!;
  Finding get finding => session.findings.firstWhere((f) => f.id == findingId);
  AiSuggestion? get suggestion =>
      session.aiSuggestions.where((s) => s.findingId == findingId).firstOrNull;
}

Future<_Ctx> _pump(
  WidgetTester tester, {
  required _Backend backend,
  String note = 'hollow wall tile',
  bool firstArea = false,
}) async {
  late ProviderContainer container;
  late Finding saved;
  late String sectionId;
  await tester.runAsync(() async {
    container = ProviderContainer(
      overrides: testOverrides(billingService: backend),
    );
    final notifier = container.read(activeSessionProvider.notifier);
    await notifier.startNew(PropertyType.highRise);
    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    final queue = container.read(inspectionQueueProvider);
    sectionId = firstArea
        ? queue.first.id
        : queue.firstWhere((s) => s.name == 'Master Bedroom').id;
    saved = notifier.saveCameraFinding(
      sectionId: sectionId,
      photo: photo!,
      note: note,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });
  addTearDown(container.dispose);
  addTearDown(tester.view.reset);
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: AreaInspectionScreen(sectionId: sectionId)),
    ),
  );
  await tester.pump();
  return _Ctx(container, backend, saved.id, sectionId);
}

Finder _tone(_Ctx c, FindingTone tone) =>
    find.byKey(ValueKey('finding-tone-${c.findingId}-${tone.name}'));

void main() {
  testWidgets('a confident AI result is auto-accepted: GREEN, no "is this '
      'correct?" step, with Change / Reanalyse / Reject / Delete on the '
      'card', (tester) async {
    final c = await _pump(
      tester,
      backend: _Backend(),
      note: 'Cracked tile',
      firstArea: true,
    );
    expect(c.finding.aiStatus, AiFindingStatus.completed);
    expect(c.suggestion!.isAutoAccepted, isTrue);

    expect(_tone(c, FindingTone.green), findsOneWidget);
    expect(find.text('Accepted by AI'), findsOneWidget);
    expect(
      find.byKey(ValueKey('finding-result-${c.findingId}')),
      findsOneWidget,
    );
    expect(find.textContaining('correct?'), findsNothing);
    expect(find.text('Other possible defects'), findsOneWidget);
    expect(
      find.byKey(ValueKey('reanalyse-finding-${c.findingId}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('reject-finding-${c.findingId}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('delete-finding-${c.findingId}')),
      findsOneWidget,
    );
  });

  testWidgets('an uncertain result is ORANGE and offers exactly 4 '
      'Recommended defects; tapping one resolves it GREEN with zero extra '
      'AI calls, and AI Review mirrors it', (tester) async {
    final c = await _pump(tester, backend: _Backend()..unsure = true);
    expect(c.finding.aiStatus, AiFindingStatus.needsReview);
    expect(_tone(c, FindingTone.orange), findsOneWidget);

    final recommended = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith(
            'recommended-${c.findingId}-',
          ),
    );
    expect(recommended, findsNWidgets(4));
    final callsBefore = c.backend.calls;

    await tester.tap(
      find.byKey(ValueKey('recommended-${c.findingId}-wall.wall_tile.04')),
    );
    await tester.pump();
    await tester.pump();

    expect(c.backend.calls, callsBefore, reason: 'a manual pick calls no AI');
    expect(c.suggestion!.finalCatalogueEntryId, 'wall.wall_tile.04');
    expect(_tone(c, FindingTone.green), findsOneWidget);
    expect(_tone(c, FindingTone.orange), findsNothing);
    expect(find.text('Confirmed'), findsOneWidget);

    // AI Review shows the very same decision.
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c.container,
        child: const MaterialApp(home: AiReviewOverviewScreen()),
      ),
    );
    await tester.pump();
    // Settled, so it's in the collapsed "Resolved" group — not the
    // needs-a-decision list.
    expect(find.textContaining('Needs your decision'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('review-show-resolved')));
    await tester.pump();
    final entry = DefectCatalogue.instance.byId('wall.wall_tile.04')!;
    expect(find.textContaining(entry.defectDescription), findsWidgets);
  });

  testWidgets('a failed finding is RED with a Retry, can be settled by '
      'hand from the Area card, and is never stranded', (tester) async {
    final c = await _pump(tester, backend: _Backend()..fail = true);
    expect(c.finding.aiStatus, AiFindingStatus.failed);
    expect(_tone(c, FindingTone.red), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.byKey(ValueKey('failure-reason-${c.findingId}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('recommended-${c.findingId}')),
      findsOneWidget,
      reason: 'ranked from the note even with no AI result',
    );

    final callsBefore = c.backend.calls;
    await tester.tap(
      find.byKey(ValueKey('recommended-${c.findingId}-wall.wall_tile.04')),
    );
    await tester.pump();
    await tester.pump();
    expect(_tone(c, FindingTone.green), findsOneWidget);
    expect(c.suggestion!.providerId, 'manual');
    expect(c.backend.calls, callsBefore);
  });

  testWidgets('Reject makes it RED/unresolved but it stays fully editable '
      '(search, pick, reanalyse, delete)', (tester) async {
    final c = await _pump(tester, backend: _Backend());
    await tester.tap(find.byKey(ValueKey('reject-finding-${c.findingId}')));
    await tester.pump();
    await tester.pump();

    expect(c.suggestion!.isRejected, isTrue);
    expect(_tone(c, FindingTone.red), findsOneWidget);
    expect(find.text('Unresolved'), findsOneWidget);
    expect(ReportReadiness.of(c.session).isReady, isFalse);
    expect(find.text('Other possible defects'), findsOneWidget);
    expect(
      find.byKey(ValueKey('reanalyse-finding-${c.findingId}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('delete-finding-${c.findingId}')),
      findsOneWidget,
    );

    c.container
        .read(activeSessionProvider.notifier)
        .selectDefectForFinding(c.findingId, 'wall.wall_tile.01');
    await tester.pump();
    expect(_tone(c, FindingTone.green), findsOneWidget);
    expect(ReportReadiness.of(c.session).isReady, isTrue);
  });

  testWidgets('Reanalyse As-Is makes one fresh request, keeps the old '
      'result in history', (tester) async {
    final c = await _pump(tester, backend: _Backend());
    final firstKey = c.suggestion!.aiJobKey;
    expect(c.backend.calls, 1);

    await tester.tap(find.byKey(ValueKey('reanalyse-finding-${c.findingId}')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('reanalyse-as-is')));
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    await tester.pump();

    expect(c.backend.calls, 2);
    final after = c.suggestion!;
    expect(after.reanalysisCount, 1);
    expect(after.aiJobKey, isNot(firstKey));
    expect(after.history, hasLength(1));
  });

  testWidgets('Delete asks first, then removes the finding, its result and '
      'its card', (tester) async {
    final c = await _pump(tester, backend: _Backend());

    await tester.tap(find.byKey(ValueKey('delete-finding-${c.findingId}')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this defect finding?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(c.session.findings, hasLength(1), reason: 'cancel keeps it');

    await tester.tap(find.byKey(ValueKey('delete-finding-${c.findingId}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-delete-finding')));
    await tester.pumpAndSettle();

    expect(c.session.findings, isEmpty);
    expect(c.session.aiSuggestions, isEmpty);
    expect(find.byKey(ValueKey('finding-panel-${c.findingId}')), findsNothing);
  });

  testWidgets('"Add New" saves a company defect and resolves the finding '
      'with it immediately; the master catalogue is untouched', (tester) async {
    final masterCount = DefectCatalogue.instance.masterEntries.length;
    final c = await _pump(tester, backend: _Backend()..fail = true);

    await tester.tap(find.text('Other possible defects'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('add-custom-defect-${c.findingId}')));
    await tester.pumpAndSettle();

    // Blank fields are refused, nothing saved.
    await tester.tap(find.byKey(const ValueKey('custom-defect-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('custom-defect-error')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('custom-defect-element')),
      'Floor',
    );
    await tester.enterText(
      find.byKey(const ValueKey('custom-defect-component')),
      'Floor Trap',
    );
    await tester.enterText(
      find.byKey(const ValueKey('custom-defect-description')),
      'Floor trap cover is loose',
    );
    await tester.enterText(
      find.byKey(const ValueKey('custom-defect-action')),
      'Re-fix the cover securely.',
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('custom-defect-save')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    final chosen = c.suggestion!.finalCatalogueEntryId!;
    expect(chosen, startsWith('custom.'));
    expect(DefectCatalogue.instance.byId(chosen)!.isCustom, isTrue);
    expect(
      DefectCatalogue.instance.byId(chosen)!.correctiveAction,
      'Re-fix the cover securely.',
    );
    expect(_tone(c, FindingTone.green), findsOneWidget);
    expect(DefectCatalogue.instance.masterEntries.length, masterCount);
    DefectCatalogue.instance.replaceCustomEntries(const []);
  });
}
