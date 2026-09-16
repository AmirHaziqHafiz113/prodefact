import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';

import '../../core/inspection/entities/auth_user.dart';
import '../../core/inspection/services/auth_service.dart';

AuthUser? _toAuthUser(fb.User? user) {
  if (user == null) return null;
  return AuthUser(uid: user.uid, email: user.email);
}

/// Maps a [fb.FirebaseAuthException.code] to a clear, user-facing
/// message — never the SDK's own raw `message`, which for several
/// distinct underlying causes (wrong password, no such account, an
/// expired/malformed credential) is literally the same generic string,
/// *"The supplied auth credential is malformed or has expired."* —
/// because recent Firebase Auth versions deliberately collapse those
/// cases into one `invalid-credential` code (an anti account-
/// enumeration measure: the server intentionally will not tell a
/// client which of "wrong password" or "no such account" occurred).
/// Passing that sentence straight through to the sign-in screen (the
/// previous behavior) reads as a broken/expired app rather than what
/// it actually means: double-check the email and password. See
/// `docs/production_readiness.md` ("Firebase Auth error mapping") for
/// the full investigation this was written from.
@visibleForTesting
String friendlyMessageForAuthError(String code) {
  switch (code) {
    case 'invalid-credential':
    case 'wrong-password':
    case 'user-not-found':
      return 'That email or password is incorrect. Please check both and '
          'try again.';
    case 'invalid-email':
      return 'That doesn\'t look like a valid email address.';
    case 'user-disabled':
      return 'This account has been disabled. Contact support for help.';
    case 'email-already-in-use':
      return 'An account already exists for that email. Try signing in '
          'instead.';
    case 'weak-password':
      return 'Please choose a stronger password (at least 6 characters).';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'network-request-failed':
      return 'Could not reach the server. Check your connection and try '
          'again.';
    case 'operation-not-allowed':
      return 'Email/password sign-in isn\'t enabled for this app yet.';
    default:
      return 'Sign-in failed. Please try again.';
  }
}

/// [AuthService] backed by Firebase Authentication. This is the only
/// file that imports `package:firebase_auth` — everything else depends
/// on the [AuthService] interface.
///
/// Note on session persistence: like any Firebase Auth app, a
/// successful sign-in is cached in the platform's secure storage (the
/// iOS Keychain, Android's encrypted preferences) — by design, that
/// storage **outlives app deletion/reinstall** on iOS in particular, so
/// a device that was previously signed in to ProDefact may still appear
/// signed in after a fresh install, with no code path in this app ever
/// having created that session. This is expected Firebase/platform
/// behavior, not anonymous or fabricated authentication — [signOut]
/// below clears it, giving a genuinely fresh state.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({fb.FirebaseAuth? auth})
    : _auth = auth ?? fb.FirebaseAuth.instance;

  final fb.FirebaseAuth _auth;

  @override
  Stream<AuthUser?> authStateChanges() =>
      _auth.authStateChanges().map(_toAuthUser);

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = _toAuthUser(credential.user);
      if (user == null) {
        throw const AuthException('Sign-in did not return a user.');
      }
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(friendlyMessageForAuthError(e.code));
    }
  }

  @override
  Future<AuthUser> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = _toAuthUser(credential.user);
      if (user == null) {
        throw const AuthException('Sign-up did not return a user.');
      }
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(friendlyMessageForAuthError(e.code));
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(friendlyMessageForAuthError(e.code));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
