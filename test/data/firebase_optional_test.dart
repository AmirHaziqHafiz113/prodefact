import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/local/database_providers.dart';
import 'package:prodefact/data/remote/remote_providers.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/home_inspection_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import '../support/fake_auth_service.dart';
import '../support/test_repository.dart';

/// Firebase optionality (Phase 8): the entire Home Inspection workflow —
/// start, configure, inspect, AI review, report — must work end to end
/// with Firebase completely unconfigured, and a previously-authenticated
/// session expiring/signing out must never touch local data. See
/// `docs/production_readiness.md` ("Firebase optionality").
void main() {
  test('the full inspection workflow works with Firebase left unconfigured '
      '(firebaseReadyProvider at its default false — no override)', () async {
    // testOverrides() deliberately never touches firebaseReadyProvider,
    // authServiceProvider, or cloudInspectionRepositoryProvider.
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    expect(container.read(firebaseReadyProvider), isFalse);

    await container
        .read(selectedPropertyTypeProvider.notifier)
        .select(PropertyType.highRise);
    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);
    final statusNotifier = container.read(sectionStatusesProvider.notifier);

    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: queue.first.id,
      photo: photo!,
      note: 'Cracked tile',
    );
    // AI classification (the fake, offline service — Firebase is
    // unconfigured) is fire-and-forget; give it a tick to complete.
    await Future<void>.delayed(Duration.zero);

    for (final s in queue) {
      statusNotifier.setStatus(s.id, SectionStatus.completed);
    }
    await notifier.markPhysicalInspectionComplete();

    final suggestion = container
        .read(activeSessionProvider)!
        .aiSuggestions
        .single;
    if (suggestion.needsReview) {
      notifier.changeSuggestion(
        suggestion.id,
        DefectCatalogue.instance.entries.first.id,
      );
    } else {
      notifier.acceptSuggestion(suggestion.id);
    }

    notifier.setReportMetadata(
      const ReportMetadata(
        title: 'Test Property',
        contactNumber: '+60123456789',
      ),
    );
    final result = await notifier.generateReport();

    expect(result.isSuccess, isTrue);
  });

  test('attempting to sync with Firebase unconfigured fails gracefully '
      'without losing local data', () async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    await container
        .read(selectedPropertyTypeProvider.notifier)
        .select(PropertyType.highRise);

    final result = await container
        .read(activeSessionProvider.notifier)
        .syncNow();

    expect(result.isSuccess, isFalse);
    // The session itself is completely unaffected.
    expect(container.read(activeSessionProvider), isNotNull);
  });

  test('signing out (simulating an expired session) never deletes or '
      'clears the local inspection data', () async {
    final auth = FakeAuthService(initialUser: testAuthUser);
    addTearDown(auth.dispose);
    final container = ProviderContainer(
      overrides: [...testOverridesWithSync(authService: auth)],
    );
    addTearDown(container.dispose);

    await container
        .read(selectedPropertyTypeProvider.notifier)
        .select(PropertyType.highRise);
    final sessionId = container.read(activeSessionProvider)!.id;
    final notifier = container.read(activeSessionProvider.notifier);
    final queue = container.read(inspectionQueueProvider);
    final photo = await notifier.captureFindingPhoto(
      source: EvidenceSource.camera,
    );
    notifier.saveCameraFinding(
      sectionId: queue.first.id,
      photo: photo!,
      note: 'Cracked tile',
    );
    // Owned by the signed-in user.
    expect(container.read(activeSessionProvider)!.ownerUid, testAuthUser.uid);

    // Simulate an expired/invalidated auth session.
    await auth.signOut();

    // The in-memory active session (and its finding) is untouched —
    // signing out is an auth-layer event, never a data-deletion event.
    final stillActive = container.read(activeSessionProvider)!;
    expect(stillActive.id, sessionId);
    expect(stillActive.findings, hasLength(1));

    // The session is still durably on disk too, fully intact.
    final repository = container.read(inspectionRepositoryProvider);
    final reloaded = await repository.loadSession(sessionId);
    expect(reloaded, isNotNull);
    expect(reloaded!.findings, hasLength(1));
    expect(reloaded.ownerUid, testAuthUser.uid);
  });
}
