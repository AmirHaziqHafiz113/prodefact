import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_metrics.dart';

/// A compact single-line progress indicator — a short label, a thin
/// filled bar, and a fraction — for dense secondary metrics (e.g. an
/// area row's AI/Review progress) that need a real visual fill without
/// the weight of a full [AppProgressBar] or [AppRingProgress].
class AppMiniProgressLine extends StatelessWidget {
  const AppMiniProgressLine({
    super.key,
    required this.label,
    required this.value,
    required this.fractionLabel,
    this.color = AppColors.primary,
  });

  /// 0.0–1.0.
  final double value;
  final String label;
  final String fractionLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 4,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          fractionLabel,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}
