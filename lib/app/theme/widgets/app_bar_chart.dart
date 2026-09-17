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

    // The value label above each bar and the day/area label below it
    // both grow with the system text-scale setting, but [height] is a
    // fixed pixel budget a caller chose assuming the *default* text
    // size — at a large accessibility text scale the two labels alone
    // can need more than that fixed budget, which overflowed
    // vertically (a real bug this pass found and fixed). Grow the
    // actual rendered height to whatever the labels really need at the
    // current scale instead of clipping them; never shrinks below the
    // caller's requested [height].
    final labelBudget = MediaQuery.textScalerOf(context).scale(36);
    final effectiveHeight = height < labelBudget + 16
        ? labelBudget + 16
        : height;

    return SizedBox(
      height: effectiveHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in points)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    Text(
                      point.value == 0 ? '' : point.value.round().toString(),
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 2),
                    // `Expanded` + `FractionallySizedBox` (rather than a
                    // hardcoded "total height minus a guessed label
                    // budget" pixel calculation) so the bar always gets
                    // whatever vertical space is actually left over
                    // after the two labels above/below it, however
                    // tall they turn out to be at the current text
                    // scale — a fixed pixel budget overflowed at larger
                    // accessibility text sizes, a real bug this pass
                    // found and fixed.
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: maxValue == 0 ? 0 : point.value / maxValue,
                        ),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (context, fraction, _) {
                          return Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: fraction.clamp(0.03, 1.0),
                              widthFactor: 1,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: point.value == 0
                                      ? AppColors.surfaceMuted
                                      : color,
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.sm,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
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
