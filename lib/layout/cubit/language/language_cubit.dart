// lib/layout/cubit/language/language_cubit.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageState {
  final Locale locale;
  const LanguageState(this.locale);
}

class LanguageCubit extends Cubit<LanguageState> {
  static const _key = 'app_language';

  LanguageCubit() : super(const LanguageState(Locale('en')));

  static LanguageCubit get(BuildContext context) => BlocProvider.of(context);

  bool get isArabic => state.locale.languageCode == 'ar';

  /// Load saved language. Returns true if a language was already saved.
  static Future<LanguageCubit> create() async {
    final prefs = await SharedPreferences.getInstance();
    final code  = prefs.getString(_key);
    final cubit = LanguageCubit();
    if (code != null) {
      cubit.emit(LanguageState(Locale(code)));
    }
    return cubit;
  }

  static Future<bool> hasSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }

  static Future<bool> hasAgreedPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('privacy_agreed') ?? false;
  }

  static Future<void> setPrivacyAgreed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_agreed', true);
  }

  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, languageCode);
    emit(LanguageState(Locale(languageCode)));
  }

  Future<void> setEnglish() => setLanguage('en');
  Future<void> setArabic()  => setLanguage('ar');
}
