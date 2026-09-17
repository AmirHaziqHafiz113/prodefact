import 'package:flutter/material.dart';

import '../app_colors.dart';

/// A labeled, animated circular progress ring — real-data progress only
/// (e.g. "N of M findings analysed"), never a decorative or fake
/// value. Mirrors [AppProgressBar]'s animate-between-values behavior so
/// changes read as deliberate feedback rather than a snap.
class AppRingProgress extends StatelessWidget {
  const AppRingProgress({
    super.key,
    required this.value,
    required this.label,
    this.valueLabel,
    this.color = AppColors.primary,
    this.size = 96,
  });

  /// 0.0–1.0.
  final double value;
  final String label;
  final String? valueLabel;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: size,
                    height: size,
                    child: CircularProgressIndicator(
                      value: animatedValue,
                      strokeWidth: 8,
                      backgroundColor: AppColors.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                  Text(
                    valueLabel ?? '${(animatedValue * 100).round()}%',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}
