import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/app.dart';
import 'package:prodefact/app/router/app_shell_screen.dart';
import 'package:prodefact/features/home_inspection/config/property_type.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/area_inspection_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/home_dashboard_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/inspection_sessions_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/profile_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/property_type_selection_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/review_inbox_screen.dart';
import 'package:prodefact/features/home_inspection/presentation/screens/wallet_screen.dart';
import 'package:prodefact/features/home_inspection/providers/active_session_providers.dart';
import 'package:prodefact/features/home_inspection/providers/new_inspection_draft_providers.dart';
import 'package:prodefact/features/home_inspection/providers/physical_inspection_providers.dart';

import 'support/test_repository.dart';

/// The bottom-navigation shell — Home / Inspections / + / Review /
/// Profile (docs/ux_architecture.md). Home is the landing screen;
/// Wallet is a pushed screen reached from Home and Profile; "+" picks
/// the inspection and area before opening the camera.
void main() {
  Finder inNav(Finder matching) =>
      find.descendant(of: find.byType(AppBottomNav), matching: matching);

  Future<void> pumpApp(
    WidgetTester tester, {
    ProviderContainer? container,
  }) async {
    final c = container ?? ProviderContainer(overrides: testOverrides());
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: c, child: const ProDefactApp()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the bottom nav shows Home, Inspections, Capture, Review and '
      'Profile — no Wallet tab — and Home is the landing screen', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(HomeDashboardScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
    expect(inNav(find.text('Home')), findsOneWidget);
    expect(inNav(find.text('Inspections')), findsOneWidget);
    expect(inNav(find.text('Review')), findsOneWidget);
    expect(inNav(find.text('Profile')), findsOneWidget);
    expect(inNav(find.text('Wallet')), findsNothing);
    // The "+" destination is icon-only — asserted via its tooltip.
    expect(inNav(find.byTooltip('Capture')), findsOneWidget);
  });

  testWidgets('Home shows the real wallet balance and a first-run empty '
      'state whose one action starts a new inspection', (tester) async {
    await pumpApp(tester);

    // FakeBillingService's default starting balance.
    expect(find.text('500 credits'), findsOneWidget);
    expect(find.text('No inspections yet'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-start-first')));
    await tester.pumpAndSettle();
    expect(find.byType(PropertyTypeSelectionScreen), findsOneWidget);
  });

  testWidgets('Wallet opens from Home\'s credits card as a pushed screen '
      '(bottom nav hidden), and back returns to Home', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('home-credits')));
    await tester.pumpAndSettle();

    expect(find.byType(WalletScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsNothing);
    expect(find.text('500 credits'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Top Up'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Starting balance'),
      200,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Starting balance'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(HomeDashboardScreen), findsOneWidget);
    expect(find.byType(AppBottomNav), findsOneWidget);
  });

  testWidgets('Profile groups the account settings and opens Wallet & '
      'usage', (tester) async {
    await pumpApp(tester);

    await tester.tap(inNav(find.text('Profile')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Local inspector'), findsOneWidget);
    expect(find.text('AI Analysis Preference'), findsOneWidget);
    expect(find.text('Inspector & company'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-wallet')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('profile-custom-catalogue')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('profile-wallet')));
    await tester.pumpAndSettle();
    expect(find.byType(WalletScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('Review tab with nothing waiting shows an "all caught up" '
      'empty state', (tester) async {
    await pumpApp(tester);

    await tester.tap(inNav(find.text('Review')));
    await tester.pumpAndSettle();

    expect(find.byType(ReviewInboxScreen), findsOneWidget);
    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('"View all inspections" on Home switches to the Inspections '
      'tab', (tester) async {
    final container = ProviderContainer(overrides: testOverrides());
    container
        .read(newInspectionDraftProvider.notifier)
        .begin(PropertyType.highRise);
    await container.read(newInspectionDraftProvider.notifier).startInspection();
    await pumpApp(tester, container: container);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('home-view-all')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // Clear the floating bottom nav that overlays the list's end.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-view-all')));
    await tester.pumpAndSettle();
    expect(find.byType(InspectionSessionsScreen), findsOneWidget);
  });

  group('"+" capture', () {
    testWidgets('with no open inspection it goes straight to New '
        'Inspection setup', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.byTooltip('Capture'));
      await tester.pumpAndSettle();

      expect(find.byType(PropertyTypeSelectionScreen), findsOneWidget);
      // The bottom nav is hidden during this focused setup flow.
      expect(find.byType(AppBottomNav), findsNothing);
    });

    testWidgets('with an open inspection it asks which inspection, then '
        'which area, then opens the camera in that area', (tester) async {
      final container = ProviderContainer(overrides: testOverrides());
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      final area = container.read(inspectionQueueProvider)[1];
      final sessionId = container.read(activeSessionProvider)!.id;
      await pumpApp(tester, container: container);

      await tester.tap(find.byTooltip('Capture'));
      await tester.pumpAndSettle();
      expect(find.text('Capture a finding'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('capture-new-inspection')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(ValueKey('capture-session-$sessionId')));
      await tester.pumpAndSettle();
      expect(find.text('Which area?'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('capture-area-${area.id}')));
      await tester.pumpAndSettle();

      final screen = tester.widget<AreaInspectionScreen>(
        find.byType(AreaInspectionScreen),
      );
      expect(screen.sectionId, area.id);
      expect(screen.autoCapture, isTrue);
      // The camera opened straight away (no Camera/Gallery question):
      // the photo preview is up, ready for a note and Save.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Save Finding'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"Start a new inspection" in the capture sheet opens setup', (
      tester,
    ) async {
      final container = ProviderContainer(overrides: testOverrides());
      container
          .read(newInspectionDraftProvider.notifier)
          .begin(PropertyType.highRise);
      await container
          .read(newInspectionDraftProvider.notifier)
          .startInspection();
      await pumpApp(tester, container: container);

      await tester.tap(find.byTooltip('Capture'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('capture-new-inspection')));
      await tester.pumpAndSettle();

      expect(find.byType(PropertyTypeSelectionScreen), findsOneWidget);
    });
  });
}
