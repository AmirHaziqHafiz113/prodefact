import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/billing/fake_billing_service.dart';
import 'package:prodefact/data/local/database.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/data/local/drift_inspection_repository.dart';
import 'package:prodefact/data/remote/remote_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/fake_auth_service.dart';
import '../support/fake_cloud_inspection_repository.dart';
import '../support/test_repository.dart';

/// P0 queue reliability (real-device QA, 2026-10-02): findings stuck at
/// "Queued for AI", a report blocked by "AI review is not complete yet"
/// at 30/35 processed + 30/30 reviewed, deleted findings still in AI
/// Review. Every queued finding must reach a terminal state on its own,
/// findings drain independently, and readiness counts only real,
/// active, unresolved work.

/// A fake backend that can fail chosen findings, hold one open, and
/// counts every analysis (and Credits charged).
class _Backend extends FakeBillingService {
  _Backend() : super(initialBalanceCredits: 100000);

  final Set<String> failFindingIds = {};
  final Map<String, Completer<void>> holds = {};
  final List<String> analysed = [];
  final List<AiLevel> levels = [];

  @override
  Future<AnalyseFindingResult> analyseFinding({
    required AiFindingClassificationRequest request,
    required AiLevel aiLevel,
    required String idempotencyKey,
  }) async {
    final hold = holds[request.findingId];
    if (hold != null) await hold.future;
    if (failFindingIds.contains(request.findingId)) {
      throw Exception('provider failed');
    }
    analysed.add(request.findingId);
    levels.add(aiLevel);
    return super.analyseFinding(
      request: request,
      aiLevel: aiLevel,
      idempotencyKey: idempotencyKey,
    );
  }
}

/// Connectivity whose fresh check can disagree with its stream — the
/// real-device case where the app's signal says online but one check
/// reads offline.
class _SplitConnectivity extends FakeConnectivityService {
  ConnectivityStatus checked = ConnectivityStatus.offline;

  @override
  Future<ConnectivityStatus> checkStatus() async => checked;
}

