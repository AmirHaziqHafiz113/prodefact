import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_metrics.dart';

/// A designed fallback for a property/area "photo" the app has no real
/// image for (no property-photo or area-photo capture exists in the
/// data model — see docs/ui_design_system.md, "Image fallbacks"). A
/// tasteful icon-on-gradient tile, never a fabricated stock photo or a
/// blank box.
class AppFallbackThumbnail extends StatelessWidget {
  const AppFallbackThumbnail({
    super.key,
    required this.icon,
    this.size = 56,
    this.radius = AppRadius.md,
  });

  final IconData icon;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.plumbingBg, AppColors.surfaceMuted],
        ),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, size: size * 0.42, color: AppColors.primaryLight),
    );
  }
}
