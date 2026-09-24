import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/ai/priced_ai_classification_coordinator.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';
import 'package:prodefact/data/remote/remote_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/fake_auth_service.dart';
import '../support/fake_cloud_inspection_repository.dart';
import '../support/scripted_billing_service.dart';
import '../support/test_repository.dart';

/// Recovery of AI work interrupted by navigation, app termination,
/// restart, session reload, or connection loss. Each "restart" below is
/// a brand-new `ProviderContainer` over the same database — exactly what
/// an app relaunch looks like to this code: every in-memory future,
/// timer, and in-flight guard is gone, and only persisted state remains.

/// Drains the event queue deeply enough for a full upload + analysis
/// chain (sync pushes the session and each evidence file through
/// several async repository calls). No real timers are involved.
Future<void> _settle() => pumpEventQueue(times: 1000);

typedef _Seeded = ({String sessionId, String findingId, String sectionId});

/// A session with one photographed, saved finding. Auto-analyse is off
/// (the Flex Credits default), so it is left `awaitingApproval` and no AI
/// has run; each test then puts it into the persisted state it needs.
Future<_Seeded> _seedFinding(DriftInspectionRepository repo) async {
  final container = ProviderContainer(
    overrides: testOverrides(repository: repo),
  );
  await container
      .read(activeSessionProvider.notifier)
      .startNew(
        PropertyType.highRise,
        commercialMode: CommercialMode.flexCredits,
        selectedAiLevel: AiLevel.smart,
      );
  final notifier = container.read(activeSessionProvider.notifier);
  final section = container.read(inspectionQueueProvider).first;
  final photo = await notifier.captureFindingPhoto(
    source: EvidenceSource.camera,
  );
  final finding = notifier.saveCameraFinding(
    sectionId: section.id,
    photo: photo!,
    note: 'Cracked tile',
  );
  await _settle();
  final sessionId = container.read(activeSessionProvider)!.id;
  container.dispose();
  return (sessionId: sessionId, findingId: finding.id, sectionId: section.id);
}

/// "Relaunches the app" and opens the session, which is when recovery
/// runs.
Future<ProviderContainer> _reopen(
  DriftInspectionRepository repo,
  ScriptedBillingService billing,
  String sessionId,
) async {
  final container = ProviderContainer(
    overrides: testOverrides(repository: repo, billingService: billing),
  );
  addTearDown(container.dispose);
  await container.read(activeSessionProvider.notifier).resume(sessionId);
  await _settle();
  return container;
}

Future<Finding> _storedFinding(
  DriftInspectionRepository repo,
  _Seeded seeded,
) async {
  final session = await repo.loadSession(seeded.sessionId);
  return session!.findings.singleWhere((f) => f.id == seeded.findingId);
}

AiAnalysisAttempt _attempt(String key, {required Duration age}) =>
    AiAnalysisAttempt(
      idempotencyKey: key,
      aiLevel: AiLevel.smart,
      submittedAt: DateTime.now().subtract(age),
    );

/// Old enough that the original backend invocation is guaranteed over.
const _stale = Duration(minutes: 10);

AiFindingClassificationRequest _requestFor(_Seeded seeded) =>
    AiFindingClassificationRequest(
      sessionId: seeded.sessionId,
      findingId: seeded.findingId,
      sectionName: 'Living',
      sectionIsPlumbing: false,
      note: 'Cracked tile',
      evidenceFilePaths: const ['/fake/evidence/1.jpg'],
      evidenceIds: const ['evidence_1'],
    );

