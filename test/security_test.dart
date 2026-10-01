import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/analytics/analytics_providers.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import 'support/test_repository.dart';

/// Captures every request handed to [analyseFinding] instead of just
/// delegating silently — lets a test inspect exactly what data would
/// leave the device, while still running the real (fake) pricing/
/// classification logic underneath.
class _CapturingBillingService implements BillingService {
  _CapturingBillingService(this._inner);

  final BillingService _inner;
  final List<AiFindingClassificationRequest> requests = [];

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    requests.add(request);
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

/// Records every event logged instead of calling Firebase Analytics.
class _RecordingAnalyticsService implements AnalyticsService {
  final List<AnalyticsEvent> events = [];

  @override
  Future<void> logEvent(AnalyticsEvent event) async {
    events.add(event);
  }
}

void main() {
  group('filename/path sanitization', () {
    test('a session id crafted to look like a path-traversal attempt never '
        'produces a filename containing a path separator or ".."', () {
      final name = buildReportFileName(
        sessionId: '../../etc/passwd',
        date: DateTime(2026, 1, 1),
      );

      expect(name, isNot(contains('/')));
      expect(name, isNot(contains(r'\')));
      expect(name, isNot(contains('..')));
      expect(name.startsWith('ProDefact_HomeInspection_'), isTrue);
      expect(name.endsWith('.pdf'), isTrue);
    });

    test('null-byte and control-character injection attempts are stripped '
        'from the generated filename', () {
      final name = buildReportFileName(
        sessionId: 'session ; rm -rf ~\n',
        date: DateTime(2026, 1, 1),
      );

      expect(name, isNot(contains(' ')));
      expect(name, isNot(contains(';')));
      expect(name, isNot(contains(' ')));
      expect(name, isNot(contains('\n')));
    });
  });

  group('AI request data minimization', () {
    test('the AI classification request never includes the session '
        'owner\'s uid, email, or any auth token — only redacted area '
        'context (structurally: AiFindingClassificationRequest has no '
        'such fields at all)', () async {
      final capturingBilling = _CapturingBillingService(FakeBillingService());
      final container = ProviderContainer(
        overrides: testOverrides(billingService: capturingBilling),
      );
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.setAutoAnalyseEnabled(true);
      final queue = container.read(inspectionQueueProvider);

      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      notifier.saveCameraFinding(
        sectionId: queue.first.id,
        photo: photo!,
        note: 'Cracked tile',
      );
      // The queue is fire-and-forget; give it a tick to run.
      await Future<void>.delayed(Duration.zero);

      expect(capturingBilling.requests, hasLength(1));
      final request = capturingBilling.requests.single;
      // Only redacted, area-shaped data — session id (a local,
      // non-identifying opaque string), area name/plumbing flag, note,
      // and evidence ids. No owner uid/email field exists on this type
      // at all to leak in the first place.
      expect(request.sessionId, isNotEmpty);
      expect(request.findingId, isNotEmpty);
    });
  });

  group('analytics excludes sensitive content', () {
    test('analytics events logged during a full workflow carry only the '
        'closed AnalyticsEvent enum value — never finding text, notes, '
        'image paths, or AI output', () async {
      const sensitiveText = 'INSPECTOR_SENSITIVE_NOTE_98765';
      final analytics = _RecordingAnalyticsService();
      final container = ProviderContainer(
        overrides: [
          ...testOverrides(),
          analyticsServiceProvider.overrideWithValue(analytics),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.setAutoAnalyseEnabled(true);
      final queue = container.read(inspectionQueueProvider);
      final statusNotifier = container.read(sectionStatusesProvider.notifier);

      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      notifier.saveCameraFinding(
        sectionId: queue.first.id,
        photo: photo!,
        note: sensitiveText,
      );
      await Future<void>.delayed(Duration.zero);
      for (final s in queue) {
        statusNotifier.setStatus(s.id, SectionStatus.completed);
      }
      await notifier.markPhysicalInspectionComplete();

      final suggestion = container
          .read(activeSessionProvider)!
          .aiSuggestions
          .single;
      // A fake/demo classification always resolves to *some* catalogue
      // entry in this environment (see FakeAiInspectionService) — force
      // it resolved either way so report generation's gate passes.
      if (suggestion.status == AiSuggestionStatus.pending) {
        if (suggestion.needsReview) {
          notifier.rejectSuggestion(suggestion.id);
        } else {
          notifier.acceptSuggestion(suggestion.id);
        }
      }
      await notifier.generateReport();

      expect(analytics.events, isNotEmpty);
      // AnalyticsEvent is a plain enum — there is no field on it that
      // could carry `sensitiveText` even if a call site tried to pass
      // it, so this is a structural guarantee, confirmed here by
      // asserting the actual recorded event list.
      expect(analytics.events, everyElement(isA<AnalyticsEvent>()));
      expect(
        analytics.events.map((e) => e.toString()).join(),
        isNot(contains(sensitiveText)),
      );
    });
  });

  group('permission denial handled gracefully', () {
    test('a camera/photo-library permission denial (capture throws) is '
        'caught and surfaced as a friendly error, never an uncaught '
        'exception, and no finding is ever created', () async {
      final container = ProviderContainer(
        overrides: testOverrides(
          captureService: _PermissionDeniedCaptureService(),
        ),
      );
      addTearDown(container.dispose);
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      final notifier = container.read(activeSessionProvider.notifier);
      notifier.setAutoAnalyseEnabled(true);

      // Must not throw — the whole point of the hardening is that
      // this awaits cleanly to completion.
      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );

      expect(photo, isNull);
      expect(container.read(activeSessionErrorProvider), isNotNull);
      final session = container.read(activeSessionProvider)!;
      expect(session.findings, isEmpty);
    });
  });
}

class _PermissionDeniedCaptureService implements EvidenceCaptureService {
  @override
  Future<CapturedEvidence?> captureImage({
    required String findingId,
    required EvidenceSource source,
  }) {
    throw Exception('Camera permission denied');
  }

  @override
  Future<List<CapturedEvidence>> captureImages({
    required String findingId,
    required EvidenceSource source,
    int maxImages = 3,
  }) {
    throw Exception('Photo library permission denied');
  }
}
