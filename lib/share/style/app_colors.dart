// lib/share/style/app_colors.dart
//
// Now fully theme-aware — resolves from ThemeData.brightness.
// Dark values are identical to the original hardcoded values.
// Light values match the new lightTheme in theme.dart.

import 'package:flutter/material.dart';

class AppColors {
  final bool  isDark;
  final Color bg;
  final Color surface;
  final Color elevated;
  final Color text;
  final Color textSub;
  final Color textHint;
  final Color border;
  final Color unread;

  const AppColors._({
    required this.isDark,
    required this.bg,
    required this.surface,
    required this.elevated,
    required this.text,
    required this.textSub,
    required this.textHint,
    required this.border,
    required this.unread,
  });

  static const _dark = AppColors._(
    isDark:   true,
    bg:       Color(0xFF0D1117),
    surface:  Color(0xFF161B22),
    elevated: Color(0xFF21262D),
    text:     Colors.white,
    textSub:  Colors.white70,
    textHint: Colors.white38,
    border:   Color(0x1AFFFFFF),
    unread:   Color(0xFF1E2730),
  );

  static const _light = AppColors._(
    isDark:   false,
    bg:       Color(0xFFF5F5F0),
    surface:  Color(0xFFFFFFFF),
    elevated: Color(0xFFF0EEE8),
    text:     Color(0xFF0D1117),
    textSub:  Color(0xFF444C56),
    textHint: Color(0xFF8B949E),
    border:   Color(0x1A0D1117),
    unread:   Color(0xFFFFF8E8),
  );

  factory AppColors.of(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? _dark : _light;
  }
}
