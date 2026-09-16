import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/data/remote/remote_providers.dart';
import 'package:prodefact/features/auth/presentation/sign_in_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/inspection_sessions_screen.dart';

import '../support/fake_auth_service.dart';
import '../support/test_repository.dart';

Finder _within(Finder matching) =>
    find.descendant(of: find.byType(Scaffold).last, matching: matching);

void main() {
  testWidgets(
    'an unauthenticated caller is redirected to Sign In instead of ever '
    'reaching the dashboard, once Firebase is actually configured',
    (tester) async {
      final auth = FakeAuthService(); // signed out
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [
          ...testOverrides(),
          firebaseReadyProvider.overrideWithValue(true),
          authServiceProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ProDefactApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_within(find.text('Start Home Inspection')));
      await tester.pumpAndSettle();

      // Redirected to Sign In — the dashboard never actually builds.
      expect(find.byType(InspectionSessionsScreen), findsNothing);
      expect(find.text('Sign in'), findsWidgets);
    },
  );

  testWidgets(
    'a signed-in inspector reaches the dashboard normally, and is bounced '
    'away from Sign In back to it',
    (tester) async {
      final auth = FakeAuthService(initialUser: testAuthUser);
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [
          ...testOverrides(),
          firebaseReadyProvider.overrideWithValue(true),
          authServiceProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ProDefactApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(_within(find.text('Start Home Inspection')));
      await tester.pumpAndSettle();
      expect(find.byType(InspectionSessionsScreen), findsOneWidget);

      // Manually navigating to Sign In while already signed in bounces
      // straight back to the dashboard rather than showing the form.
      final context = tester.element(find.byType(InspectionSessionsScreen));
      GoRouter.of(context).push(SignInScreen.routePath);
      await tester.pumpAndSettle();

      expect(find.byType(SignInScreen), findsNothing);
      expect(find.byType(InspectionSessionsScreen), findsOneWidget);
    },
  );

  testWidgets('in local-only mode (Firebase not configured), the dashboard is '
      'reachable without any authentication at all — offline-first is '
      'unaffected by the hard gate', (tester) async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    expect(container.read(firebaseReadyProvider), isFalse);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ProDefactApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_within(find.text('Start Home Inspection')));
    await tester.pumpAndSettle();

    expect(find.byType(InspectionSessionsScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });
}
