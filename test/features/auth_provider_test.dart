import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/data/remote/remote_providers.dart';

import '../support/fake_auth_service.dart';

void main() {
  test('authStateProvider restores an already-signed-in user and reflects '
      'subsequent sign-out/sign-in', () async {
    final auth = FakeAuthService(initialUser: const AuthUser(uid: 'u1'));
    final container = ProviderContainer(
      overrides: [
        firebaseReadyProvider.overrideWithValue(true),
        authServiceProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(auth.dispose);

    final events = <AuthUser?>[];
    container.listen(authStateProvider, (previous, next) {
      if (next.hasValue) events.add(next.value);
    }, fireImmediately: true);
    await Future<void>.delayed(Duration.zero);

    // Restores existing auth state without requiring a fresh sign-in.
    expect(container.read(authStateProvider).value?.uid, 'u1');

    await auth.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authStateProvider).value, isNull);

    await auth.signUpWithEmail('new@example.com', 'password123');
    await Future<void>.delayed(Duration.zero);
    expect(container.read(authStateProvider).value?.email, 'new@example.com');

    expect(events.map((e) => e?.uid).toList(), [
      'u1',
      null,
      'uid_new@example.com',
    ]);
  });

  test('signing in with the wrong password throws an AuthException without '
      'changing auth state', () async {
    final auth = FakeAuthService();
    await auth.signUpWithEmail('a@example.com', 'correct-password');
    await auth.signOut();

    expect(
      () => auth.signInWithEmail('a@example.com', 'wrong-password'),
      throwsA(isA<AuthException>()),
    );
    expect(auth.currentUser, isNull);
    auth.dispose();
  });
}