void main() {
  late DriftInspectionRepository repo;

  setUp(() => repo = createInMemoryRepository());

  group('terminal states are never re-run', () {
    test('1. a completed finding is never requeued', () async {
      final seeded = await _seedFinding(repo);
      await repo.setFindingAiStatus(
        seeded.sessionId,
        seeded.findingId,
        AiFindingStatus.completed,
      );
      final billing = ScriptedBillingService();

      await _reopen(repo, billing, seeded.sessionId);

      expect(billing.calls, isEmpty);
      expect(
        (await _storedFinding(repo, seeded)).aiStatus,
        AiFindingStatus.completed,
      );
    });

    test('2. a needsReview finding is never requeued', () async {
      final seeded = await _seedFinding(repo);
      await repo.setFindingAiStatus(
        seeded.sessionId,
        seeded.findingId,
        AiFindingStatus.needsReview,
      );
      final billing = ScriptedBillingService();

      await _reopen(repo, billing, seeded.sessionId);

      expect(billing.calls, isEmpty);
      expect(
        (await _storedFinding(repo, seeded)).aiStatus,
        AiFindingStatus.needsReview,
      );
    });

    test('3. a failed finding stays failed on reload and remains '
        'retryable; its Retry mints a fresh key', () async {
      final seeded = await _seedFinding(repo);
      await repo.setFindingAiStatus(
        seeded.sessionId,
        seeded.findingId,
        AiFindingStatus.failed,
      );
      final billing = ScriptedBillingService();

      final container = await _reopen(repo, billing, seeded.sessionId);
      expect(billing.calls, isEmpty, reason: 'never auto-retried');
      expect(
        (await _storedFinding(repo, seeded)).aiStatus,
        AiFindingStatus.failed,
      );

      await container
          .read(activeSessionProvider.notifier)
          .retryAiClassification(seeded.findingId);
      await _settle();

      expect(billing.calls, hasLength(1));
      expect(billing.calls.single.idempotencyKey, startsWith(seeded.findingId));
      final stored = await _storedFinding(repo, seeded);
      expect(stored.aiStatus, AiFindingStatus.completed);
      expect(stored.aiAttempt, isNull);
    });
  });

  group('stale in-flight states are reconciled on reload', () {
    test('4. a stale queued finding resumes and completes', () async {
      final seeded = await _seedFinding(repo);
      await repo.setFindingAiStatus(
        seeded.sessionId,
        seeded.findingId,
        AiFindingStatus.queued,
      );
      final billing = ScriptedBillingService();

      await _reopen(repo, billing, seeded.sessionId);

      expect(billing.calls, hasLength(1));
      expect(
        (await _storedFinding(repo, seeded)).aiStatus,
        AiFindingStatus.completed,
      );
    });

    test('5. a stale uploading finding resumes and completes', () async {
      final seeded = await _seedFinding(repo);
      await repo.setFindingAiStatus(
        seeded.sessionId,
        seeded.findingId,
        AiFindingStatus.uploading,
      );
      final billing = ScriptedBillingService();

      await _reopen(repo, billing, seeded.sessionId);

      expect(billing.calls, hasLength(1));
      expect(
        (await _storedFinding(repo, seeded)).aiStatus,
        AiFindingStatus.completed,
      );
    });

    test('6a. a stale analyzing finding replays its own key and level, '
        'then clears the attempt', () async {
      final seeded = await _seedFinding(repo);
      await repo.beginFindingAiAttempt(
        seeded.sessionId,
        seeded.findingId,
        AiAnalysisAttempt(
          idempotencyKey: 'original_key',
          aiLevel: AiLevel.expert,
          submittedAt: DateTime.now().subtract(_stale),
        ),
      );
      final billing = ScriptedBillingService();

      await _reopen(repo, billing, seeded.sessionId);

      expect(billing.calls, hasLength(1));
      expect(billing.calls.single.idempotencyKey, 'original_key');
      expect(billing.calls.single.aiLevel, AiLevel.expert);
      final stored = await _storedFinding(repo, seeded);
      expect(stored.aiStatus, AiFindingStatus.completed);
      expect(stored.aiAttempt, isNull);
    });

    test('6b. an analyzing finding whose original request finished on the '
        'backend while the app was closed gets the stored result, with no '
        'second charge', () async {
      final seeded = await _seedFinding(repo);
      await repo.beginFindingAiAttempt(
        seeded.sessionId,
        seeded.findingId,
        _attempt('original_key', age: _stale),
      );
      final billing = ScriptedBillingService();
      await billing.completeJobOnBackend(
        request: _requestFor(seeded),
        idempotencyKey: 'original_key',
      );
      expect(billing.providerRuns, 1);

      final container = await _reopen(repo, billing, seeded.sessionId);

      expect(billing.calls.single.idempotencyKey, 'original_key');
      expect(billing.providerRuns, 1, reason: 'replay must not re-run/charge');
      final stored = await _storedFinding(repo, seeded);
      // Whatever the stored job concluded — a confident match or one that
      // needs manual review — is applied as-is.
      expect(
        stored.aiStatus,
        isIn([AiFindingStatus.completed, AiFindingStatus.needsReview]),
      );
      expect(stored.aiAttempt, isNull);
      expect(
        container.read(activeSessionProvider)!.aiSuggestions,
        hasLength(1),
      );
    });

    test(
      '6c. a recently submitted analyzing finding is not replayed yet '
      '(the original may still be running) and keeps its real state',
      () async {
        final seeded = await _seedFinding(repo);
        await repo.beginFindingAiAttempt(
          seeded.sessionId,
          seeded.findingId,
          _attempt('recent_key', age: const Duration(seconds: 20)),
        );
        final billing = ScriptedBillingService();

        final container = await _reopen(repo, billing, seeded.sessionId);

        expect(billing.calls, isEmpty);
        final stored = await _storedFinding(repo, seeded);
        expect(stored.aiStatus, AiFindingStatus.analyzing);
        expect(stored.aiAttempt?.idempotencyKey, 'recent_key');
        expect(
          container.read(activeSessionProvider)!.findings.single.aiStatus,
          AiFindingStatus.analyzing,
        );
      },
    );

    test('6d. a legacy analyzing finding with no persisted key (written by '
        'a build before this fix) moves to failed for an explicit Retry, '
        'never re-sent under a guessed key', () async {
      final seeded = await _seedFinding(repo);
      await repo.setFindingAiStatus(
        seeded.sessionId,
        seeded.findingId,
        AiFindingStatus.analyzing,
      );
      final billing = ScriptedBillingService();

      await _reopen(repo, billing, seeded.sessionId);
      await _settle();

      expect(billing.calls, isEmpty);
      expect(
        (await _storedFinding(repo, seeded)).aiStatus,
        AiFindingStatus.failed,
      );
    });
  });

  group('recovery is idempotent', () {
    test('7. reopening the session again after recovery triggers nothing '
        'new', () async {
      final seeded = await _seedFinding(repo);
      await repo.setFindingAiStatus(
        seeded.sessionId,
        seeded.findingId,
        AiFindingStatus.queued,
      );
      final billing = ScriptedBillingService();

      final container = await _reopen(repo, billing, seeded.sessionId);
      final notifier = container.read(activeSessionProvider.notifier);
      await notifier.resume(seeded.sessionId);
      await _settle();
      await notifier.resume(seeded.sessionId);
      await _settle();

      expect(billing.calls, hasLength(1));
    });

    test('8. repeated recovery triggers and provider reads while a request '
        'is in flight never start a duplicate request', () async {
      final seeded = await _seedFinding(repo);
      await repo.beginFindingAiAttempt(
        seeded.sessionId,
        seeded.findingId,
        _attempt('original_key', age: _stale),
      );
      final billing = ScriptedBillingService()..gate = Completer<void>();

      final container = await _reopen(repo, billing, seeded.sessionId);
      final notifier = container.read(activeSessionProvider.notifier);
      for (var i = 0; i < 3; i++) {
        container.read(activeSessionProvider);
        await notifier.processQueuedAiClassifications();
        await notifier.resume(seeded.sessionId);
      }
      await _settle();
      expect(billing.calls, hasLength(1));

      billing.gate!.complete();
      await _settle();

      expect(billing.calls, hasLength(1));
      expect(
        (await _storedFinding(repo, seeded)).aiStatus,
        AiFindingStatus.completed,
      );
    });
  });

  group('billing identity', () {
    test('9 + 10. a request whose response was lost keeps its key; the '
        'relaunch replays that same key and gets the stored result without '
        'a second charge', () async {
      final seeded = await _seedFinding(repo);
      await repo.setFindingAiStatus(
        seeded.sessionId,
        seeded.findingId,
        AiFindingStatus.queued,
      );
      final billing = ScriptedBillingService(
        steps: [ScriptedAnalysisStep.succeedButLoseResponse],
      );

      final first = await _reopen(repo, billing, seeded.sessionId);
      expect(billing.calls, hasLength(1));
      expect(billing.providerRuns, 1);
      final afterLoss = await _storedFinding(repo, seeded);
      expect(afterLoss.aiStatus, AiFindingStatus.queued);
      expect(
        afterLoss.aiAttempt?.idempotencyKey,
        billing.calls.single.idempotencyKey,
      );

      // The app is closed and reopened after the replay window.
      first.dispose();
      await repo.beginFindingAiAttempt(
        seeded.sessionId,
        seeded.findingId,
        afterLoss.aiAttempt!.resubmittedAt(DateTime.now().subtract(_stale)),
      );
      await _reopen(repo, billing, seeded.sessionId);

      expect(billing.calls, hasLength(2));
      expect(
        billing.calls.last.idempotencyKey,
        billing.calls.first.idempotencyKey,
      );
      expect(billing.providerRuns, 1, reason: 'charged exactly once');
      final stored = await _storedFinding(repo, seeded);
      expect(stored.aiStatus, AiFindingStatus.completed);
      expect(stored.aiAttempt, isNull);
    });

    test('a definitive backend rejection clears the key, so Retry is a '
        'genuinely new request', () async {
      final seeded = await _seedFinding(repo);
      await repo.setFindingAiStatus(
        seeded.sessionId,
        seeded.findingId,
        AiFindingStatus.queued,
      );
      final billing = ScriptedBillingService(
        steps: [ScriptedAnalysisStep.rejectDefinitively],
      );

      final container = await _reopen(repo, billing, seeded.sessionId);
      final failed = await _storedFinding(repo, seeded);
      expect(failed.aiStatus, AiFindingStatus.failed);
      expect(failed.aiAttempt, isNull);

      await container
          .read(activeSessionProvider.notifier)
          .retryAiClassification(seeded.findingId);
      await _settle();

      expect(billing.calls, hasLength(2));
      expect(
        billing.calls.last.idempotencyKey,
        isNot(billing.calls.first.idempotencyKey),
      );
      expect(
        (await _storedFinding(repo, seeded)).aiStatus,
        AiFindingStatus.completed,
      );
    });

    test('Retry of a failed finding whose outcome was unknown replays the '
        'same key rather than risking a second charge', () async {
      final seeded = await _seedFinding(repo);
      await repo.beginFindingAiAttempt(
        seeded.sessionId,
        seeded.findingId,
        _attempt('unknown_outcome_key', age: _stale),
      );
      await repo.setFindingAiStatus(
        seeded.sessionId,
        seeded.findingId,
        AiFindingStatus.failed,
      );
      final billing = ScriptedBillingService();

      final container = await _reopen(repo, billing, seeded.sessionId);
      expect(billing.calls, isEmpty);
      await container
          .read(activeSessionProvider.notifier)
          .retryAiClassification(seeded.findingId);
      await _settle();

      expect(billing.calls.single.idempotencyKey, 'unknown_outcome_key');
    });

    test('11. recovery never duplicates the finding, its evidence, or its '
        'suggestion', () async {
      final seeded = await _seedFinding(repo);
      await repo.beginFindingAiAttempt(
        seeded.sessionId,
        seeded.findingId,
        _attempt('original_key', age: _stale),
      );
      final billing = ScriptedBillingService();

      final container = await _reopen(repo, billing, seeded.sessionId);
      await container
          .read(activeSessionProvider.notifier)
          .resume(seeded.sessionId);
      await _settle();

      final session = (await repo.loadSession(seeded.sessionId))!;
      expect(session.findings, hasLength(1));
      expect(session.findings.single.evidence, hasLength(1));
      expect(session.aiSuggestions, hasLength(1));
    });
  });

  group('connection loss', () {
    test('12 + 13. offline: the interrupted finding stays saved and shows as '
        'waiting; when the connection returns it replays the same key and '
        'completes', () async {
      final seeded = await _seedFinding(repo);
      await repo.beginFindingAiAttempt(
        seeded.sessionId,
        seeded.findingId,
        _attempt('original_key', age: _stale),
      );
      final billing = ScriptedBillingService();
      final connectivity = FakeConnectivityService(
        initial: ConnectivityStatus.offline,
      );
      addTearDown(connectivity.dispose);
      final container = ProviderContainer(
        overrides: testOverridesWithSync(
          repository: repo,
          billingService: billing,
          connectivityService: connectivity,
          authService: FakeAuthService(initialUser: testAuthUser),
          cloudRepository: FakeCloudInspectionRepository(),
        ),
      );
      addTearDown(container.dispose);
      final notifier = container.read(activeSessionProvider.notifier);
      container.listen(connectivityStatusProvider, (_, _) {});
      await _settle();

      await notifier.resume(seeded.sessionId);
      await _settle();

      expect(billing.calls, isEmpty);
      final offline = await _storedFinding(repo, seeded);
      expect(offline.aiStatus, AiFindingStatus.queued);
      expect(offline.aiAttempt?.idempotencyKey, 'original_key');
      expect(offline.evidence, hasLength(1));

      connectivity.setStatus(ConnectivityStatus.online);
      await _settle();

      expect(billing.calls.single.idempotencyKey, 'original_key');
      final recovered = await _storedFinding(repo, seeded);
      expect(recovered.aiStatus, AiFindingStatus.completed);
      expect(recovered.aiAttempt, isNull);
    });

    test('several interrupted findings recovered together all complete — '
        'none is parked behind the single-sync-per-session guard', () async {
      final seeded = await _seedFinding(repo);
      // Two more findings in the same session.
      final setup = ProviderContainer(
        overrides: testOverrides(repository: repo),
      );
      await setup.read(activeSessionProvider.notifier).resume(seeded.sessionId);
      final setupNotifier = setup.read(activeSessionProvider.notifier);
      final ids = [seeded.findingId];
      for (var i = 0; i < 2; i++) {
        final photo = await setupNotifier.captureFindingPhoto(
          source: EvidenceSource.camera,
        );
        ids.add(
          setupNotifier
              .saveCameraFinding(
                sectionId: seeded.sectionId,
                photo: photo!,
                note: 'Finding $i',
              )
              .id,
        );
      }
      await _settle();
      setup.dispose();
      for (final id in ids) {
        await repo.setFindingAiStatus(
          seeded.sessionId,
          id,
          AiFindingStatus.uploading,
        );
      }

      final billing = ScriptedBillingService();
      final container = ProviderContainer(
        overrides: testOverridesWithSync(
          repository: repo,
          billingService: billing,
          authService: FakeAuthService(initialUser: testAuthUser),
          cloudRepository: FakeCloudInspectionRepository(),
        ),
      );
      addTearDown(container.dispose);
      await container
          .read(activeSessionProvider.notifier)
          .resume(seeded.sessionId);
      await _settle();

      expect(billing.calls, hasLength(3));
      final session = (await repo.loadSession(seeded.sessionId))!;
      expect(
        session.findings.map((f) => f.aiStatus),
        everyElement(AiFindingStatus.completed),
      );
    });
  });

  group('coordinator replay window', () {
    test('a replay inside the window is deferred without sending; after it, '
        'the same key is sent', () async {
      final seeded = await _seedFinding(repo);
      final submittedAt = DateTime(2026, 9, 24, 10);
      await repo.beginFindingAiAttempt(
        seeded.sessionId,
        seeded.findingId,
        AiAnalysisAttempt(
          idempotencyKey: 'windowed_key',
          aiLevel: AiLevel.smart,
          submittedAt: submittedAt,
        ),
      );
      final billing = ScriptedBillingService();
      var now = submittedAt.add(const Duration(minutes: 1));
      final coordinator = PricedAiClassificationCoordinator(
        localRepository: repo,
        billingService: billing,
        clock: () => now,
      );

      final early = await coordinator.classifyFinding(
        seeded.sessionId,
        seeded.findingId,
      );
      expect(early.outcome, AiClassificationOutcome.deferred);
      expect(early.retryAt, submittedAt.add(AiAnalysisAttempt.replaySafeAfter));
      expect(billing.calls, isEmpty);

      now = submittedAt.add(const Duration(minutes: 5));
      final late = await coordinator.classifyFinding(
        seeded.sessionId,
        seeded.findingId,
      );
      expect(late.isSuccess, isTrue);
      expect(billing.calls.single.idempotencyKey, 'windowed_key');
    });

    test(
      'the attempt is durably persisted before the request is sent',
      () async {
        final seeded = await _seedFinding(repo);
        await repo.setFindingAiStatus(
          seeded.sessionId,
          seeded.findingId,
          AiFindingStatus.queued,
        );
        final billing = ScriptedBillingService()..gate = Completer<void>();
        final coordinator = PricedAiClassificationCoordinator(
          localRepository: repo,
          billingService: billing,
        );

        final pending = coordinator.classifyFinding(
          seeded.sessionId,
          seeded.findingId,
        );
        await _settle();

        // The request is in flight: an app kill right now must still find
        // the key on disk.
        final midFlight = await _storedFinding(repo, seeded);
        expect(midFlight.aiStatus, AiFindingStatus.analyzing);
        expect(
          midFlight.aiAttempt?.idempotencyKey,
          billing.calls.single.idempotencyKey,
        );

        billing.gate!.complete();
        await pending;
      },
    );
  });

  test('outcome classification: only backend-originated rejections are '
      'definitive', () {
    for (final code in [
      'invalid-argument',
      'permission-denied',
      'unauthenticated',
      'failed-precondition',
      'internal',
    ]) {
      expect(analyseFindingOutcomeUnknownForCode(code), isFalse, reason: code);
    }
    for (final code in [
      'deadline-exceeded',
      'unavailable',
      'cancelled',
      'unknown',
      'aborted',
    ]) {
      expect(analyseFindingOutcomeUnknownForCode(code), isTrue, reason: code);
    }
  });

  group('14. connectivity wording', () {
    Future<void> pumpQueuedFinding(
      WidgetTester tester, {
      required ConnectivityStatus connectivity,
    }) async {
      late _Seeded seeded;
      late ProviderContainer container;
      await tester.runAsync(() async {
        seeded = await _seedFinding(repo);
        await repo.setFindingAiStatus(
          seeded.sessionId,
          seeded.findingId,
          AiFindingStatus.queued,
        );
        final cloud = FakeCloudInspectionRepository()
          // Online, but the evidence upload fails once: the finding is
          // back in `queued` purely because its upload is pending.
          ..failNextCallWith = Exception('transient upload failure');
        final connectivityService = FakeConnectivityService(
          initial: connectivity,
        );
        container = ProviderContainer(
          overrides: testOverridesWithSync(
            repository: repo,
            billingService: ScriptedBillingService(),
            connectivityService: connectivityService,
            authService: FakeAuthService(initialUser: testAuthUser),
            cloudRepository: cloud,
          ),
        );
        container.listen(connectivityStatusProvider, (_, _) {});
        await _settle();
        await container
            .read(activeSessionProvider.notifier)
            .resume(seeded.sessionId);
        await _settle();
      });
      addTearDown(container.dispose);
      expect(
        container.read(activeSessionProvider)!.findings.single.aiStatus,
        AiFindingStatus.queued,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: AreaInspectionScreen(sectionId: seeded.sectionId),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('online with a pending upload shows "Queued for AI", never '
        '"Waiting for connection"', (tester) async {
      await pumpQueuedFinding(tester, connectivity: ConnectivityStatus.online);

      expect(find.text('Queued for AI'), findsOneWidget);
      expect(find.text('Waiting for connection'), findsNothing);
    });

    testWidgets('genuinely offline shows "Waiting for connection"', (
      tester,
    ) async {
      await pumpQueuedFinding(tester, connectivity: ConnectivityStatus.offline);

      expect(find.text('Waiting for connection'), findsOneWidget);
      expect(find.text('Queued for AI'), findsNothing);
    });
  });
}
