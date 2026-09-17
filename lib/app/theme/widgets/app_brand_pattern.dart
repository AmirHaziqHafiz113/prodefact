import 'package:flutter/material.dart';

/// A subtle, low-opacity technical-grid motif — ProDefact's brand
/// geometry, used only as a background layer on hero surfaces (never on
/// routine cards/rows). Evokes an inspection blueprint/scanning grid:
/// a sparse dot lattice plus two soft diagonal contour lines. Purely
/// decorative and painted once (no animation), so it never affects
/// widget-test determinism.
class AppBrandPattern extends StatelessWidget {
  const AppBrandPattern({
    super.key,
    this.color = Colors.white,
    this.opacity = 0.10,
  });

  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _BrandPatternPainter(color: color, opacity: opacity),
      ),
    );
  }
}

class _BrandPatternPainter extends CustomPainter {
  const _BrandPatternPainter({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..color = color.withValues(alpha: opacity);
    const spacing = 18.0;
    for (double y = 8; y < size.height; y += spacing) {
      for (
        double x = size.width * 0.35;
        x < size.width + spacing;
        x += spacing
      ) {
        canvas.drawCircle(Offset(x, y), 1.1, dotPaint);
      }
    }

    final linePaint = Paint()
      ..color = color.withValues(alpha: opacity * 1.4)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final path1 = Path()
      ..moveTo(size.width * 0.55, -4)
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.35,
        size.width + 8,
        size.height * 0.18,
      );
    final path2 = Path()
      ..moveTo(size.width * 0.4, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.85,
        size.width + 8,
        size.height * 0.6,
      );
    canvas.drawPath(path1, linePaint);
    canvas.drawPath(path2, linePaint);
  }

  @override
  bool shouldRepaint(covariant _BrandPatternPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.opacity != opacity;
}
