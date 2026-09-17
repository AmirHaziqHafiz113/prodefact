import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_metrics.dart';

/// A single bordered container holding several related rows, separated
/// by hairline dividers — the grouped-list treatment
/// (docs/prodefact_design_system.md §9/§20) used instead of stacking
/// each row in its own separately-bordered card. One border defines
/// the whole group; rows inside it read as one unit, not five
/// competing cards.
class AppGroupedList extends StatelessWidget {
  const AppGroupedList({super.key, required this.children, this.color});

  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.outline),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            children[i],
          ],
        ],
      ),
    );
  }
}
