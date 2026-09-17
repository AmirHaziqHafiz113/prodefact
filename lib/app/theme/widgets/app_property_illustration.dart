import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_metrics.dart';

/// Which silhouette [AppPropertyIllustration] paints — kept generic
/// (not the feature-layer `PropertyType` enum) so this shared design-
/// system widget has no dependency on feature config; call sites map
/// their own property type to this at the call site.
enum AppPropertyIllustrationKind { highRise, landed }

/// A small, locally-drawn vector illustration standing in for a
/// property photo — ProDefact has no property-photo capture in its
/// data model (see `AppFallbackThumbnail`'s doc comment), and
/// production must never use stock/remote imagery. Rather than a
/// generic centered icon, this paints a simple silhouette (a high-rise
/// tower with a window grid, or a gable-roofed landed house) so the
/// fallback itself reads as a deliberate piece of brand illustration.
/// Real captured/uploaded property images should replace this when the
/// product ever supports them — this widget is the honest placeholder
/// until then.
class AppPropertyIllustration extends StatelessWidget {
  const AppPropertyIllustration({
    super.key,
    required this.kind,
    this.size = 56,
    this.radius = AppRadius.md,
  });

  final AppPropertyIllustrationKind kind;
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          size: Size.square(size),
          painter: _PropertyPainter(
            isHighRise: kind == AppPropertyIllustrationKind.highRise,
            color: AppColors.primaryLight,
          ),
        ),
      ),
    );
  }
}

class _PropertyPainter extends CustomPainter {
  const _PropertyPainter({required this.isHighRise, required this.color});

  final bool isHighRise;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fill = Paint()..color = color.withValues(alpha: 0.85);
    final window = Paint()..color = Colors.white.withValues(alpha: 0.9);

    if (isHighRise) {
      // A tower silhouette with a regular window grid — reads as
      // "apartment/condominium" at a glance without any text.
      final towerRect = Rect.fromLTWH(w * 0.22, h * 0.12, w * 0.56, h * 0.8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(towerRect, Radius.circular(w * 0.04)),
        fill,
      );
      const cols = 3;
      const rows = 5;
      final cellW = towerRect.width / (cols * 2 + 1);
      final cellH = towerRect.height / (rows * 2 + 1);
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final dx = towerRect.left + cellW * (1 + c * 2);
          final dy = towerRect.top + cellH * (1 + r * 2);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(dx, dy, cellW, cellH),
              Radius.circular(w * 0.01),
            ),
            window,
          );
        }
      }
    } else {
      // A gable-roofed house silhouette with a door and one window —
      // reads as "landed/terrace house."
      final bodyRect = Rect.fromLTWH(w * 0.16, h * 0.42, w * 0.68, h * 0.46);
      canvas.drawRRect(
        RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.03)),
        fill,
      );
      final roof = Path()
        ..moveTo(w * 0.10, h * 0.44)
        ..lineTo(w * 0.5, h * 0.14)
        ..lineTo(w * 0.90, h * 0.44)
        ..close();
      canvas.drawPath(roof, fill);
      // Door.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.45, h * 0.62, w * 0.12, h * 0.26),
          Radius.circular(w * 0.015),
        ),
        window,
      );
      // Window.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.24, h * 0.54, w * 0.13, h * 0.13),
          Radius.circular(w * 0.015),
        ),
        window,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PropertyPainter oldDelegate) =>
      oldDelegate.isHighRise != isHighRise || oldDelegate.color != color;
}
