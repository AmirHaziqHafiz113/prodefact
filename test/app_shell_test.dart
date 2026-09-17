import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/router/app_shell_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/home_dashboard_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/inspection_sessions_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/profile_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/property_type_selection_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/wallet_screen.dart';

import 'support/test_repository.dart';

/// The bottom-navigation shell (Home/Inspections/+/Wallet/Profile) —
/// see `AppShellScreen`/`docs/commercial_model.md`. The Inspections tab
/// is still the app's landing screen (see `buildAppRouter`), so these
/// tests navigate to each of the other destinations explicitly.
void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: testOverrides(), child: const ProDefactApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the bottom nav bar shows all five destinations, and the '
      'Inspections tab is the initial landing screen', (tester) async {
    await pumpApp(tester);

    expect(find.byType(InspectionSessionsScreen), findsOneWidget);
    final bottomNav = find.byType(AppBottomNav);
    expect(bottomNav, findsOneWidget);
    Finder inNav(Finder matching) =>
        find.descendant(of: bottomNav, matching: matching);
    expect(inNav(find.text('Home')), findsOneWidget);
    expect(inNav(find.text('Inspections')), findsOneWidget);
    expect(inNav(find.text('Wallet')), findsOneWidget);
    expect(inNav(find.text('Profile')), findsOneWidget);
    // The "+" destination is icon-only (no visible label), matching
    // the reference mockups — asserted via its tooltip instead.
    expect(inNav(find.byTooltip('New Inspection')), findsOneWidget);
  });

  testWidgets('tapping Home switches to the Home tab, showing the real '
      'wallet balance and an empty-progress state with no inspections', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(HomeDashboardScreen), findsOneWidget);
    // FakeBillingService's default starting balance.
    expect(find.text('500 credits'), findsOneWidget);
    expect(find.text('No inspections yet'), findsOneWidget);
  });

  testWidgets('tapping Wallet switches to the Wallet tab and shows the '
      'real balance, Top Up action, and an empty activity feed', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Wallet'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(WalletScreen), findsOneWidget);
    expect(find.text('500 credits'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Top Up'), findsOneWidget);
    // The fake wallet always starts with a "Starting balance" entry —
    // never a fabricated empty state when there IS real history. Below
    // the fold on a small test viewport, so scroll to it first.
    await tester.scrollUntilVisible(
      find.text('Starting balance'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Starting balance'), findsOneWidget);
  });

  testWidgets('tapping Profile switches to the Profile tab', (tester) async {
    await pumpApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(AppBottomNav),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Local inspector'), findsOneWidget);
  });

  testWidgets('tapping the "+" destination pushes New Inspection, not a '
      'sixth tab', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byTooltip('New Inspection'));
    await tester.pumpAndSettle();

    expect(find.byType(PropertyTypeSelectionScreen), findsOneWidget);
    // The bottom nav is hidden during this focused setup flow.
    expect(find.byType(AppBottomNav), findsNothing);
  });
}
