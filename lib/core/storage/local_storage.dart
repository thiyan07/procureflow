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

  // Offline cache — lightweight, never pretends success without server
  static const _kCachedBooking = 'cached_booking_json';
  static const _kCachedBookingTime = 'cached_booking_time';
  static const _kCachedQueue = 'cached_queue_json';
  static const _kCachedQueueTime = 'cached_queue_time';
  static const _kCachedProfile = 'cached_profile_json';
  static const _kCachedProfileTime = 'cached_profile_time';
  static const _kCachedCentres = 'cached_centres_json';
  static const _kCachedCentresTime = 'cached_centres_time';
  static const _kCachedNotifications = 'cached_notifications_json';
  static const _kCachedNotificationsTime = 'cached_notifications_time';
  Future<void> cacheBooking(String json) async {
    await setString(_kCachedBooking, json);
    await setString(_kCachedBookingTime, DateTime.now().toIso8601String());
  }
  String? get cachedBooking => getString(_kCachedBooking);
  String? get cachedBookingTime => getString(_kCachedBookingTime);
  Future<void> cacheQueue(String json) async {
    await setString(_kCachedQueue, json);
    await setString(_kCachedQueueTime, DateTime.now().toIso8601String());
  }
  String? get cachedQueue => getString(_kCachedQueue);
  String? get cachedQueueTime => getString(_kCachedQueueTime);
  bool get hasCachedBooking => cachedBooking != null;
  Future<void> cacheProfile(String json) async {
    await setString(_kCachedProfile, json);
    await setString(_kCachedProfileTime, DateTime.now().toIso8601String());
  }
  String? get cachedProfile => getString(_kCachedProfile);
  String? get cachedProfileTime => getString(_kCachedProfileTime);
  Future<void> cacheCentres(String json) async {
    await setString(_kCachedCentres, json);
    await setString(_kCachedCentresTime, DateTime.now().toIso8601String());
  }
  String? get cachedCentres => getString(_kCachedCentres);
  String? get cachedCentresTime => getString(_kCachedCentresTime);
  Future<void> cacheNotifications(String json) async {
    await setString(_kCachedNotifications, json);
    await setString(_kCachedNotificationsTime, DateTime.now().toIso8601String());
  }
  String? get cachedNotifications => getString(_kCachedNotifications);
  String? get cachedNotificationsTime => getString(_kCachedNotificationsTime);
  String get lastUpdatedLabel {
    final t = cachedBookingTime ?? cachedQueueTime ?? cachedProfileTime;
    if (t==null) return 'Last updated: never';
    try { return 'Last updated: ${DateTime.parse(t).toLocal().toString().split('.').first}'; } catch (_){ return 'Last updated: $t'; }
  }
}
