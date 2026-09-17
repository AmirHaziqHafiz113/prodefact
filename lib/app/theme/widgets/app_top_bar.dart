import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_metrics.dart';
import 'app_avatar.dart';
import 'app_brand_mark.dart';

/// The top identity row shared by Home/Wallet/Inspections/Profile: an
/// optional brand mark on the left, and real-data actions on the right
/// — a "needs attention" bell (only badged when [attentionCount] is
/// genuinely greater than zero, never a decorative dot) and/or a
/// settings gear, plus the signed-in inspector's avatar. Screens
/// compose this differently (Home/Wallet show the brand + bell +
/// avatar; Inspections shows just bell + avatar under its own title;
/// Profile shows brand + gear) rather than forcing one rigid layout.
class AppTopBar extends StatelessWidget {
  const AppTopBar({
    super.key,
    this.showBrand = true,
    this.attentionCount = 0,
    this.onAttentionTap,
    this.onSettingsTap,
    this.displayName,
    this.email,
    this.onAvatarTap,
  });

  final bool showBrand;

  /// A real count of items needing the inspector's attention (overdue
  /// inspections, pending reviews, failed AI) — never fabricated. Zero
  /// hides the badge dot entirely.
  final int attentionCount;
  final VoidCallback? onAttentionTap;
  final VoidCallback? onSettingsTap;
  final String? displayName;
  final String? email;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBrand) const ProDefactBrandMark(),
        const Spacer(),
        if (onAttentionTap != null)
          _IconWithBadge(
            icon: Icons.notifications_outlined,
            badgeCount: attentionCount,
            onTap: onAttentionTap!,
          ),
        if (onSettingsTap != null)
          IconButton(
            onPressed: onSettingsTap,
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
          ),
        if (onAvatarTap != null || displayName != null || email != null) ...[
          const SizedBox(width: AppSpacing.xs),
          AppAvatar(displayName: displayName, email: email, onTap: onAvatarTap),
        ],
      ],
    );
  }
}

class _IconWithBadge extends StatelessWidget {
  const _IconWithBadge({
    required this.icon,
    required this.badgeCount,
    required this.onTap,
  });

  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: badgeCount > 0 ? '$badgeCount need attention' : 'Notifications',
      icon: Badge(
        isLabelVisible: badgeCount > 0,
        backgroundColor: AppColors.danger,
        smallSize: 9,
        child: Icon(icon),
      ),
    );
  }
}
