import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class LocalStorage {
  LocalStorage._();
  static final LocalStorage instance = LocalStorage._();
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get prefs {
    if (_prefs == null) throw StateError('LocalStorage not initialized');
    return _prefs!;
  }

  Future<void> setString(String key, String value) async {
    if (_prefs == null) return;
    await prefs.setString(key, value);
  }

  String? getString(String key) {
    if (_prefs == null) return null;
    return prefs.getString(key);
  }

  Future<void> setBool(String key, bool value) async {
    if (_prefs == null) return;
    await prefs.setBool(key, value);
  }

  bool? getBool(String key) {
    if (_prefs == null) return null;
    return prefs.getBool(key);
  }

  Future<void> remove(String key) async {
    if (_prefs == null) return;
    await prefs.remove(key);
  }

  Future<void> clear() async {
    if (_prefs == null) return;
    await prefs.clear();
  }

  // Typed helpers
  Future<void> saveAuth(String token, UserRole role, String userJson) async {
    await setString(AppConstants.keyAuthToken, token);
    await setString(AppConstants.keyUserRole, role.nameStr);
    await setString(AppConstants.keyUserJson, userJson);
  }

  String? get authToken => getString(AppConstants.keyAuthToken);
  UserRole? get userRole {
    final v = getString(AppConstants.keyUserRole);
    if (v == null) return null;
    return UserRoleX.fromString(v);
  }

  bool get isLoggedIn => authToken != null;

  Future<void> saveLanguage(String code) => setString(AppConstants.keyLanguage, code);
  String get languageCode => getString(AppConstants.keyLanguage) ?? 'en';
}
