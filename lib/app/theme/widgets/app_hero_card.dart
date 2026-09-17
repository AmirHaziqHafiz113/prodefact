import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_metrics.dart';

/// The dark-green "hero" treatment used for the single most important
/// piece of content on a screen (the active inspection's progress on
/// Home, the inspection-wide progress panel on Inspection Overview) —
/// deliberately used sparingly so it keeps reading as "the important
/// thing" rather than becoming another repeated card style.
class AppHeroCard extends StatelessWidget {
  const AppHeroCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: IconTheme.merge(
          data: const IconThemeData(color: Colors.white),
          child: child,
        ),
      ),
    );
  }
}
