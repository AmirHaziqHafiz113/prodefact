import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_metrics.dart';

/// A placeholder block shaped like the real content that will replace
/// it — used instead of a lone spinner on screens where a skeleton
/// communicates the eventual layout (e.g. Wallet/Home/Inspections
/// while their first real data is loading). Deliberately a plain
/// static block, not an animated/shimmer one: an unbounded, repeating
/// [AnimationController] here would keep a ticker alive forever,
/// which makes `tester.pumpAndSettle()` hang in any widget test that
/// happens to build this widget even briefly (a real regression this
/// pass hit and fixed) — not worth it for a purely cosmetic pulse.
class AppSkeletonBox extends StatelessWidget {
  const AppSkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A ready-made skeleton for a card-list screen (Wallet/Inspections
/// first paint) — a handful of [AppSkeletonBox] rows shaped like the
/// real content that will replace them.
class AppSkeletonCardList extends StatelessWidget {
  const AppSkeletonCardList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppSkeletonBox(width: 140, height: 16),
                  const SizedBox(height: AppSpacing.sm),
                  const AppSkeletonBox(width: 200, height: 12),
                  const SizedBox(height: AppSpacing.md),
                  const AppSkeletonBox(height: 8),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
