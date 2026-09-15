import 'dart:async';

import 'package:prodefact/core/inspection/inspection_domain.dart';

/// In-memory [AuthService] fake — no Firebase involved. Lets tests drive
/// sign-in/out and observe [authStateChanges] deterministically.
class FakeAuthService implements AuthService {
  FakeAuthService({AuthUser? initialUser}) : _current = initialUser {
    _controller = StreamController<AuthUser?>.broadcast();
  }

  AuthUser? _current;
  late final StreamController<AuthUser?> _controller;

  /// Users "registered" via [signUpWithEmail], keyed by email, so
  /// [signInWithEmail] can validate credentials the way a real backend
  /// would (without actually implementing password hashing — this is a
  /// test double, not a security model).
  final Map<String, String> _passwordsByEmail = {};

  @override
  Stream<AuthUser?> authStateChanges() {
    return Stream.multi((controller) {
      controller.add(_current);
      final subscription = _controller.stream.listen(controller.add);
      controller.onCancel = subscription.cancel;
    });
  }

  @override
  AuthUser? get currentUser => _current;

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    final expected = _passwordsByEmail[email];
    if (expected == null || expected != password) {
      throw const AuthException('Invalid email or password.');
    }
    final user = AuthUser(uid: 'uid_$email', email: email);
    _current = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<AuthUser> signUpWithEmail(String email, String password) async {
    if (_passwordsByEmail.containsKey(email)) {
      throw const AuthException('An account already exists for that email.');
    }
    _passwordsByEmail[email] = password;
    final user = AuthUser(uid: 'uid_$email', email: email);
    _current = user;
    _controller.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
    _current = null;
    _controller.add(null);
  }

  void dispose() => _controller.close();
}
