import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inspection/inspection_domain.dart';
import '../local/database_providers.dart';
import '../sync/default_sync_coordinator.dart';
import 'connectivity_plus_service.dart';
import 'firebase_auth_service.dart';
import 'firestore_cloud_inspection_repository.dart';

/// Whether Firebase finished initializing successfully. `main.dart`
/// overrides this after attempting `Firebase.initializeApp` — false
/// (the default here) means "not configured" or "init failed", in
/// which case the app runs in local-only mode: every provider below
/// falls back to a stub that reports "signed out"/"unavailable" instead
/// of throwing, so nothing in the UI has to special-case a missing
/// Firebase project.
final firebaseReadyProvider = Provider<bool>((ref) => false);

final authServiceProvider = Provider<AuthService>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return const _UnavailableAuthService();
  return FirebaseAuthService();
});

/// The signed-in user, or null — restores auth state across app
/// restarts by listening to the underlying auth stream from the moment
/// this provider is first watched.
final authStateProvider = StreamProvider<AuthUser?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

final cloudInspectionRepositoryProvider = Provider<CloudInspectionRepository>((
  ref,
) {
  if (!ref.watch(firebaseReadyProvider)) {
    return const _UnavailableCloudInspectionRepository();
  }
  return FirestoreCloudInspectionRepository();
});

/// Real device connectivity — see `ConnectivityService`'s doc comment
/// for why "online" doesn't guarantee working internet access. Tests
/// override this provider with a fake instead of driving real platform
/// connectivity events.
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityPlusService();
});

/// The device's current connectivity status, updated live. Callers that
/// need a value before the first stream event (e.g. on cold start)
/// should prefer `isOnlineForAiProvider`, which already accounts for
/// that — `.value` is null until this resolves once.
final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  final service = ref.watch(connectivityServiceProvider);
  return service.statusChanges();
});

/// Whether progressive AI classification can proceed right now — the
/// signal `AiCardSummary`/the classification queue use to distinguish
/// "actively analysing" from "waiting for connection". True whenever
/// Firebase isn't configured at all (local-only/demo mode always works
/// offline via the fake AI service); otherwise requires both being
/// signed in **and** the device not being definitively offline
/// (`ConnectivityStatus.offline`) — an `unknown`/not-yet-resolved
/// reading is treated as online rather than blocking work on an
/// ambiguous signal. This still isn't a guarantee the network call
/// will actually succeed (see `ConnectivityService`) — a queued finding
/// safely stays queued if the real request fails anyway, never lost or
/// duplicated; see `docs/production_readiness.md` ("Known
/// limitations").
final isOnlineForAiProvider = Provider<bool>((ref) {
  if (!ref.watch(firebaseReadyProvider)) return true;
  // Watches the stream (not just `authServiceProvider.currentUser`) so
  // a dependent that watches this provider reactively still rebuilds on
  // sign-in/out. But the stream can still be `AsyncLoading` (`.value`
  // null) for one microtask right after container/notifier creation —
  // e.g. exactly when a finding is saved and queued in the same tick a
  // session starts — in which case fall back to the always-current,
  // synchronous getter rather than misreading "not yet resolved" as
  // "signed out".
  final authState = ref.watch(authStateProvider);
  final signedIn = authState.hasValue
      ? authState.value != null
      : ref.watch(authServiceProvider).currentUser != null;
  if (!signedIn) return false;
  final connectivity = ref.watch(connectivityStatusProvider).value;
  return connectivity != ConnectivityStatus.offline;
});

final syncCoordinatorProvider = Provider<SyncCoordinator>((ref) {
  return DefaultSyncCoordinator(
    localRepository: ref.watch(inspectionRepositoryProvider),
    cloudRepository: ref.watch(cloudInspectionRepositoryProvider),
    authService: ref.watch(authServiceProvider),
  );
});

const _unconfiguredMessage =
    'Cloud sync isn\'t configured for this build yet — see docs/firebase.md.';

class _UnavailableAuthService implements AuthService {
  const _UnavailableAuthService();

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(null);

  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> signInWithEmail(String email, String password) {
    throw const AuthException(_unconfiguredMessage);
  }

  @override
  Future<AuthUser> signUpWithEmail(String email, String password) {
    throw const AuthException(_unconfiguredMessage);
  }

  @override
  Future<void> resetPassword(String email) {
    throw const AuthException(_unconfiguredMessage);
  }

  @override
  Future<void> signOut() async {}
}

class _UnavailableCloudInspectionRepository
    implements CloudInspectionRepository {
  const _UnavailableCloudInspectionRepository();

  Never _unavailable() => throw StateError(_unconfiguredMessage);

  @override
  Future<void> pushSession(String ownerUid, InspectionSession session) =>
      _unavailable();

  @override
  Future<void> pushSections(
    String ownerUid,
    String sessionId,
    List<Section> sections,
  ) => _unavailable();

  @override
  Future<void> pushFinding(
    String ownerUid,
    String sessionId,
    Finding finding,
  ) => _unavailable();

  @override
  Future<void> deleteFinding(
    String ownerUid,
    String sessionId,
    String findingId,
  ) => _unavailable();

  @override
  Future<String> uploadEvidenceFile(
    String ownerUid,
    String sessionId,
    Evidence evidence,
  ) => _unavailable();

  @override
  Future<void> pushEvidenceMetadata(
    String ownerUid,
    String sessionId,
    Evidence evidence,
  ) => _unavailable();

  @override
  Future<void> deleteEvidence(
    String ownerUid,
    String sessionId,
    String findingId,
    String evidenceId,
  ) => _unavailable();

  @override
  Future<void> pushAiSuggestion(
    String ownerUid,
    String sessionId,
    AiSuggestion suggestion,
  ) => _unavailable();

  @override
  Future<void> pushReportMetadata(
    String ownerUid,
    String sessionId,
    Report report,
  ) => _unavailable();
}
