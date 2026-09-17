import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home_inspection/presentation/screens/property_type_selection_screen.dart';

/// The authenticated bottom-navigation shell: Home / Inspections / +
/// / Wallet / Profile — see docs/commercial_model.md. Wraps the four
/// real [StatefulShellRoute] branches (Home, Inspections, Wallet,
/// Profile); the "+" destination isn't a branch at all — it always
/// pushes straight into the existing New Inspection flow, exactly what
/// the dashboard's own "New Inspection" button already does, so there's
/// only one New Inspection entry point to keep consistent.
///
/// Only screens reached via the bottom nav show it — the New
/// Inspection setup flow, physical inspection, AI review, and the
/// report all push on top of this shell and intentionally hide it
/// while the inspector is in a focused task (see the routing audit in
/// docs/commercial_model.md).
class AppShellScreen extends StatelessWidget {
  const AppShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _addTabIndex = 2;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _destinationIndexFor(navigationShell.currentIndex),
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Inspections',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            selectedIcon: Icon(Icons.add_circle),
            label: 'New',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  /// Maps a branch index (0..3 — Home/Inspections/Wallet/Profile) to
  /// its visual destination index (0,1,3,4 — index 2 is "+", not a
  /// branch).
  int _destinationIndexFor(int branchIndex) =>
      branchIndex < _addTabIndex ? branchIndex : branchIndex + 1;

  void _onDestinationSelected(BuildContext context, int destinationIndex) {
    if (destinationIndex == _addTabIndex) {
      context.push(PropertyTypeSelectionScreen.routePath);
      return;
    }
    final branchIndex = destinationIndex < _addTabIndex
        ? destinationIndex
        : destinationIndex - 1;
    navigationShell.goBranch(
      branchIndex,
      initialLocation: branchIndex == navigationShell.currentIndex,
    );
  }
}
