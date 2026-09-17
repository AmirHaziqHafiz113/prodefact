import 'package:flutter/material.dart';

import '../app_colors.dart';

/// A generated-initials avatar — never a fabricated stock photo. Used
/// everywhere the app would otherwise need a profile picture (top bars,
/// Profile header) but only ever has a real display name/email to work
/// with, never an uploaded photo.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.displayName,
    this.email,
    this.size = 40,
    this.onTap,
  });

  final String? displayName;
  final String? email;
  final double size;
  final VoidCallback? onTap;

  static const _palette = [
    AppColors.primary,
    AppColors.primaryLight,
    AppColors.plumbing,
    AppColors.accent,
    AppColors.info,
  ];

  String get _initials {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
      final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
      if (letters.isNotEmpty) return letters;
    }
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) {
      return mail[0].toUpperCase();
    }
    return '?';
  }

  Color get _background {
    final seed = (displayName?.isNotEmpty == true ? displayName! : email) ?? '';
    final index = seed.isEmpty ? 0 : seed.codeUnitAt(0) % _palette.length;
    return _palette[index];
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _background, shape: BoxShape.circle),
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.4,
        ),
      ),
    );
    if (onTap == null) return avatar;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: avatar,
    );
  }
}
