import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // String
  Future<bool> setString(String key, String value) async {
    await init();
    return _prefs!.setString(key, value);
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }

  // Int
  Future<bool> setInt(String key, int value) async {
    await init();
    return _prefs!.setInt(key, value);
  }

  int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  // Bool
  Future<bool> setBool(String key, bool value) async {
    await init();
    return _prefs!.setBool(key, value);
  }

  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  // Remove
  Future<bool> remove(String key) async {
    await init();
    return _prefs!.remove(key);
  }

  // Clear
  Future<bool> clear() async {
    await init();
    return _prefs!.clear();
  }
}
