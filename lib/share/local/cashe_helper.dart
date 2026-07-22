import 'package:shared_preferences/shared_preferences.dart';

/// Local key-value storage wrapper around SharedPreferences.
/// Named CacheHelper (previously CashHelper — typo corrected).
class CacheHelper {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static dynamic getData({required String key}) => _prefs?.get(key);

  static Future<bool?> saveData({
    required String key,
    required dynamic value,
  }) async {
    if (value is String)  return _prefs?.setString(key, value);
    if (value is int)     return _prefs?.setInt(key, value);
    if (value is bool)    return _prefs?.setBool(key, value);
    if (value is double)  return _prefs?.setDouble(key, value);
    return null;
  }

  static Future<bool?> putData({required String key, required bool value}) =>
      saveData(key: key, value: value);

  static Future<bool>? removeData({required String key}) =>
      _prefs?.remove(key);
}

/// Backward-compatibility alias so existing imports don't break.
typedef CashHelper = CacheHelper;
