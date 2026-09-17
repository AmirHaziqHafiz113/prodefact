import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_metrics.dart';

/// A compact icon + value + label stat, reused wherever the app shows
/// a single real number (Credits used, inspections analysed, active
/// count, findings, photos…) instead of every screen growing its own
/// near-identical private `_StatTile`. Always real, never decorative —
/// callers pass the already-computed value.
class AppMetricCard extends StatelessWidget {
  const AppMetricCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.caption,
    this.iconColor = AppColors.primary,
    this.dense = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? caption;
  final Color iconColor;

  /// A tighter layout for narrow multi-column rows (e.g. 3-across on a
  /// phone-width screen).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: dense ? 30 : 36,
          height: dense ? 30 : 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: dense ? 16 : 18, color: iconColor),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: dense ? textTheme.titleMedium : textTheme.headlineSmall,
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall,
        ),
        if (caption != null)
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
      ],
    );
  }
}
