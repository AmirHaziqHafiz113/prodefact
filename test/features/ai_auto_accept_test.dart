import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/ai_review_overview_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';
import '../support/uncertain_ai_billing_service.dart';

/// AI Review auto-accept (2026-10-01): a valid catalogue match is
/// accepted automatically and is report-ready; the inspector can still
/// change or reject it. Uncertain or invalid results are never
/// auto-accepted.

/// AI that answers with an id that isn't in the catalogue, claiming
/// confidence — it must never be accepted.
class _InvalidIdBilling extends FakeBillingService {
  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    final result = await super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
    return AnalyseFindingResult(
      aiLevel: result.aiLevel,
      creditsCharged: result.creditsCharged,
      newBalance: result.newBalance,
      paymentMode: result.paymentMode,
      classification: AiFindingClassification(
        findingId: request.findingId,
        needsReview: false,
        catalogueEntryId: 'not.a.real.entry',
        confidence: 0.99,
      ),
    );
  }
}

Future<ProviderContainer> _analysedSession({BillingService? billing}) async {
  final container = ProviderContainer(
    overrides: testOverrides(billingService: billing),
  );
  addTearDown(container.dispose);
  final notifier = container.read(activeSessionProvider.notifier);
  await notifier.startNew(PropertyType.highRise);
  notifier.setAutoAnalyseEnabled(true);
  final photo = await notifier.captureFindingPhoto(
    source: EvidenceSource.camera,
  );
  notifier.saveCameraFinding(
    sectionId: container.read(inspectionQueueProvider).first.id,
    photo: photo!,
    note: 'Hollow tile',
  );
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return container;
}

void main() {
  test('17. a valid catalogue result is accepted automatically, with the '
      'suggestion as its final value and no inspector review stamp', () async {
    final container = await _analysedSession();
    final session = container.read(activeSessionProvider)!;
    final suggestion = session.aiSuggestions.single;

    expect(suggestion.status, AiSuggestionStatus.accepted);
    expect(suggestion.isAutoAccepted, isTrue);
    expect(suggestion.reviewedAt, isNull);
    expect(suggestion.finalCatalogueEntryId, isNotNull);
    expect(
      suggestion.finalCatalogueEntryId,
      suggestion.suggestedCatalogueEntryId,
    );
    expect(session.findings.single.aiStatus, AiFindingStatus.completed);

    // Durable, not just in memory.
    final reloaded = await container
        .read(inspectionRepositoryProvider)
        .loadSession(session.id);
    expect(reloaded!.aiSuggestions.single.isAutoAccepted, isTrue);
  });

  test('18. a needsReview result is NOT auto-accepted', () async {
    final container = await _analysedSession(
      billing: UncertainAiBillingService(),
    );
    final session = container.read(activeSessionProvider)!;
    expect(session.aiSuggestions.single.status, AiSuggestionStatus.pending);
    expect(session.findings.single.aiStatus, AiFindingStatus.needsReview);
    expect(AiReviewProgress.of(session).pending, 1);
  });

  test('19. an invalid catalogue id is NOT auto-accepted, even when the AI '
      'claims confidence', () async {
    final container = await _analysedSession(billing: _InvalidIdBilling());
    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    expect(suggestion.status, AiSuggestionStatus.pending);
    expect(suggestion.suggestedCatalogueEntryId, isNull);
    expect(suggestion.finalCatalogueEntryId, isNull);
  });

  test('20. an auto-accepted result can still be changed or rejected by '
      'the inspector', () async {
    final container = await _analysedSession();
    final notifier = container.read(activeSessionProvider.notifier);
    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    final other = DefectCatalogue.instance.entries.firstWhere(
      (e) => e.id != suggestion.suggestedCatalogueEntryId,
    );

    notifier.changeSuggestion(suggestion.id, other.id);
    var updated = container.read(activeSessionProvider)!.aiSuggestions.single;
    expect(updated.status, AiSuggestionStatus.edited);
    expect(updated.finalCatalogueEntryId, other.id);
    expect(updated.isAutoAccepted, isFalse);
    // The AI's original suggestion is preserved.
    expect(
      updated.suggestedCatalogueEntryId,
      suggestion.suggestedCatalogueEntryId,
    );

    notifier.rejectSuggestion(suggestion.id);
    updated = container.read(activeSessionProvider)!.aiSuggestions.single;
    expect(updated.status, AiSuggestionStatus.rejected);
  });

  test(
    '21. auto-accepted results count as report-ready: review has '
    'nothing pending and completing the inspection completes AI review',
    () async {
      final container = await _analysedSession();
      final notifier = container.read(activeSessionProvider.notifier);
      var session = container.read(activeSessionProvider)!;
      final review = AiReviewProgress.of(session);
      expect(review.pending, 0);
      expect(review.autoAccepted, 1);
      expect(review.resolved, 1);

      expect(await notifier.markPhysicalInspectionComplete(), isTrue);
      session = container.read(activeSessionProvider)!;
      expect(session.status, InspectionStatus.aiReviewComplete);
      expect(session.aiReviewState, AiReviewState.completed);
    },
  );

  test('22. existing suggestions stay readable: an older pending one is '
      'still pending, and an inspector-accepted one is not "automatic"', () {
    final legacyPending = AiSuggestion(
      id: 's1',
      sessionId: 'x',
      findingId: 'f1',
      providerId: 'ai',
      generatedAt: DateTime(2026, 9, 1),
      suggestedCatalogueEntryId: DefectCatalogue.instance.entries.first.id,
      finalCatalogueEntryId: DefectCatalogue.instance.entries.first.id,
    );
    expect(legacyPending.status, AiSuggestionStatus.pending);
    expect(legacyPending.isAutoAccepted, isFalse);
    final inspectorAccepted = legacyPending.copyWith(
      status: AiSuggestionStatus.accepted,
      reviewedAt: DateTime(2026, 9, 2),
    );
    expect(inspectorAccepted.isAutoAccepted, isFalse);
    expect(
      AiReviewProgress.forSuggestions([legacyPending, inspectorAccepted])
          .autoAccepted,
      0,
    );
  });

  testWidgets('the AI Review card says "Accepted automatically" and still '
      'offers Change and Reject', (tester) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      container = await _analysedSession();
    });
    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: AiReviewOverviewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accepted automatically'), findsOneWidget);
    expect(find.text('Auto-accepted'), findsOneWidget);
    expect(find.byKey(ValueKey('change-${suggestion.id}')), findsOneWidget);
    expect(find.byKey(ValueKey('reject-${suggestion.id}')), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });
}
