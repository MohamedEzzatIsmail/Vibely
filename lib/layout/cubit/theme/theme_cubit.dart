// lib/layout/cubit/theme/theme_cubit.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── States ────────────────────────────────────────────────────────────────────
abstract class ThemeState {}

class DarkThemeState extends ThemeState {}

class LightThemeState extends ThemeState {}

// ── Cubit ─────────────────────────────────────────────────────────────────────
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(DarkThemeState());

  static ThemeCubit get(BuildContext context) => BlocProvider.of(context);

  static const _prefKey = 'themeMode';

  /// Load theme from SharedPreferences on app start.
  static Future<ThemeCubit> create() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool(_prefKey) ?? true;
    final cubit = ThemeCubit();
    isDark ? cubit._emitDark() : cubit._emitLight();
    return cubit;
  }

  bool get isDark => state is DarkThemeState;

  void toggle() {
    if (isDark) {
      _emitLight();
      _save(false);
    } else {
      _emitDark();
      _save(true);
    }
  }

  void _emitDark() => emit(DarkThemeState());
  void _emitLight() => emit(LightThemeState());

  Future<void> _save(bool isDark) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isDark);
  }
}

// ── Light theme data ──────────────────────────────────────────────────────────
ThemeData get lightThemeData => ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      colorScheme: const ColorScheme.light(
        primary: Color(0xFFe5c687),
        secondary: Color(0xFF1565C0),
        surface: Color(0xFFFFFFFF),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF0D1117),
        elevation: 0,
      ),
      cardColor: Colors.white,
      dividerColor: Color(0xFFE0E0E0),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF0D1117)),
        bodyMedium: TextStyle(color: Color(0xFF333333)),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF0F0F0),
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Color(0xFFCCCCCC)),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
