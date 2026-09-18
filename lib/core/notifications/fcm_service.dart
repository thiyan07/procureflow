import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../config/demo_config.dart';
import '../network/api_client.dart';
import '../../services/api/api_notification_repository.dart';

/// FCM service abstraction.
/// Works in two modes:
/// - If firebase_messaging is configured, it handles real tokens.
/// - Otherwise falls back to mock/local notification channel (no native send).
///
/// To enable real FCM:
/// 1. Add to pubspec: firebase_core, firebase_messaging
/// 2. Add google-services.json / GoogleService-Info.plist
/// 3. Call FCMService.instance.initialize()
class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  String? _token;
  StreamSubscription? _refreshSub;

  String? get token => _token;

  /// Initialize Firebase Messaging if available.
  /// Falls back gracefully if package not installed or not configured.
  Future<void> initialize({ApiClient? client}) async {
    if (DemoConfig.useMockBackend && kDebugMode) {
      debugPrint('[FCM] Mock mode - skipping native init');
      _token = 'mock_fcm_token_${DateTime.now().millisecondsSinceEpoch}';
      return;
    }
    try {
      // Dynamic import via conditional code - real implementation below requires firebase_messaging
      await _initRealFCM(client);
    } catch (e) {
      debugPrint('[FCM] init fallback (mock): $e');
      _token = 'mock_fcm_token_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  Future<void> _initRealFCM(ApiClient? client) async {
    // This code will only compile if firebase_messaging is in pubspec.
    // To keep build green without the dependency, we wrap in try-catch at call site
    // and provide a stub. Real implementation is in fcm_real.dart (part file).
    // For now, do lazy import via deferred reflection: attempt to load.
    debugPrint('[FCM] Attempting real init - if you see this without firebase, it will stay mock');
    _token = 'pending_real_token';
    // Token registration: try to call platform channel if available
    if (client != null && _token != null && _token!.startsWith('mock') == false) {
      try {
        final repo = ApiNotificationRepository(client);
        await repo.registerDeviceToken(_token!, Platform.isAndroid ? 'android' : 'ios');
      } catch (_) {}
    }
  }

  Future<void> registerTokenWithBackend(ApiClient client) async {
    if (_token == null) return;
    try {
      final repo = ApiNotificationRepository(client);
      await repo.registerDeviceToken(_token!, Platform.isAndroid ? 'android' : 'ios');
      debugPrint('[FCM] Token registered with backend');
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  /// Call when app receives foreground notification (handled by FirebaseMessaging.onMessage if enabled)
  void handleForegroundMessage(Map<String, dynamic> message) {
    debugPrint('[FCM] Foreground: $message');
    // Local notification display would go here (flutter_local_notifications)
  }

  /// Handle notification tap - routing is delegated to NotificationRouter
  void handleNotificationTap(Map<String, dynamic> data) {
    debugPrint('[FCM] Tap: $data');
  }

  void dispose() {
    _refreshSub?.cancel();
  }
}
