import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/ai/ai_providers.dart';
import 'package:prodefact/data/ai/fake_ai_inspection_service.dart';
import 'package:prodefact/data/remote/remote_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/fake_auth_service.dart';
import '../support/test_repository.dart';

/// Lets any fire-and-forget AI classification (or a queued
/// resume/reconnect chain) actually run before assertions. A real
/// (non-zero) delay, not just a microtask hop — settling a freshly
/// subscribed `StreamProvider`'s first buffered event, nested several
/// provider builds deep, needs more than one microtask turn.
Future<void> _pumpAiQueue() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  group('isOnlineForAiProvider', () {
    test('true in local-only mode regardless of connectivity', () {
      final container = ProviderContainer(
        overrides: [
          connectivityServiceProvider.overrideWithValue(
            FakeConnectivityService(initial: ConnectivityStatus.offline),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(isOnlineForAiProvider), isTrue);
    });

    test('false when Firebase is configured but signed out', () {
      final container = ProviderContainer(
        overrides: [
          firebaseReadyProvider.overrideWithValue(true),
          authServiceProvider.overrideWithValue(FakeAuthService()),
          connectivityServiceProvider.overrideWithValue(
            FakeConnectivityService(initial: ConnectivityStatus.online),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(isOnlineForAiProvider), isFalse);
    });

    test('false when signed in but device connectivity is offline', () async {
      final container = ProviderContainer(
        overrides: [
          firebaseReadyProvider.overrideWithValue(true),
          authServiceProvider.overrideWithValue(
            FakeAuthService(initialUser: testAuthUser),
          ),
          connectivityServiceProvider.overrideWithValue(
            FakeConnectivityService(initial: ConnectivityStatus.offline),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(authStateProvider, (_, _) {});
      container.listen(connectivityStatusProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(isOnlineForAiProvider), isFalse);
    });

    test('true when signed in and connectivity is online', () async {
      final container = ProviderContainer(
        overrides: [
          firebaseReadyProvider.overrideWithValue(true),
          authServiceProvider.overrideWithValue(
            FakeAuthService(initialUser: testAuthUser),
          ),
          connectivityServiceProvider.overrideWithValue(
            FakeConnectivityService(initial: ConnectivityStatus.online),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(authStateProvider, (_, _) {});
      container.listen(connectivityStatusProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(container.read(isOnlineForAiProvider), isTrue);
    });

    test('an unknown/not-yet-resolved connectivity reading (read before '
        'either stream has had a chance to emit) is treated as online '
        'rather than blocking work', () {
      final container = ProviderContainer(
        overrides: [
          firebaseReadyProvider.overrideWithValue(true),
          authServiceProvider.overrideWithValue(
            FakeAuthService(initialUser: testAuthUser),
          ),
          connectivityServiceProvider.overrideWithValue(
            FakeConnectivityService(),
          ),
        ],
      );
      addTearDown(container.dispose);
      // No `await` — neither the auth nor the connectivity stream has
      // had a chance to emit yet, so both providers are still
      // `AsyncLoading`. Falls back to the synchronous
      // `authServiceProvider.currentUser` getter for sign-in, and
      // treats a still-unresolved connectivity reading as online.
      expect(container.read(isOnlineForAiProvider), isTrue);
    });
  });

  group('offline save / reconnect resume', () {
    test('a finding saved while offline stays queued (AI is never even '
        'attempted, never shows analysing), and resumes automatically — '
        'exactly once — the moment connectivity returns', () async {
      final connectivity = FakeConnectivityService(
        initial: ConnectivityStatus.offline,
      );
      addTearDown(connectivity.dispose);
      final aiService = FakeAiInspectionService();
      final container = ProviderContainer(
        overrides: [
          ...testOverridesWithSync(
            authService: FakeAuthService(initialUser: testAuthUser),
            connectivityService: connectivity,
          ),
          aiInspectionServiceProvider.overrideWithValue(aiService),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      // Let the connectivity/auth streams deliver their first
      // buffered value before exercising the offline gate below.
      container.listen(connectivityStatusProvider, (_, _) {});
      container.listen(authStateProvider, (_, _) {});
      await _pumpAiQueue();
      final notifier = container.read(activeSessionProvider.notifier);
      final section = container.read(inspectionQueueProvider).first;

      final photo = await notifier.captureFindingPhoto(
        source: EvidenceSource.camera,
      );
      final finding = notifier.saveCameraFinding(
        sectionId: section.id,
        photo: photo!,
      );
      await _pumpAiQueue();

      // Offline: stays queued, never reaches uploading/analyzing.
      var current = container
          .read(activeSessionProvider)!
          .findings
          .firstWhere((f) => f.id == finding.id);
      expect(current.aiStatus, AiFindingStatus.queued);
      expect(container.read(activeSessionProvider)!.aiSuggestions, isEmpty);

      // Reconnect — the auto-resume listener should re-attempt this
      // finding without any explicit call from the test.
      connectivity.setStatus(ConnectivityStatus.online);
      await _pumpAiQueue();
      await _pumpAiQueue();

      current = container
          .read(activeSessionProvider)!
          .findings
          .firstWhere((f) => f.id == finding.id);
      expect(current.aiStatus, AiFindingStatus.completed);
      expect(
        container
            .read(activeSessionProvider)!
            .aiSuggestions
            .where((s) => s.findingId == finding.id),
        hasLength(1),
      );

      // A second, redundant reconnect signal (e.g. a flaky radio)
      // must not duplicate the classification or the finding.
      connectivity.setStatus(ConnectivityStatus.offline);
      connectivity.setStatus(ConnectivityStatus.online);
      await _pumpAiQueue();
      await _pumpAiQueue();

      final session = container.read(activeSessionProvider)!;
      expect(session.findings.where((f) => f.id == finding.id), hasLength(1));
      expect(
        session.aiSuggestions.where((s) => s.findingId == finding.id),
        hasLength(1),
      );
    });
  });
}
