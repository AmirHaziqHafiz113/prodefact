import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
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
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.widgetWithText(NavigationDestination, 'Home'), findsOneWidget);
    expect(
      find.widgetWithText(NavigationDestination, 'Inspections'),
      findsOneWidget,
    );
    expect(find.widgetWithText(NavigationDestination, 'New'), findsOneWidget);
    expect(
      find.widgetWithText(NavigationDestination, 'Wallet'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(NavigationDestination, 'Profile'),
      findsOneWidget,
    );
  });

  testWidgets('tapping Home switches to the Home tab, showing the real '
      'wallet balance and an empty-progress state with no inspections', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeDashboardScreen), findsOneWidget);
    // FakeBillingService's default starting balance.
    expect(find.text('500 Credits'), findsOneWidget);
    expect(find.text('No active inspections.'), findsOneWidget);
  });

  testWidgets('tapping Wallet switches to the Wallet tab and shows the '
      'real balance, Top Up action, and an empty activity feed', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Wallet'));
    await tester.pumpAndSettle();

    expect(find.byType(WalletScreen), findsOneWidget);
    expect(find.text('500 Credits'), findsOneWidget);
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

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Local inspector'), findsOneWidget);
  });

  testWidgets('tapping the "+" destination pushes New Inspection, not a '
      'sixth tab', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('New'));
    await tester.pumpAndSettle();

    expect(find.byType(PropertyTypeSelectionScreen), findsOneWidget);
    // The bottom nav is hidden during this focused setup flow.
    expect(find.byType(NavigationBar), findsNothing);
  });
}
