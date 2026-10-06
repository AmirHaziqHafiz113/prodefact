import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/fake_auth_service.dart';
import '../support/fake_cloud_inspection_repository.dart';
import '../support/test_repository.dart';

/// Inspection resolution workflow: the inspector settles a finding from
/// its card — Recommended / search / Reject / Delete — with no extra AI
/// call, and a finding can never sit "queued" forever.

class _Backend extends FakeBillingService {
  _Backend() : super(initialBalanceCredits: 100000);

  bool fail = false;
  bool unsure = false;
  Completer<void>? hold;
  int calls = 0;

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    calls++;
    if (hold != null) await hold!.future;
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

Future<ProviderContainer> _start(_Backend backend) async {
  final container = ProviderContainer(
    overrides: testOverrides(billingService: backend),
  );
  addTearDown(container.dispose);
  await container
      .read(activeSessionProvider.notifier)
      .startNew(PropertyType.highRise);
  return container;
}

Future<Finding> _save(ProviderContainer c, String note) async {
  final notifier = c.read(activeSessionProvider.notifier);
  final photo = await notifier.captureFindingPhoto(
    source: EvidenceSource.camera,
  );
  return notifier.saveCameraFinding(
    sectionId: c.read(inspectionQueueProvider).first.id,
    photo: photo!,
    note: note,
  );
}

Future<void> _until(bool Function() done) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) fail('timed out');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

InspectionSession _session(ProviderContainer c) =>
    c.read(activeSessionProvider)!;

Finding _finding(ProviderContainer c, String id) =>
    _session(c).findings.firstWhere((f) => f.id == id);

AiSuggestion? _suggestion(ProviderContainer c, String findingId) =>
    _session(c).aiSuggestions
        .where((s) => s.findingId == findingId)
        .firstOrNull;

FindingResolution _resolution(ProviderContainer c, String id) =>
    resolutionOf(_finding(c, id), _suggestion(c, id));

const _manualId = 'wall.wall_tile.04';

