import 'package:flutter/material.dart';

import '../app_colors.dart';

/// The ProDefact wordmark — an icon badge plus "Pro" + "Defact" in two
/// weights (matching the two-tone treatment used across the reference
/// mockups), drawn entirely from vector/`Icon` primitives. No bundled
/// image asset exists (or is needed) for this.
class ProDefactBrandMark extends StatelessWidget {
  const ProDefactBrandMark({super.key, this.iconSize = 26, this.fontSize = 20});

  final double iconSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.fact_check_outlined,
          size: iconSize,
          color: AppColors.primary,
        ),
        const SizedBox(width: 6),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Pro',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              TextSpan(
                text: 'Defact',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
