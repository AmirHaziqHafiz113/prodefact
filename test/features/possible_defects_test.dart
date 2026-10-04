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

/// Top-4 "Possible defects" (2026-10-04): an uncertain AI result offers
/// up to 4 ranked catalogue defects; tapping one confirms it as the
/// inspector's decision without another AI call.

const _candidates = [
  'door.sliding_door_panel.07',
  'door.sliding_door_frame.07',
  'door.sliding_door_frame.01',
  'door.sliding_door_panel.08',
];

/// AI is unsure: no pick, four sliding-door options, a reason.
class _UnsureBackend extends FakeBillingService {
  _UnsureBackend() : super(initialBalanceCredits: 100000);

  int calls = 0;

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    calls++;
    final r = await super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
    return AnalyseFindingResult(
      aiLevel: r.aiLevel,
      creditsCharged: r.creditsCharged,
      newBalance: r.newBalance,
      paymentMode: r.paymentMode,
      classification: AiFindingClassification(
        findingId: request.findingId,
        needsReview: true,
        confidence: 0.45,
        candidateEntryIds: _candidates,
        needsReviewReason: 'ambiguous_candidates',
        noteImageAgreement: 'supports',
        detectedComponent: 'Sliding Door',
      ),
    );
  }
}

void main() {
  testWidgets('1-10. AI Review shows up to 4 ranked catalogue options '
      '(Element · Component + description, no ids); choosing one confirms '
      'it with no AI call and makes the finding report-ready', (tester) async {
    late ProviderContainer container;
    final backend = _UnsureBackend();
    await tester.runAsync(() async {
      container = ProviderContainer(
        overrides: testOverrides(billingService: backend),
      );
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.startNew(PropertyType.highRise);
      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      notifier.saveCameraFinding(
        sectionId: container.read(inspectionQueueProvider).first.id,
        photo: photo!,
        note: 'sliding dr senget',
      );
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    addTearDown(container.dispose);
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;

    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    expect(suggestion.suggestedCandidateEntryIds, _candidates);
    expect(suggestion.needsReviewReason, 'ambiguous_candidates');
    expect(
      ReportReadiness.of(container.read(activeSessionProvider)!).isReady,
      isFalse,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiReviewOverviewScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Possible defects'), findsOneWidget);
    expect(
      find.text('A few defects could fit — please confirm one.'),
      findsOneWidget,
    );
    for (final id in _candidates) {
      final entry = DefectCatalogue.instance.byId(id)!;
      final tile = find.byKey(ValueKey('candidate-$id'));
      expect(tile, findsOneWidget);
      expect(
        find.descendant(of: tile, matching: find.text(entry.defectDescription)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: tile,
          matching: find.text(
            '${entry.mainElementName} · ${entry.componentName}',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining(id), findsNothing, reason: 'no raw ids');
    }
    // Ranked: the first option is the AI's most likely one.
    final firstTileY = tester
        .getTopLeft(
          find.byKey(const ValueKey('candidate-door.sliding_door_panel.07')),
        )
        .dy;
    final lastTileY = tester
        .getTopLeft(
          find.byKey(const ValueKey('candidate-door.sliding_door_panel.08')),
        )
        .dy;
    expect(firstTileY, lessThan(lastTileY));

    await tester.tap(
      find.byKey(const ValueKey('candidate-door.sliding_door_frame.07')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Use this defect?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-candidate')));
    await tester.pumpAndSettle();

    final session = container.read(activeSessionProvider)!;
    final decided = session.aiSuggestions.single;
    expect(decided.status, AiSuggestionStatus.edited);
    expect(decided.finalCatalogueEntryId, 'door.sliding_door_frame.07');
    expect(backend.calls, 1, reason: 'choosing a candidate calls no AI');
    expect(ReportReadiness.of(session).isReady, isTrue);

    final reported = buildReportModel(
      session: session,
      propertyTypeLabel: 'High Rise',
      generatedAt: DateTime(2026, 10, 4),
    ).areas.expand((a) => a.findings).single;
    final entry = DefectCatalogue.instance.byId('door.sliding_door_frame.07')!;
    expect(reported.componentName, 'Sliding Door Frame');
    expect(reported.recommendation, entry.correctiveAction);
  });
}
