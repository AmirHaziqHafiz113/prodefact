import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home_inspection/presentation/widgets/capture_entry_sheet.dart';
import '../../features/home_inspection/providers/session_list_providers.dart';
import '../theme/design_system.dart';

/// The authenticated bottom-navigation shell: Home / Inspections / + /
/// Review / Profile — see docs/ux_architecture.md. Wraps the four real
/// [StatefulShellRoute] branches; the "+" destination isn't a branch:
/// it starts the capture flow ([startCaptureFlow] — pick an open
/// inspection and area, then the camera; or New Inspection when nothing
/// is open). Review carries a real count badge of inspections waiting on
/// the inspector. Wallet is no longer a tab: it opens from Home's credits
/// card and from Profile.
///
/// Only screens reached via the bottom nav show it — the New
/// Inspection setup flow, the inspection itself, AI review and the
/// report all push on top of this shell and hide it while the inspector
/// is in a focused task.
class AppShellScreen extends ConsumerWidget {
  const AppShellScreen({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _addTabIndex = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewCount = ref.watch(attentionSessionsProvider).length;
    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _destinationIndexFor(navigationShell.currentIndex),
        reviewBadgeCount: reviewCount,
        onDestinationSelected: (index) =>
            _onDestinationSelected(context, ref, index),
      ),
    );
  }

  /// Maps a branch index (0..3 — Home/Inspections/Review/Profile) to
  /// its visual destination index (0,1,3,4 — index 2 is "+", not a
  /// branch).
  int _destinationIndexFor(int branchIndex) =>
      branchIndex < _addTabIndex ? branchIndex : branchIndex + 1;

  void _onDestinationSelected(
    BuildContext context,
    WidgetRef ref,
    int destinationIndex,
  ) {
    if (destinationIndex == _addTabIndex) {
      startCaptureFlow(context, ref);
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
    this.reviewBadgeCount = 0,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  /// Inspections waiting on the inspector — badges the Review tab.
  final int reviewBadgeCount;

  static const _reviewIndex = 3;

  static const _destinations = [
    (icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Home'),
    (
      icon: Icons.assignment_outlined,
      selectedIcon: Icons.assignment,
      label: 'Inspections',
    ),
    (icon: Icons.add, selectedIcon: Icons.add, label: 'Capture'),
    (
      icon: Icons.rate_review_outlined,
      selectedIcon: Icons.rate_review,
      label: 'Review',
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
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.12),
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
                        badgeCount: i == _reviewIndex ? reviewBadgeCount : 0,
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
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final int badgeCount;
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
              Badge(
                isLabelVisible: badgeCount > 0,
                label: Text('$badgeCount'),
                backgroundColor: AppColors.warning,
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
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
/// that overflows the bar's top edge): the global capture action rather
/// than a tab.
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
          message: 'Capture',
          child: Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 58,
                height: 58,
                child: Icon(Icons.add_a_photo, color: Colors.white, size: 26),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
