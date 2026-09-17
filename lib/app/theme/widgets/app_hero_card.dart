import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_metrics.dart';
import 'app_brand_pattern.dart';

/// The dark-green "hero" treatment used for the single most important
/// piece of content on a screen (the active inspection's progress on
/// Home, the balance surface on Wallet, the inspection-wide progress
/// panel on Inspection Overview) — deliberately used sparingly so it
/// keeps reading as "the important thing" rather than becoming another
/// repeated card style. A hero is the one place this border-first
/// design system deliberately allows depth: a richer three-stop
/// gradient, a soft shadow lifting it off the page, and a faint brand
/// geometry pattern — never applied to routine cards or rows.
class AppHeroCard extends StatelessWidget {
  const AppHeroCard({
    super.key,
    required this.child,
    this.padding,
    this.showPattern = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Off for hero variants that already carry enough visual interest
  /// (e.g. a real photo) that the pattern would just add noise.
  final bool showPattern;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryLight,
            AppColors.primary,
            AppColors.primaryDark,
          ],
          stops: [0, 0.5, 1],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (showPattern) const Positioned.fill(child: AppBrandPattern()),
          Padding(
            padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
            child: DefaultTextStyle.merge(
              style: const TextStyle(color: Colors.white),
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
