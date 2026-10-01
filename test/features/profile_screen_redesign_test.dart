import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
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

  testWidgets('1 + 2. Profile offers the AI Analysis Preference with Fast, '
      'Smart and Expert, and Smart is selected when nothing is saved', (
    tester,
  ) async {
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;

    await openProfile(tester, container);
    expect(find.byType(ProfileScreen), findsOneWidget);

    expect(find.text('AI Analysis Preference'), findsOneWidget);
    expect(find.text('Fastest and lowest cost'), findsOneWidget);
    expect(find.text('Recommended · Default'), findsOneWidget);
    expect(
      find.text('Best for difficult or unclear defects'),
      findsOneWidget,
    );
    ListTile tile(AiLevel level) =>
        tester.widget<ListTile>(find.byKey(ValueKey('ai-pref-${level.name}')));
    expect(tile(AiLevel.smart).selected, isTrue);
    expect(tile(AiLevel.fast).selected, isFalse);
    expect(tile(AiLevel.expert).selected, isFalse);
  });

  testWidgets('a QA build identifier shows the real platform version and build '
      'number, and the build stamp (never a hard-coded value)', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'ProDefact',
      packageName: 'com.prodefact.app',
      version: '0.1.0',
      buildNumber: '42',
      buildSignature: '',
    );
    final container = ProviderContainer(overrides: testOverrides());
    addTearDown(container.dispose);
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;

    await openProfile(tester, container);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('qa-build-identifier')), findsOneWidget);
    expect(find.text('ProDefact QA'), findsOneWidget);
    expect(find.text('Version: 0.1.0 (42)'), findsOneWidget);
    // Tests run without --dart-define=GIT_SHA, so the build says so
    // rather than showing a stale commit.
    expect(find.text('Build: not stamped'), findsOneWidget);
  });

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
