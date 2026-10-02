import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/data/report/pdf_report_renderer.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// One photo = one finding (tester feedback, 2026-10-01): every photo
/// becomes its own finding — even another angle of the same defect —
/// with its own note, AI job, classification, review and report entry.
/// Historical multi-photo findings still load and render.

/// Records every AI request, so each finding's job can be checked.
class _RecordingBilling extends FakeBillingService {
  _RecordingBilling() : super(initialBalanceCredits: 5000);

  final List<AiFindingClassificationRequest> requests = [];

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) {
    requests.add(request);
    return super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
  }
}

Future<(ProviderContainer, FakeEvidenceCaptureService)> _start({
  int galleryPickCount = 1,
  BillingService? billing,
}) async {
  final capture = FakeEvidenceCaptureService()
    ..galleryPickCount = galleryPickCount;
  final container = ProviderContainer(
    overrides: testOverrides(captureService: capture, billingService: billing),
  );
  addTearDown(container.dispose);
  final notifier = container.read(activeSessionProvider.notifier);
  await notifier.startNew(PropertyType.highRise);
  return (container, capture);
}

String _firstArea(ProviderContainer c) =>
    c.read(inspectionQueueProvider).first.id;

Future<List<Finding>> _pickAndSave(
  ProviderContainer container,
  List<String?> notes, {
  EvidenceSource source = EvidenceSource.gallery,
}) async {
  final notifier = container.read(activeSessionProvider.notifier);
  final photos = await notifier.captureFindingPhotos(source: source);
  return notifier.saveCameraFindings(
    sectionId: _firstArea(container),
    photos: photos,
    notes: notes,
  );
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  test('1. one gallery photo creates one finding', () async {
    final (container, _) = await _start();
    final saved = await _pickAndSave(container, ['Crack']);
    expect(saved, hasLength(1));
    expect(container.read(activeSessionProvider)!.findings, hasLength(1));
  });

  test('2. two selected gallery photos create two findings', () async {
    final (container, _) = await _start(galleryPickCount: 2);
    final saved = await _pickAndSave(container, ['Tile front', 'Tile side']);
    expect(saved, hasLength(2));
    expect(container.read(activeSessionProvider)!.findings, hasLength(2));
  });

  test('3. three selected gallery photos create three findings (the pick '
      'stays capped at 3)', () async {
    final (container, capture) = await _start(galleryPickCount: 7);
    final saved = await _pickAndSave(container, ['A', 'B', 'C']);
    expect(saved, hasLength(3));
    expect(capture.captureCount, 3);
    expect(saved.map((f) => f.description), ['A', 'B', 'C']);
  });

  test('4. each new finding holds exactly one photo, with its own finding '
      'and evidence ids, and that survives a reload', () async {
    final (container, _) = await _start(galleryPickCount: 3);
    final saved = await _pickAndSave(container, ['A', 'B', 'C']);
    for (final f in saved) {
      expect(f.evidence, hasLength(1));
      expect(f.evidence.single.findingId, f.id);
    }
    expect(saved.map((f) => f.id).toSet(), hasLength(3));
    expect(saved.map((f) => f.evidence.single.id).toSet(), hasLength(3));
    expect(saved.map((f) => f.evidence.single.filePath).toSet(), hasLength(3));

    await _settle();
    final reloaded = await container
        .read(inspectionRepositoryProvider)
        .loadSession(container.read(activeSessionProvider)!.id);
    expect(reloaded!.findings, hasLength(3));
    for (final f in reloaded.findings) {
      expect(f.evidence, hasLength(1));
    }
  });

  test('5. taking another camera photo creates a new finding, even of the '
      'same defect', () async {
    final (container, _) = await _start();
    final first = await _pickAndSave(container, [
      'Hollow tile',
    ], source: EvidenceSource.camera);
    final second = await _pickAndSave(container, [
      'Hollow tile',
    ], source: EvidenceSource.camera);
    final findings = container.read(activeSessionProvider)!.findings;
    expect(findings, hasLength(2));
    expect(first.single.id, isNot(second.single.id));
    expect(findings.every((f) => f.evidence.length == 1), isTrue);
  });

  test('7 + 8. each finding gets its own AI job (one photo per request) and '
      'its own classification', () async {
    final billing = _RecordingBilling();
    final (container, _) = await _start(
      galleryPickCount: 3,
      billing: billing,
    );
    final saved = await _pickAndSave(container, ['Crack', 'Stain', 'Gap']);
    await _settle();

    expect(
      billing.requests.map((r) => r.findingId).toSet(),
      saved.map((f) => f.id).toSet(),
    );
    expect(billing.requests, hasLength(3));
    for (final r in billing.requests) {
      expect(r.evidenceIds, hasLength(1));
    }
    final session = container.read(activeSessionProvider)!;
    expect(
      session.aiSuggestions.map((s) => s.findingId).toSet(),
      saved.map((f) => f.id).toSet(),
    );
    expect(session.aiSuggestions, hasLength(3));
  });

  test('9 + 10 + 11. two findings with the same classification are never '
      'merged: separate suggestions, separate review, separate one-photo '
      'report entries', () async {
    final (container, _) = await _start(
      galleryPickCount: 2,
      billing: _RecordingBilling(),
    );
    final saved = await _pickAndSave(container, ['Hollow tile', 'Hollow tile']);
    await _settle();

    final session = container.read(activeSessionProvider)!;
    expect(session.findings, hasLength(2));
    final entries = session.aiSuggestions
        .map((s) => s.finalCatalogueEntryId)
        .toSet();
    expect(session.aiSuggestions, hasLength(2));
    expect(entries, hasLength(1), reason: 'same classification for both');
    expect(AiReviewProgress.of(session).total, 2);

    final model = buildReportModel(
      session: session,
      propertyTypeLabel: 'High Rise',
      generatedAt: DateTime(2026, 10, 1),
    );
    final reported = model.areas.expand((a) => a.findings).toList();
    expect(reported, hasLength(2));
    expect(
      reported.map((f) => f.evidenceFilePaths.single).toSet(),
      saved.map((f) => f.evidence.single.displayFilePath).toSet(),
    );
    expect(reported.every((f) => f.evidenceFilePaths.length == 1), isTrue);
    expect(await PdfReportRenderer().render(model), isNotEmpty);
  });

  test('12 + 13. a historical multi-photo finding still loads, appears as '
      'one report entry with both photos, and renders', () async {
    final (container, capture) = await _start();
    final notifier = container.read(activeSessionProvider.notifier);
    final finding = (await _pickAndSave(container, [
      'Old finding',
    ], source: EvidenceSource.camera)).single;
    // The pre-change data shape: a second photo on the same finding.
    await notifier.addEvidence(
      findingId: finding.id,
      source: EvidenceSource.camera,
    );
    await _settle();
    expect(capture.captureCount, 2);

    final session = container.read(activeSessionProvider)!;
    final reloaded = await container
        .read(inspectionRepositoryProvider)
        .loadSession(session.id);
    expect(reloaded!.findings.single.evidence, hasLength(2));

    final model = buildReportModel(
      session: reloaded,
      propertyTypeLabel: 'High Rise',
      generatedAt: DateTime(2026, 10, 1),
    );
    final entry = model.areas.expand((a) => a.findings).single;
    expect(entry.evidenceFilePaths, hasLength(2));
    expect(await PdfReportRenderer().render(model), isNotEmpty);
  });

  testWidgets('the gallery preview gives each photo its own note and saves '
      'one finding per photo; a removed photo creates nothing', (tester) async {
    late ProviderContainer container;
    await tester.runAsync(() async {
      (container, _) = await _start(galleryPickCount: 3);
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AreaInspectionScreen(sectionId: _firstArea(container)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Take Defect Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Each photo is saved as its own finding'),
      findsOneWidget,
    );
    expect(find.text('Save 3 Findings'), findsOneWidget);
    // No AI level choice at upload — that lives only in Profile.
    expect(find.text('Expert'), findsNothing);

    Finder noteField() => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(TextField),
    );
    Future<void> select(int i) async {
      await tester.tap(find.byKey(ValueKey('preview-thumb-$i')));
      await tester.pumpAndSettle();
    }

    await tester.enterText(noteField(), 'Front view');
    await select(1);
    expect(find.text('Front view'), findsNothing);
    await tester.enterText(noteField(), 'Side view');
    await select(2);
    await tester.enterText(noteField(), 'Close-up');

    // Drop the side view: it must not become a finding.
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('preview-thumb-1')),
        matching: find.byIcon(Icons.close),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Save 2 Findings'), findsOneWidget);

    await tester.tap(find.text('Save 2 Findings'));
    await tester.pumpAndSettle();

    final findings = container.read(activeSessionProvider)!.findings;
    expect(
      findings.map((f) => f.description).toSet(),
      {'Front view', 'Close-up'},
    );
    expect(findings.every((f) => f.evidence.length == 1), isTrue);
    expect(find.text('✓ 2 findings saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
