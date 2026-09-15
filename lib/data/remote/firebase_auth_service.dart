import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../core/inspection/entities/auth_user.dart';
import '../../core/inspection/services/auth_service.dart';

AuthUser? _toAuthUser(fb.User? user) {
  if (user == null) return null;
  return AuthUser(uid: user.uid, email: user.email);
}

/// [AuthService] backed by Firebase Authentication. This is the only
/// file that imports `package:firebase_auth` — everything else depends
/// on the [AuthService] interface.
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
      throw AuthException(e.message ?? 'Sign-in failed (${e.code}).');
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
      throw AuthException(e.message ?? 'Sign-up failed (${e.code}).');
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
