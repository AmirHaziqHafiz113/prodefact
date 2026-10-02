import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/inspection_queue_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// Auto Analyse is always on (tester feedback, 2026-10-02: "Ni main
/// reason pakai app ni. Buatkan ia sentiasa ON"). There is no switch:
/// every saved finding with its quick note is analysed automatically.

/// Counts every analysis the fake backend actually runs.
class _CountingBilling extends FakeBillingService {
  _CountingBilling() : super(initialBalanceCredits: 10000);

  int analyses = 0;

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) {
    analyses++;
    return super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
  }
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 60));

void main() {
  testWidgets('1 + 2. a new inspection shows AI analysis as automatic, with '
      'no switch to turn it off', (tester) async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();

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

    expect(
      find.text('AI analysis runs automatically for every saved finding.'),
      findsOneWidget,
    );
    expect(find.byType(SwitchListTile), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Auto Analyse'), findsNothing);
  });

  test('4 + 5. saving a finding queues AI at once and it completes with no '
      'Analyse/approval step', () async {
    final billing = _CountingBilling();
    final container = ProviderContainer(
      overrides: testOverrides(billingService: billing),
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
      note: 'Hollow tile',
    );
    expect(finding.aiStatus, AiFindingStatus.queued);

    await _settle();
    final saved = container.read(activeSessionProvider)!.findings.single;
    expect(saved.aiStatus, AiFindingStatus.completed);
    expect(billing.analyses, 1);
  });

  test('a finding saved without a note waits for the note, then is '
      'analysed automatically once it is added', () async {
    final billing = _CountingBilling();
    final container = ProviderContainer(
      overrides: testOverrides(billingService: billing),
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
    );
    expect(finding.aiStatus, AiFindingStatus.awaitingApproval);

    notifier.updateFinding(
      findingId: finding.id,
      description: 'Crack',
      notes: null,
    );
    await _settle();
    expect(
      container.read(activeSessionProvider)!.findings.single.aiStatus,
      AiFindingStatus.completed,
    );
    expect(billing.analyses, 1);
  });

  test('3. an inspection stored with Auto Analyse off (an older build) '
      'is treated as on: its waiting finding is analysed on resume', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repository = DriftInspectionRepository(db);
    final billing = _CountingBilling();
    final container = ProviderContainer(
      overrides: testOverrides(repository: repository, billingService: billing),
    );
    addTearDown(container.dispose);

    // The pre-change state: a session with the opt-out stored, and a
    // finding (with its note) left waiting for an approval tap.
    final session = await repository.createSession(
      industry: Industry.homeInspection,
      assetTypeId: 'highRise',
      initialSections: const [
        Section(
          id: 'bathroom',
          name: 'Bathroom',
          elements: [],
          isPlumbing: true,
        ),
      ],
    );
    await db.customStatement(
      'UPDATE inspection_session_rows SET auto_analyse_enabled = 0',
    );
    final now = DateTime(2026, 10, 1);
    await repository.saveFinding(
      session.id,
      Finding(
        id: 'finding_old',
        sectionId: 'bathroom',
        description: 'Leaking tap',
        createdAt: now,
        updatedAt: now,
        aiStatus: AiFindingStatus.awaitingApproval,
      ),
    );
    await repository.addEvidence(
      session.id,
      Evidence(
        id: 'evidence_old',
        findingId: 'finding_old',
        filePath: '/fake/old.jpg',
        createdAt: now,
      ),
    );

    expect(
      await container.read(activeSessionProvider.notifier).resume(session.id),
      isTrue,
    );
    await _settle();

    final finding = container.read(activeSessionProvider)!.findings.single;
    expect(finding.aiStatus, AiFindingStatus.completed);
    expect(billing.analyses, 1);
  });
}
