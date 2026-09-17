import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/test_repository.dart';

/// A spy [BillingService] that records every priced `analyseFinding`
/// call, delegating everything to a real [FakeBillingService] — used
/// to prove AI is never even *reached* except after the explicit
/// estimate/approval gate. Camera-first model: capturing/previewing a
/// photo, saving a finding, or editing a not-yet-approved note must
/// never spend Credits or call AI by themselves — only an explicit
/// [ActiveInspectionSession.approveAndRunAnalysis] (or, for an active
/// House Pass with Auto Analyse on, the save itself) does. See
/// docs/commercial_model.md ("The estimate -> approval -> reservation
/// -> settlement protocol").
class _SpyBillingService implements BillingService {
  _SpyBillingService(this._inner);

  final BillingService _inner;
  int analyseCallCount = 0;

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    analyseCallCount++;
    return _inner.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<CommercialConfig> getCommercialConfig() =>
      _inner.getCommercialConfig();

  @override
  Future<AnalysisEstimate> estimateFindingAnalysis({
    required String inspectionId,
    required String findingId,
    required AiLevel aiLevel,
  }) => _inner.estimateFindingAnalysis(
    inspectionId: inspectionId,
    findingId: findingId,
    aiLevel: aiLevel,
  );

  @override
  Future<TopUpIntent> createTopUpIntent(double amountMyr) =>
      _inner.createTopUpIntent(amountMyr);

  @override
  Future<HousePassPurchaseIntent> purchaseHousePass(String inspectionId) =>
      _inner.purchaseHousePass(inspectionId);

  @override
  Future<SandboxPaymentConfirmation> confirmSandboxPayment(String intentId) =>
      _inner.confirmSandboxPayment(intentId);
}

ProviderContainer _containerWithSpy(_SpyBillingService spy) {
  return ProviderContainer(overrides: testOverrides(billingService: spy));
}

void main() {
  test(
    'capturing a photo (before Save) does not call analyseFinding',
    () async {
      final spy = _SpyBillingService(FakeBillingService());
      final container = _containerWithSpy(spy);
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      final notifier = container.read(activeSessionProvider.notifier);

      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );

      expect(photo, isNotNull);
      expect(spy.analyseCallCount, 0);
      // Nothing was saved either — capturing alone creates no finding.
      expect(container.read(activeSessionProvider)!.findings, isEmpty);
    },
  );

  test('discarding a captured photo without saving never calls '
      'analyseFinding and leaves no finding behind', () async {
    final spy = _SpyBillingService(FakeBillingService());
    final container = _containerWithSpy(spy);
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    await notifier.discardCapturedFindingPhoto(photo!);

    expect(spy.analyseCallCount, 0);
    expect(container.read(activeSessionProvider)!.findings, isEmpty);
  });

  test('saving a camera-first finding (default Flex Credits, Auto '
      'Analyse off) never calls analyseFinding by itself — it waits '
      'for explicit approval', () async {
    final spy = _SpyBillingService(FakeBillingService());
    final container = _containerWithSpy(spy);
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    expect(spy.analyseCallCount, 0);

    final finding = notifier.saveCameraFinding(
      sectionId: queue.first.id,
      photo: photo!,
      note: 'Cracked tile',
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(activeSessionProvider)!.findings, hasLength(1));
    expect(finding.aiStatus, AiFindingStatus.awaitingApproval);
    expect(spy.analyseCallCount, 0);
  });

  test(
    'explicitly approving an awaitingApproval finding calls '
    'analyseFinding exactly once and settles to a terminal AI status',
    () async {
      final spy = _SpyBillingService(FakeBillingService());
      final container = _containerWithSpy(spy);
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      final notifier = container.read(activeSessionProvider.notifier);
      final queue = container.read(inspectionQueueProvider);

      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      final finding = notifier.saveCameraFinding(
        sectionId: queue.first.id,
        photo: photo!,
        note: 'Cracked tile',
      );

      await notifier.approveAndRunAnalysis(finding.id);
      await Future<void>.delayed(Duration.zero);

      expect(spy.analyseCallCount, 1);
      final updated = container.read(activeSessionProvider)!.findings.single;
      expect(
        updated.aiStatus,
        anyOf(AiFindingStatus.completed, AiFindingStatus.needsReview),
      );
    },
  );

  test('an inspection with Auto Analyse enabled calls analyseFinding '
      'automatically on save, without any explicit approval step', () async {
    final spy = _SpyBillingService(FakeBillingService());
    final container = _containerWithSpy(spy);
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);
    final sessionId = container.read(activeSessionProvider)!.id;
    notifier.setAutoAnalyseEnabled(true);
    final queue = container.read(inspectionQueueProvider);

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    final finding = notifier.saveCameraFinding(
      sectionId: queue.first.id,
      photo: photo!,
      note: 'Cracked tile',
    );
    expect(finding.aiStatus, AiFindingStatus.queued);
    await Future<void>.delayed(Duration.zero);

    expect(spy.analyseCallCount, 1);
    expect(sessionId, isNotEmpty); // sanity: session was actually created
  });

  test('marking an area (or every area) physically complete does not '
      'call analyseFinding by itself', () async {
    final spy = _SpyBillingService(FakeBillingService());
    final container = _containerWithSpy(spy);
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);
    final statusNotifier = container.read(sectionStatusesProvider.notifier);

    for (final section in queue) {
      statusNotifier.setStatus(section.id, SectionStatus.completed);
    }
    expect(spy.analyseCallCount, 0);

    await notifier.markPhysicalInspectionComplete();
    expect(spy.analyseCallCount, 0);
  });

  test("editing a finding's note after saving does not change its "
      'awaitingApproval status or call analyseFinding (only new '
      'evidence, or explicit approval, does)', () async {
    final spy = _SpyBillingService(FakeBillingService());
    final container = _containerWithSpy(spy);
    addTearDown(container.dispose);
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    final finding = notifier.saveCameraFinding(
      sectionId: queue.first.id,
      photo: photo!,
      note: 'Cracked tile',
    );
    await Future<void>.delayed(Duration.zero);
    expect(spy.analyseCallCount, 0);
    expect(finding.aiStatus, AiFindingStatus.awaitingApproval);

    notifier.updateFinding(
      findingId: finding.id,
      description: 'Cracked tile, updated wording only',
      notes: null,
    );
    await Future<void>.delayed(Duration.zero);

    expect(spy.analyseCallCount, 0);
    final updated = container.read(activeSessionProvider)!.findings.single;
    expect(updated.aiStatus, AiFindingStatus.awaitingApproval);
  });
}
