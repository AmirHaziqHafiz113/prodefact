import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/core/inspection/inspection_domain.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/router/app_shell_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/profile_screen.dart';

import '../support/fake_auth_service.dart';
import '../support/test_repository.dart';

/// Profile's grouped-list pass (docs/prodefact_design_system.md §9/§20):
/// AI Preferences now shows a tier-specific supporting sentence instead
/// of a static generic subtitle, and Sign Out is a restrained outlined
/// button (never a large filled-red one) shown only when signed in.
void main() {
  Future<void> openProfile(
    WidgetTester tester,
    ProviderContainer container,
  ) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ProDefactApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Profile shows Smart AI as the fixed analysis level, with no '
    'Fast/Smart/Expert selector (QA #24)',
    (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      addTearDown(container.dispose);

      await openProfile(tester, container);
      expect(find.byType(ProfileScreen), findsOneWidget);

      expect(
        find.textContaining('Balanced speed and thoroughness'),
        findsOneWidget,
      );
      expect(find.byType(SegmentedButton<AiLevel>), findsNothing);
      expect(find.text('Fast'), findsNothing);
      expect(find.text('Expert'), findsNothing);
    },
  );

  testWidgets('Sign Out is not shown when not signed in', (tester) async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);

    // A tall surface so the lazily-built tail of the list is actually
    // mounted, matching the pattern other tests in this suite use.
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;

    await openProfile(tester, container);

    expect(find.widgetWithText(OutlinedButton, 'Sign Out'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Sign Out'), findsNothing);
  });

  testWidgets(
    'Sign Out is a restrained outlined button when signed in, not a large '
    'filled-red one',
    (tester) async {
      final container = ProviderContainer(
        overrides: testOverridesWithSync(
          authService: FakeAuthService(initialUser: testAuthUser),
        ),
      );
      addTearDown(container.dispose);

      // A tall surface so the lazily-built tail of the list (the
      // Divider + Sign Out button, below the fold on the default test
      // viewport) is actually mounted, matching the pattern other
      // tests in this suite use for the same reason.
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;

      await openProfile(tester, container);

      // Outlined, not filled — destructive action without excessive
      // red prominence (mission §5 "SIGN OUT").
      expect(find.widgetWithText(OutlinedButton, 'Sign Out'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Sign Out'), findsNothing);
    },
  );
}
