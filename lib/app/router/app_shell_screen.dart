import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home_inspection/presentation/screens/property_type_selection_screen.dart';
import '../theme/design_system.dart';

/// The authenticated bottom-navigation shell: Home / Inspections / +
/// / Wallet / Profile — see docs/commercial_model.md and
/// docs/ui_design_system.md ("Navigation"). Wraps the four real
/// [StatefulShellRoute] branches (Home, Inspections, Wallet, Profile);
/// the "+" destination isn't a branch at all — it always pushes
/// straight into the existing New Inspection flow, exactly what the
/// dashboard's/Inspections' own "New Inspection" actions already do,
/// so there's only one New Inspection entry point to keep consistent.
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
      extendBody: true,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _destinationIndexFor(navigationShell.currentIndex),
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, index),
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

/// A floating, pill-shaped bottom bar with a raised circular center
/// action — visually distinct from a standard Material [NavigationBar]
/// to match the reference mockups, while keeping the exact same
/// destination semantics (index 2 is the global "+" action, never a
/// real tab).
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _destinations = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    (
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment,
      label: 'Inspections',
    ),
    (icon: Icons.add, selectedIcon: Icons.add, label: 'New Inspection'),
    (
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
      label: 'Wallet',
    ),
    (icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.outline),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < _destinations.length; i++)
              Expanded(
                child: i == 2
                    ? _AddDestination(
                        selected: selectedIndex == i,
                        onTap: () => onDestinationSelected(i),
                      )
                    : _NavDestination(
                        icon: selectedIndex == i
                            ? _destinations[i].selectedIcon
                            : _destinations[i].icon,
                        label: _destinations[i].label,
                        selected: selectedIndex == i,
                        onTap: () => onDestinationSelected(i),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavDestination extends StatelessWidget {
  const _NavDestination({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.successBg : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The center "+" — visually raised above the bar (a filled circle
/// that overflows the bar's top edge), matching the reference mockups'
/// treatment of "New Inspection" as a global action rather than a tab.
class _AddDestination extends StatelessWidget {
  const _AddDestination({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, -14),
        child: Tooltip(
          message: 'New Inspection',
          child: Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 52,
                height: 52,
                child: Icon(Icons.add, color: Colors.white, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
