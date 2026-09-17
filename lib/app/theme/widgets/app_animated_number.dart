import 'package:flutter/material.dart';

/// A bounded, one-shot count-up entrance for a real integer metric
/// (Credits balance, etc.) — never a looping/infinite animation, so it
/// stays deterministic under `tester.pumpAndSettle()`. Gives a metric
/// number a moment of deliberate motion instead of snapping into
/// place, without animating on every rebuild (only when [value]
/// actually changes).
class AppAnimatedNumber extends StatelessWidget {
  const AppAnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
  });

  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        return Text(
          '$prefix$animatedValue$suffix',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
      },
    );
  }
}