void main() {
  group('queue ceiling', () {
    test('a finding that can never start (signed out) becomes a visible, '
        'retryable failure with a reason — not "queued" forever', () async {
      final auth = FakeAuthService();
      final backend = _Backend();
      final container = ProviderContainer(
        overrides: testOverridesWithSync(
          billingService: backend,
          authService: auth,
          cloudRepository: FakeCloudInspectionRepository(),
        ),
      );
      addTearDown(container.dispose);
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.startNew(PropertyType.highRise);
      notifier.maxParkedWait = Duration.zero;

      final finding = await _save(container, 'hollow wall tile');
      await _until(
        () =>
            _finding(container, finding.id).aiStatus == AiFindingStatus.failed,
      );
      expect(backend.calls, 0);
      expect(notifier.aiFailureReason(finding.id), contains('signed out'));
      expect(_resolution(container, finding.id).tone, FindingTone.red);

      // Retry after signing in: analysed, reason cleared, green.
      await auth.signUpWithEmail('inspector@example.com', 'secret1');
      await notifier.retryAiClassification(finding.id);
      await _until(
        () =>
            _finding(container, finding.id).aiStatus ==
            AiFindingStatus.completed,
      );
      expect(notifier.aiFailureReason(finding.id), isNull);
      expect(_resolution(container, finding.id).tone, FindingTone.green);
    });
  });

  group('manual selection', () {
    test('a failed finding can be settled by hand: green, report-ready, '
        'zero provider calls', () async {
      final backend = _Backend()..fail = true;
      final container = await _start(backend);
      final finding = await _save(container, 'hollow wall tile');
      await _until(
        () =>
            _finding(container, finding.id).aiStatus == AiFindingStatus.failed,
      );
      final callsBefore = backend.calls;
      expect(_resolution(container, finding.id).tone, FindingTone.red);

      final notifier = container.read(activeSessionProvider.notifier);
      expect(notifier.selectDefectForFinding(finding.id, _manualId), isTrue);

      expect(backend.calls, callsBefore, reason: 'manual pick calls no AI');
      final suggestion = _suggestion(container, finding.id)!;
      expect(suggestion.finalCatalogueEntryId, _manualId);
      expect(suggestion.providerId, 'manual');
      expect(_resolution(container, finding.id).tone, FindingTone.green);
      expect(ReportReadiness.of(_session(container)).isReady, isTrue);
    });

    test('a needs-review finding: picking a defect turns it green and keeps '
        'the AI result; rejecting makes it unresolved and blocks the '
        'report; it can still be picked again', () async {
      final backend = _Backend()..unsure = true;
      final container = await _start(backend);
      final finding = await _save(container, 'hollow wall tile');
      await _until(
        () => !aiFindingStatusIsInFlight(
          _finding(container, finding.id).aiStatus,
        ),
      );
      expect(
        _finding(container, finding.id).aiStatus,
        AiFindingStatus.needsReview,
      );
      expect(_resolution(container, finding.id).tone, FindingTone.orange);
      final callsBefore = backend.calls;
      final notifier = container.read(activeSessionProvider.notifier);

      notifier.selectDefectForFinding(finding.id, _manualId);
      expect(_resolution(container, finding.id).tone, FindingTone.green);
      expect(
        _finding(container, finding.id).aiStatus,
        AiFindingStatus.completed,
      );

      final suggestion = _suggestion(container, finding.id)!;
      notifier.rejectSuggestion(suggestion.id);
      expect(
        _resolution(container, finding.id).state,
        FindingResolutionState.unresolved,
      );
      expect(_resolution(container, finding.id).tone, FindingTone.red);
      final readiness = ReportReadiness.of(_session(container));
      expect(readiness.unresolved, 1);
      expect(readiness.isReady, isFalse);
      expect(readiness.summary, contains('unresolved'));

      // Still editable after a rejection.
      notifier.selectDefectForFinding(finding.id, 'wall.wall_tile.01');
      expect(_resolution(container, finding.id).tone, FindingTone.green);
      expect(ReportReadiness.of(_session(container)).isReady, isTrue);
      expect(backend.calls, callsBefore);
    });

    test('is refused while a request is running (a late answer must not '
        'overwrite the choice), and for an id outside the catalogue', () async {
      final backend = _Backend()..hold = Completer<void>();
      final container = await _start(backend);
      final finding = await _save(container, 'hollow wall tile');
      await _until(() => backend.calls == 1);
      final notifier = container.read(activeSessionProvider.notifier);

      expect(notifier.selectDefectForFinding(finding.id, _manualId), isFalse);
      expect(_suggestion(container, finding.id), isNull);

      backend.hold!.complete();
      await _until(
        () => !aiFindingStatusIsInFlight(
          _finding(container, finding.id).aiStatus,
        ),
      );
      expect(
        notifier.selectDefectForFinding(finding.id, 'not.a.real.id'),
        isFalse,
      );
    });
  });

  group('delete', () {
    test('deleting removes the finding, its suggestion and readiness '
        'counts, and asks the cloud to delete its copy', () async {
      final cloud = FakeCloudInspectionRepository();
      final container = ProviderContainer(
        overrides: testOverridesWithSync(
          billingService: _Backend(),
          authService: FakeAuthService(initialUser: testAuthUser),
          cloudRepository: cloud,
        ),
      );
      addTearDown(container.dispose);
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.startNew(PropertyType.highRise);
      final finding = await _save(container, 'hollow wall tile');
      await _until(
        () =>
            _finding(container, finding.id).aiStatus ==
            AiFindingStatus.completed,
      );

      notifier.removeFinding(finding.id);
      await _until(() => cloud.deletedFindingIds.contains(finding.id));

      expect(_session(container).findings, isEmpty);
      expect(_session(container).aiSuggestions, isEmpty);
      expect(ReportReadiness.of(_session(container)).isReady, isTrue);
    });
  });
}
