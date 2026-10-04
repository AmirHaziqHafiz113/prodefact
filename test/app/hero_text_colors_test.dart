import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prodefact/app/theme/app_colors.dart';
import 'package:prodefact/app/theme/widgets/app_hero_card.dart';

/// Hero text uses design-system tokens (brand-tinted mints, not
/// translucent white) and stays readable on the hero's green.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  test('every hero text token keeps at least 4.5:1 on the hero green', () {
    for (final token in [
      AppColors.onHero,
      AppColors.onHeroSecondary,
      AppColors.onHeroMuted,
    ]) {
      expect(_contrast(token, AppColors.primary), greaterThanOrEqualTo(4.5));
      expect(
        _contrast(token, AppColors.primaryDark),
        greaterThanOrEqualTo(4.5),
      );
    }
    // The hierarchy reads in order: primary > secondary > muted.
    expect(
      _luminance(AppColors.onHero),
      greaterThan(_luminance(AppColors.onHeroSecondary)),
    );
    expect(
      _luminance(AppColors.onHeroSecondary),
      greaterThan(_luminance(AppColors.onHeroMuted)),
    );
  });

  testWidgets('text inside a hero defaults to the hero token, and the '
      'card keeps its size', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: AppHeroCard(child: Text('Jed Residence')),
          ),
        ),
      ),
    );
    final style = DefaultTextStyle.of(
      tester.element(find.text('Jed Residence')),
    ).style;
    expect(style.color, AppColors.onHero);
    expect(tester.getSize(find.byType(AppHeroCard)).width, 360);
  });
}
