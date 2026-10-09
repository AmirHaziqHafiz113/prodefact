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

/// Reanalyse (2026-10-04): any finding — passed, needs review, failed,
/// manually corrected — can be analysed again on explicit request, as a
/// NEW request (fresh key), keeping the previous result in history.

enum _Mode { confident, uncertain, fail }

/// A backend whose next answers can be scripted, recording every
/// request (and its key) it actually processes.
class _Backend extends FakeBillingService {
  _Backend() : super(initialBalanceCredits: 100000);

  _Mode mode = _Mode.confident;
  final List<AiFindingClassificationRequest> requests = [];
  final List<String> keys = [];

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    if (mode == _Mode.fail) throw Exception('provider failed');
    requests.add(request);
    keys.add(idempotencyKey);
    final r = await super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
    if (mode == _Mode.confident) return r;
    final c = r.classification;
    return AnalyseFindingResult(
      aiLevel: r.aiLevel,
      creditsCharged: r.creditsCharged,
      newBalance: r.newBalance,
      paymentMode: r.paymentMode,
      classification: AiFindingClassification(
        findingId: c.findingId,
        needsReview: true,
        catalogueEntryId: c.catalogueEntryId,
        defectTerm: c.defectTerm,
        confidence: 0.4,
        needsReviewReason: 'low_confidence',
      ),
    );
  }
}

Future<(ProviderContainer, _Backend, String)> _analysed(_Mode mode) async {
  final backend = _Backend()..mode = mode;
  final container = ProviderContainer(
    overrides: testOverrides(billingService: backend),
  );
  addTearDown(container.dispose);
  final notifier = container.read(activeSessionProvider.notifier);
  await notifier.startNew(PropertyType.highRise);
  final photo = await notifier.captureFindingPhoto(
    source: EvidenceSource.camera,
  );
  final finding = notifier.saveCameraFinding(
    sectionId: container.read(inspectionQueueProvider).first.id,
    photo: photo!,
    note: 'Cracked tile',
  );
  await _settle();
  return (container, backend, finding.id);
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 80));

InspectionSession _s(ProviderContainer c) => c.read(activeSessionProvider)!;

AiSuggestion _suggestion(ProviderContainer c) => _s(c).aiSuggestions.single;

void main() {
  test('1 + 5 + 7 + 8 + 9. a passed finding reanalysed makes ONE fresh '
      'request under a new key; the new result is current and the old one '
      'is kept in history', () async {
    final (container, backend, id) = await _analysed(_Mode.confident);
    expect(_s(container).findings.single.aiStatus, AiFindingStatus.completed);
    expect(backend.keys, hasLength(1));
    final before = _suggestion(container);

    backend.mode = _Mode.uncertain;
    final started = await container
        .read(activeSessionProvider.notifier)
        .reanalyseFinding(id);
    await _settle();

    expect(started, isTrue);
    expect(backend.keys, hasLength(2));
    expect(
      backend.keys[1],
      isNot(backend.keys[0]),
      reason: 'old idempotency never blocks an intentional reanalysis',
    );
    expect(backend.requests.last.reanalysisAttempt, 1);
    final after = _suggestion(container);
    expect(after.reanalysisCount, 1);
    expect(after.status, AiSuggestionStatus.pending);
    expect(after.needsReviewReason, 'low_confidence');
    expect(after.aiJobKey, backend.keys[1]);
    expect(after.history, hasLength(1));
    expect(after.history.single['status'], before.status.name);
    expect(after.history.single['aiJobKey'], backend.keys[0]);

    // Durable, so the report and a reload use the newest result.
    final stored =
        (await container
                .read(inspectionRepositoryProvider)
                .loadSession(_s(container).id))!
            .aiSuggestions
            .single;
    expect(stored.reanalysisCount, 1);
    expect(stored.history, hasLength(1));
  });

  test('2. a Needs Review finding can be reanalysed (and pass)', () async {
    final (container, backend, id) = await _analysed(_Mode.uncertain);
    expect(_suggestion(container).status, AiSuggestionStatus.pending);
    backend.mode = _Mode.confident;
    await container.read(activeSessionProvider.notifier).reanalyseFinding(id);
    await _settle();
    expect(_suggestion(container).status, AiSuggestionStatus.accepted);
    expect(backend.keys, hasLength(2));
  });

  test('3. a failed finding can be reanalysed (an explicit retry)', () async {
    final (container, backend, id) = await _analysed(_Mode.fail);
    expect(_s(container).findings.single.aiStatus, AiFindingStatus.failed);
    backend.mode = _Mode.confident;
    await container.read(activeSessionProvider.notifier).reanalyseFinding(id);
    await _settle();
    expect(_s(container).findings.single.aiStatus, AiFindingStatus.completed);
    expect(backend.keys, hasLength(1));
  });

  test('4. a manually corrected finding can be reanalysed; the correction '
      'stays in history for evaluation', () async {
    final (container, backend, id) = await _analysed(_Mode.confident);
    final other = DefectCatalogue.instance.entries
        .firstWhere(
          (e) => e.id != _suggestion(container).suggestedCatalogueEntryId,
        )
        .id;
    container
        .read(activeSessionProvider.notifier)
        .changeSuggestion(_suggestion(container).id, other);
    await _settle();

    await container.read(activeSessionProvider.notifier).reanalyseFinding(id);
    await _settle();
    final after = _suggestion(container);
    expect(backend.keys, hasLength(2));
    expect(after.history.single['status'], 'edited');
    expect(after.history.single['finalCatalogueEntryId'], other);
  });

  test('6. Edit Note & Reanalyse sends (and stores) the new note', () async {
    final (container, backend, id) = await _analysed(_Mode.confident);
    await container
        .read(activeSessionProvider.notifier)
        .reanalyseFinding(id, newNote: 'jubin kosong');
    await _settle();
    expect(backend.requests.last.note, 'jubin kosong');
    expect(_s(container).findings.single.description, 'jubin kosong');
  });

  test('10. one click never makes duplicate requests: a second tap while '
      'the first is starting or running is refused', () async {
    final (container, backend, id) = await _analysed(_Mode.confident);
    final notifier = container.read(activeSessionProvider.notifier);
    final results = await Future.wait([
      notifier.reanalyseFinding(id),
      notifier.reanalyseFinding(id),
    ]);
    final third = await notifier.reanalyseFinding(id);
    await _settle();
    expect(results.where((r) => r), hasLength(1));
    expect(third, isFalse);
    expect(backend.keys, hasLength(2));
  });

  testWidgets('the Reanalyse dialog offers As-Is, Edit Note and Cancel, and '
      'Cancel sends nothing', (tester) async {
    late ProviderContainer container;
    late _Backend backend;
    await tester.runAsync(() async {
      final r = await _analysed(_Mode.confident);
      container = r.$1;
      backend = r.$2;
    });
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
    // A confident result is settled: it's in the collapsed "Resolved"
    // group, where Reanalyse is still offered.
    await tester.tap(find.byKey(const ValueKey('review-show-resolved')));
    await tester.pump();

    await tester.tap(find.text('Reanalyse'));
    await tester.pumpAndSettle();
    expect(find.text('Reanalyse As-Is'), findsOneWidget);
    expect(find.text('Edit Note & Reanalyse'), findsOneWidget);
    expect(find.textContaining('uses one more AI analysis'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(backend.keys, hasLength(1));
  });
}
