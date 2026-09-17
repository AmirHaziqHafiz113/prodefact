import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_metrics.dart';

/// One real-data point in an [AppBarChart] — e.g. one day's/week's
/// Credits usage, or one area's finding count. Never a fabricated or
/// interpolated value.
class AppBarChartPoint {
  const AppBarChartPoint({required this.label, required this.value});

  final String label;
  final double value;
}

/// A minimal, animated bar chart for real-data-only usage — e.g.
/// Wallet's usage-over-time, or a completed inspection's
/// findings-by-area. Deliberately simple (no external charting
/// package): bars scale relative to the largest value in [points], and
/// animate in on first build.
class AppBarChart extends StatelessWidget {
  const AppBarChart({
    super.key,
    required this.points,
    this.color = AppColors.primary,
    this.height = 120,
    this.emptyMessage = 'No data yet.',
  });

  final List<AppBarChartPoint> points;
  final Color color;
  final double height;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty || points.every((p) => p.value == 0)) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            emptyMessage,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      point.value == 0 ? '' : point.value.round().toString(),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 2),
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: maxValue == 0 ? 0 : point.value / maxValue,
                      ),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      builder: (context, fraction, _) {
                        return Container(
                          height: (height - 40).clamp(4, height) * fraction,
                          decoration: BoxDecoration(
                            color: point.value == 0
                                ? AppColors.surfaceMuted
                                : color,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
