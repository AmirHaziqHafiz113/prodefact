import 'package:flutter/material.dart';

/// ProDefact's semantic color tokens. Screens should reference these
/// (or `Theme.of(context).colorScheme`) rather than picking arbitrary
/// `Colors.*` values — this is the single place the palette is tuned.
abstract final class AppColors {
  // Brand — a confident, professional deep teal/navy blue, distinct
  // from Flutter's default Material blue/indigo demo look.
  static const primary = Color(0xFF0F5C57);
  static const primaryDark = Color(0xFF0A3F3C);
  static const primaryLight = Color(0xFF3D8F89);
  static const accent = Color(0xFFDB8B2A); // warm amber — CTAs, highlights

  // Text on the dark-green hero (`AppHeroCard`). Brand-tinted mints
  // rather than translucent white, which read as a flat grey on green.
  // Each keeps at least 4.5:1 contrast on [primary], the hero's main
  // tone (see app_colors_test.dart).
  static const onHero = Color(0xFFFFFFFF); // titles, key values
  static const onHeroSecondary = Color(0xFFD4EBE7); // supporting lines
  static const onHeroMuted = Color(0xFFB5D8D2); // timestamps, captions

  // Neutral surfaces.
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF4F6F6);
  static const surfaceMuted = Color(0xFFEAEFEE);
  static const outline = Color(0xFFD7DEDD);
  static const textPrimary = Color(0xFF14201F);
  static const textSecondary = Color(0xFF576765);
  static const textMuted = Color(0xFF8A9896);

  // Status/semantic colors — always paired with an icon/label, never
  // color alone.
  static const success = Color(0xFF2E9E5B);
  static const successBg = Color(0xFFE4F5EA);
  static const warning = Color(0xFFC97A0F);
  static const warningBg = Color(0xFFFBF0DE);
  static const danger = Color(0xFFC94B3F);
  static const dangerBg = Color(0xFFFAE7E4);
  static const info = Color(0xFF2E6EA6);
  static const infoBg = Color(0xFFE3EEF7);
  static const neutralBg = Color(0xFFEDEFEE);

  // Plumbing-priority accent (distinct from the rest of the semantic
  // set so "plumbing first" reads as a category, not a status).
  static const plumbing = Color(0xFF1F7A8C);
  static const plumbingBg = Color(0xFFE1F1F3);
}
