// lib/share/style/theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../local/constants.dart';

// ── Dark theme (original) ─────────────────────────────────────────────────────
final ThemeData darkTheme = ThemeData(
  brightness:              Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF0D1117),
  colorScheme: const ColorScheme.dark(
    primary:   kGold,
    secondary: kGoldDim,
    surface:   Color(0xFF161B22),
    onSurface: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor:  Color(0xFF0D1117),
    foregroundColor:  Colors.white,
    elevation:        0,
    titleTextStyle:   TextStyle(
        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
    iconTheme:        IconThemeData(color: Colors.white),
    systemOverlayStyle: SystemUiOverlayStyle.dark,
  ),
  cardColor:    const Color(0xFF161B22),
  dividerColor: const Color(0x1AFFFFFF),
  iconTheme:    const IconThemeData(color: Colors.white70),
  textTheme: const TextTheme(
    bodyLarge:  TextStyle(color: Colors.white),
    bodyMedium: TextStyle(color: Colors.white70),
    bodySmall:  TextStyle(color: Colors.white54),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled:    true,
    fillColor: Color(0xFF161B22),
    border: OutlineInputBorder(
      borderSide:   BorderSide(color: Colors.white12),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide:   BorderSide(color: Colors.white12),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide:   BorderSide(color: kGold, width: 1.5),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    labelStyle: TextStyle(color: Colors.white54),
    hintStyle:  TextStyle(color: Colors.white38),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kGold,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      elevation: 0,
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor:  WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? kGold : Colors.white38),
    trackColor:  WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? kGold.withValues(alpha: 0.4) : Colors.white12),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor:    Color(0xFF0D1117),
    selectedItemColor:  kGold,
    unselectedItemColor: Colors.white38,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: Color(0xFF161B22),
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20))),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: Color(0xFF21262D),
    contentTextStyle: TextStyle(color: Colors.white),
    behavior: SnackBarBehavior.floating,
  ),
);

// ── Light theme ───────────────────────────────────────────────────────────────
final ThemeData lightTheme = ThemeData(
  brightness:              Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF5F5F0),
  colorScheme: const ColorScheme.light(
    primary:   kGold,
    secondary: kGoldDim,
    surface:   Color(0xFFFFFFFF),
    onSurface: Color(0xFF0D1117),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor:  Color(0xFFFFFFFF),
    foregroundColor:  Color(0xFF0D1117),
    elevation:        0,
    titleTextStyle:   TextStyle(
        color: Color(0xFF0D1117), fontSize: 18, fontWeight: FontWeight.bold),
    iconTheme:        IconThemeData(color: kGold),
    systemOverlayStyle: SystemUiOverlayStyle.light,
  ),
  cardColor:    const Color(0xFFFFFFFF),
  dividerColor: const Color(0x1A0D1117),
  iconTheme:    const IconThemeData(color: Color(0xFF444C56)),
  textTheme: const TextTheme(
    bodyLarge:  TextStyle(color: Color(0xFF0D1117)),
    bodyMedium: TextStyle(color: Color(0xFF444C56)),
    bodySmall:  TextStyle(color: Color(0xFF8B949E)),
  ),
  inputDecorationTheme: const InputDecorationTheme(
    filled:    true,
    fillColor: Color(0xFFF0EEE8),
    border: OutlineInputBorder(
      borderSide:   BorderSide(color: Color(0x1A0D1117)),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    enabledBorder: OutlineInputBorder(
      borderSide:   BorderSide(color: Color(0x1A0D1117)),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide:   BorderSide(color: kGold, width: 1.5),
      borderRadius: BorderRadius.all(Radius.circular(12)),
    ),
    labelStyle: TextStyle(color: Color(0xFF8B949E)),
    hintStyle:  TextStyle(color: Color(0xFF8B949E)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kGold,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      elevation: 0,
    ),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? kGold : Colors.white),
    trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? kGold.withValues(alpha: 0.4) : const Color(0xFFD0D0D0)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor:    Color(0xFFFFFFFF),
    selectedItemColor:  kGold,
    unselectedItemColor: Color(0xFF8B949E),
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: Color(0xFFFFFFFF),
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20))),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: Color(0xFF333333),
    contentTextStyle: TextStyle(color: Colors.white),
    behavior: SnackBarBehavior.floating,
  ),
);
