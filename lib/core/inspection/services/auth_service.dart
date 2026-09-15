import '../entities/auth_user.dart';

/// Thrown for any sign-in/sign-up failure, carrying a message safe to
/// show to the inspector (never a raw Firebase exception).
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Minimal authentication surface the app depends on. A Firebase-backed
/// implementation lives in the data layer; nothing outside it touches
/// `firebase_auth` directly.
abstract class AuthService {
  /// Emits the current user (or null) immediately on listen, then again
  /// whenever sign-in state changes — this is what restores auth state
  /// across app restarts.
  Stream<AuthUser?> authStateChanges();

  AuthUser? get currentUser;

  Future<AuthUser> signInWithEmail(String email, String password);

  Future<AuthUser> signUpWithEmail(String email, String password);

  Future<void> signOut();
}
