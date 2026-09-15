import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/inspection/inspection_domain.dart';
import '../local/database_providers.dart';
import '../sync/default_sync_coordinator.dart';
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
}
