import 'dart:io';

import 'package:flutter/material.dart';

import '../app_metrics.dart';
import 'app_property_illustration.dart';

/// The property's own residence/unit photo when one has been attached
/// (the report's cover photo — a local file), otherwise the drawn
/// [AppPropertyIllustration]. Never a stock or remote image.
class AppPropertyPhoto extends StatelessWidget {
  const AppPropertyPhoto({
    super.key,
    required this.photoPath,
    required this.kind,
    this.width = 64,
    this.height = 64,
    this.radius = AppRadius.md,
  });

  final String? photoPath;
  final AppPropertyIllustrationKind kind;
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fallback = SizedBox(
      width: width,
      height: height,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: AppPropertyIllustration(
          kind: kind,
          size: height,
          radius: radius,
        ),
      ),
    );
    final path = photoPath;
    if (path == null || path.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => fallback,
        ),
      ),
    );
  }
}
