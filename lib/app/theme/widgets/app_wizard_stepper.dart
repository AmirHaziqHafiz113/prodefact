import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_metrics.dart';

/// The reusable step indicator for the New Inspection wizard (Property
/// -> Details -> Areas -> Plan -> Review) — a "Step X of N" caption
/// plus a segmented progress bar, the same shape on every wizard
/// screen so the inspector always knows exactly where they are. One
/// component, not five ad hoc headers.
class AppWizardStepper extends StatelessWidget {
  const AppWizardStepper({
    super.key,
    required this.stepLabels,
    required this.currentIndex,
  });

  final List<String> stepLabels;

  /// 0-based index of the current step.
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              stepLabels[currentIndex],
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Text(
              'Step ${currentIndex + 1} of ${stepLabels.length}',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < stepLabels.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= currentIndex
                        ? AppColors.primary
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