Future<ProviderContainer> _start({
  _Backend? backend,
  InspectionRepository? repository,
  List<Override> extra = const [],
  bool sync = false,
  FakeAuthService? auth,
  ConnectivityService? connectivity,
}) async {
  final container = ProviderContainer(
    overrides: [
      ...(sync
          ? testOverridesWithSync(
              billingService: backend ?? _Backend(),
              authService: auth ?? FakeAuthService(initialUser: testAuthUser),
              cloudRepository: FakeCloudInspectionRepository(),
              connectivityService: connectivity,
            )
          : testOverrides(
              billingService: backend ?? _Backend(),
              repository: repository,
            )),
      ...extra,
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(activeSessionProvider.notifier)
      .startNew(PropertyType.highRise);
  return container;
}

Future<List<Finding>> _saveMany(
  ProviderContainer container,
  int count, {
  String note = 'Hollow tile',
}) async {
  final notifier = container.read(activeSessionProvider.notifier);
  final section = container.read(inspectionQueueProvider).first.id;
  final saved = <Finding>[];
  for (var i = 0; i < count; i++) {
    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    saved.add(
      notifier.saveCameraFinding(
        sectionId: section,
        photo: photo!,
        note: '$note $i',
      ),
    );
  }
  return saved;
}

/// Waits (real time, bounded) until [done] holds.
Future<void> _until(
  bool Function() done, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!done()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('timed out waiting for the AI queue');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

InspectionSession _session(ProviderContainer c) =>
    c.read(activeSessionProvider)!;

bool _allTerminal(ProviderContainer c) =>
    _session(c).findings.every((f) => !aiFindingStatusIsInFlight(f.aiStatus));

Future<void> _completeAndAddContact(ProviderContainer container) async {
  final notifier = container.read(activeSessionProvider.notifier);
  await notifier.markPhysicalInspectionComplete();
  notifier.setReportMetadata(
    const ReportMetadata(title: 'Unit A-12-3', contactNumber: '012-3456789'),
  );
  await Future<void>.delayed(const Duration(milliseconds: 30));
}

void main() {
  group('queue drains by itself', () {
    test('26 + 34. a saved finding leaves "queued" on its own and the '
        'result reaches the app state', () async {
      final container = await _start();
      final finding = (await _saveMany(container, 1)).single;
      expect(finding.aiStatus, AiFindingStatus.queued);
      await _until(() => _allTerminal(container));
      expect(
        _session(container).findings.single.aiStatus,
        AiFindingStatus.completed,
      );
      expect(_session(container).aiSuggestions.single.findingId, finding.id);
    });

    test('31 + 47. 35 findings drain independently to 35/35 processed, '
        'and the report can be generated', () async {
      final backend = _Backend();
      final container = await _start(backend: backend);
      await _saveMany(container, 35);
      await _until(() => _allTerminal(container));

      final processing = AiProcessingProgress.of(_session(container));
      expect(processing.processed, 35);
      expect(processing.totalEligible, 35);
      expect(backend.analysed.toSet(), hasLength(35));
      expect(ReportReadiness.of(_session(container)).isReady, isTrue);

      await _completeAndAddContact(container);
      final result = await container
          .read(activeSessionProvider.notifier)
          .generateReport();
      expect(result.outcome, ReportGenerationOutcome.success);
    });

    test('28 + 32. a provider failure becomes "failed" (Retry offered) and '
        'never blocks its siblings', () async {
      final backend = _Backend();
      final container = await _start(backend: backend);
      final notifier = container.read(activeSessionProvider.notifier);
      final section = container.read(inspectionQueueProvider).first.id;
      final photos = [
        for (var i = 0; i < 4; i++)
          (await notifier.captureFindingPhoto(source: EvidenceSource.camera))!,
      ];
      backend.failFindingIds.add(photos[1].pendingFindingId);
      for (final (i, photo) in photos.indexed) {
        notifier.saveCameraFinding(
          sectionId: section,
          photo: photo,
          note: 'Crack $i',
        );
      }
      await _until(() => _allTerminal(container));

      final byId = {for (final f in _session(container).findings) f.id: f};
      expect(
        byId[photos[1].pendingFindingId]!.aiStatus,
        AiFindingStatus.failed,
      );
      for (final i in [0, 2, 3]) {
        expect(
          byId[photos[i].pendingFindingId]!.aiStatus,
          AiFindingStatus.completed,
        );
      }
    });

    test('39 + 45. a failed finding is reported as needing Retry or '
        'Classify Manually — never as queued — and blocks the report until '
        'handled', () async {
      final backend = _Backend();
      final container = await _start(backend: backend);
      final notifier = container.read(activeSessionProvider.notifier);
      final section = container.read(inspectionQueueProvider).first.id;
      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      backend.failFindingIds.add(photo!.pendingFindingId);
      notifier.saveCameraFinding(
        sectionId: section,
        photo: photo,
        note: 'Crack',
      );
      await _until(() => _allTerminal(container));

      final finding = _session(container).findings.single;
      expect(finding.aiStatus, AiFindingStatus.failed);
      var readiness = ReportReadiness.of(_session(container));
      expect(readiness.failed, 1);
      expect(readiness.analysing, 0);
      expect(readiness.summary, contains('Retry or Classify Manually'));

      backend.failFindingIds.clear();
      await notifier.retryAiClassification(finding.id);
      await _until(() => _allTerminal(container));
      expect(
        _session(container).findings.single.aiStatus,
        AiFindingStatus.completed,
      );
      readiness = ReportReadiness.of(_session(container));
      expect(readiness.isReady, isTrue);
    });

    test('29. a finding left queued by a killed app is analysed on resume, '
        'with no user action', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final repository = DriftInspectionRepository(db);
      final backend = _Backend();
      final container = await _start(backend: backend, repository: repository);
      final sessionId = _session(container).id;
      final now = DateTime(2026, 10, 1);
      await repository.saveFinding(
        sessionId,
        Finding(
          id: 'finding_restart',
          sectionId: _session(container).sections.first.id,
          description: 'Leaking tap',
          createdAt: now,
          updatedAt: now,
          aiStatus: AiFindingStatus.queued,
        ),
      );
      await repository.addEvidence(
        sessionId,
        Evidence(
          id: 'evidence_restart',
          findingId: 'finding_restart',
          filePath: '/fake/restart.jpg',
          createdAt: now,
        ),
      );

      // "Restart": a fresh resume of the stored session.
      await container.read(activeSessionProvider.notifier).resume(sessionId);
      await _until(() => _allTerminal(container));
      expect(
        _session(container).findings.single.aiStatus,
        AiFindingStatus.completed,
      );
      expect(backend.analysed, ['finding_restart']);
    });

    test('35 + 48. a Fast-level inspection drains completely and can '
        'generate its report', () async {
      final backend = _Backend();
      final container = await _start(backend: backend);
      await container
          .read(inspectionRepositoryProvider)
          .saveUserProfile(const UserProfile(defaultAiLevel: AiLevel.fast));
      await _saveMany(container, 12);
      await _until(() => _allTerminal(container));

      expect(backend.levels, everyElement(AiLevel.fast));
      expect(AiProcessingProgress.of(_session(container)).processed, 12);
      await _completeAndAddContact(container);
      final result = await container
          .read(activeSessionProvider.notifier)
          .generateReport();
      expect(result.outcome, ReportGenerationOutcome.success);
    });
  });

  group('parked findings never wait on an external event', () {
    test('a finding parked while Firebase Auth is still restoring the user '
        '(signed out) is analysed as soon as sign-in completes', () async {
      final auth = FakeAuthService();
      final backend = _Backend();
      final container = await _start(sync: true, backend: backend, auth: auth);
      final finding = (await _saveMany(container, 1)).single;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        _session(container).findings.single.aiStatus,
        AiFindingStatus.queued,
      );
      expect(backend.analysed, isEmpty);

      await auth.signUpWithEmail('inspector@example.com', 'secret1');
      await _until(() => _allTerminal(container));
      expect(
        _session(container).findings.single.aiStatus,
        AiFindingStatus.completed,
      );
      expect(backend.analysed, [finding.id]);
    });

    test('30 + 37. a conflicting "offline" reading while the app is online '
        'is tried anyway after a bounded number of re-checks', () async {
      final connectivity = _SplitConnectivity();
      final backend = _Backend();
      final container = await _start(
        sync: true,
        backend: backend,
        connectivity: connectivity,
      );
      // Let the connectivity/auth streams deliver their first value.
      container.listen(connectivityStatusProvider, (_, _) {});
      container.listen(authStateProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      await _saveMany(container, 1);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(backend.analysed, isEmpty, reason: 'first reading: parked');

      // Each drain (watchdog tick / recovery trigger) re-checks; the
      // check keeps saying offline while the app's signal says online.
      final notifier = container.read(activeSessionProvider.notifier);
      for (var i = 0; i < 3 && backend.analysed.isEmpty; i++) {
        await notifier.processQueuedAiClassifications();
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await _until(() => _allTerminal(container));
      expect(backend.analysed, hasLength(1));
      expect(
        _session(container).findings.single.aiStatus,
        AiFindingStatus.completed,
      );
    });

    test('19. queue diagnostics hold safe facts per finding (status, level, '
        'retries) and never a note', () async {
      final auth = FakeAuthService();
      final container = await _start(sync: true, auth: auth);
      await _saveMany(container, 1, note: 'SECRET note text');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final rows = container
          .read(activeSessionProvider.notifier)
          .aiQueueDiagnostics();
      expect(rows, hasLength(1));
      expect(rows.single.aiStatus, AiFindingStatus.queued);
      expect(rows.single.retryCount, greaterThanOrEqualTo(1));
      expect(rows.single.lastErrorCode, 'signedOut');
      expect(rows.single.toLogString(), isNot(contains('SECRET')));
    });
  });

  group('deleted findings disappear everywhere', () {
    test('40 + 41 + 43. deleting a finding removes it — and its suggestion — '
        'from AI Review counts and report readiness', () async {
      final container = await _start();
      final findings = await _saveMany(container, 3);
      await _until(() => _allTerminal(container));
      expect(AiReviewProgress.of(_session(container)).total, 3);

      container
          .read(activeSessionProvider.notifier)
          .removeFinding(findings[1].id);
      final session = _session(container);
      expect(
        session.findings.map((f) => f.id),
        isNot(contains(findings[1].id)),
      );
      expect(
        session.aiSuggestions.map((s) => s.findingId),
        isNot(contains(findings[1].id)),
      );
      expect(AiReviewProgress.of(session).total, 2);
      expect(AiProcessingProgress.of(session).totalEligible, 2);
      expect(ReportReadiness.of(session).isReady, isTrue);
    });

    test('a finding deleted while its analysis is in flight never comes '
        'back when the late result arrives', () async {
      final backend = _Backend();
      final container = await _start(backend: backend);
      final notifier = container.read(activeSessionProvider.notifier);
      final section = container.read(inspectionQueueProvider).first.id;
      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      final hold = Completer<void>();
      backend.holds[photo!.pendingFindingId] = hold;
      final finding = notifier.saveCameraFinding(
        sectionId: section,
        photo: photo,
        note: 'Crack',
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      notifier.removeFinding(finding.id);
      hold.complete();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      final session = _session(container);
      expect(session.findings, isEmpty);
      expect(session.aiSuggestions, isEmpty);
      final stored = await container
          .read(inspectionRepositoryProvider)
          .loadSession(session.id);
      expect(stored!.findings, isEmpty);
      expect(stored.aiSuggestions, isEmpty);
    });

    test('42 + 44. an orphan suggestion (its finding gone) or stale queue '
        'state never counts toward review or readiness', () {
      final now = DateTime(2026, 10, 2);
      final finding = Finding(
        id: 'f1',
        sectionId: 's1',
        createdAt: now,
        updatedAt: now,
        description: 'Crack',
        aiStatus: AiFindingStatus.completed,
        evidence: [
          Evidence(id: 'e1', findingId: 'f1', filePath: '/x', createdAt: now),
        ],
      );
      AiSuggestion suggestion(String findingId, AiSuggestionStatus status) =>
          AiSuggestion(
            id: 'suggestion_$findingId',
            sessionId: 'session',
            findingId: findingId,
            providerId: 'ai',
            generatedAt: now,
            status: status,
          );
      final session = InspectionSession(
        id: 'session',
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        sections: const [],
        sectionStatuses: const {},
        findings: [finding],
        createdAt: now,
        updatedAt: now,
        aiSuggestions: [
          suggestion('f1', AiSuggestionStatus.accepted),
          // Orphans: deleted findings, one still "pending".
          suggestion('gone_1', AiSuggestionStatus.pending),
          suggestion('gone_2', AiSuggestionStatus.accepted),
        ],
      );
      expect(AiReviewProgress.of(session).total, 1);
      expect(AiReviewProgress.of(session).pending, 0);
      expect(ReportReadiness.of(session).isReady, isTrue);
    });
  });

  group('report readiness rule', () {
    InspectionSession sessionWith(
      List<Finding> findings, [
      List<AiSuggestion> suggestions = const [],
    ]) {
      final now = DateTime(2026, 10, 2);
      return InspectionSession(
        id: 's',
        industry: Industry.homeInspection,
        assetTypeId: 'highRise',
        sections: const [],
        sectionStatuses: const {},
        findings: findings,
        aiSuggestions: suggestions,
        createdAt: now,
        updatedAt: now,
      );
    }

    Finding f(String id, AiFindingStatus status, {String? note = 'x'}) {
      final now = DateTime(2026, 10, 2);
      return Finding(
        id: id,
        sectionId: 's1',
        description: note,
        createdAt: now,
        updatedAt: now,
        aiStatus: status,
        evidence: [
          Evidence(id: 'e_$id', findingId: id, filePath: '/x', createdAt: now),
        ],
      );
    }

    test('45. each kind of unresolved active finding blocks, under its own '
        'reason', () {
      final r = ReportReadiness.of(
        sessionWith(
          [
            f('a', AiFindingStatus.queued),
            f('b', AiFindingStatus.analyzing),
            f('c', AiFindingStatus.awaitingApproval, note: null),
            f('d', AiFindingStatus.failed),
            f('e', AiFindingStatus.needsReview),
          ],
          [
            AiSuggestion(
              id: 'se',
              sessionId: 's',
              findingId: 'e',
              providerId: 'ai',
              generatedAt: DateTime(2026),
            ),
          ],
        ),
      );
      expect(r.analysing, 2);
      expect(r.waitingForNote, 1);
      expect(r.failed, 1);
      expect(r.toReview, 1);
      expect(r.isReady, isFalse);
    });

    test('46. every active finding terminal and resolved (auto-accepted, '
        'reviewed, or manually classified after a failure) is ready', () {
      AiSuggestion s(String id, AiSuggestionStatus status) => AiSuggestion(
        id: 's_$id',
        sessionId: 's',
        findingId: id,
        providerId: 'ai',
        generatedAt: DateTime(2026),
        status: status,
        finalCatalogueEntryId: 'x',
      );
      final r = ReportReadiness.of(
        sessionWith(
          [
            f('a', AiFindingStatus.completed),
            f('b', AiFindingStatus.needsReview),
            f('c', AiFindingStatus.failed),
          ],
          [
            s('a', AiSuggestionStatus.accepted),
            s('b', AiSuggestionStatus.edited),
            s('c', AiSuggestionStatus.edited),
          ],
        ),
      );
      expect(r.isReady, isTrue);
      expect(r.summary, isNull);
    });
  });
}
