import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/demo_config.dart';
import '../network/api_client.dart';
import '../../services/api/api_notification_repository.dart';
import '../../firebase_options.dart';

/// FCM service - real integration.
/// Requires:
/// 1. firebase_core + firebase_messaging + flutter_local_notifications in pubspec (now enabled)
/// 2. android/app/google-services.json (from Firebase Console) - not committed
/// 3. Firebase project service account for backend (FCM_PROJECT_ID etc)
class FCMService {
  FCMService._();
  static final FCMService instance = FCMService._();

  String? _token;
  StreamSubscription? _refreshSub;
  final FlutterLocalNotificationsPlugin _localPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  String? get token => _token;
  bool get isInitialized => _initialized;

  Future<void> initialize({ApiClient? client}) async {
    if (_initialized) return;
    try {
      // Initialize Firebase (uses google-services.json on Android, or DefaultFirebaseOptions stub)
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (e) {
        // Already initialized or placeholder - try default init
        try {
          await Firebase.initializeApp();
        } catch (_) {}
      }
      // Request permission (Android 13+ and iOS)
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

      // Get token
      _token = await messaging.getToken();
      debugPrint('[FCM] Token: ${_token?.substring(0, 20)}...');

      if (_token != null && client != null) {
        await registerTokenWithBackend(client);
      } else if (_token != null) {
        // Try with default client if none supplied
        try {
          final c = ApiClient();
          await registerTokenWithBackend(c);
        } catch (_) {}
      }

      // Token refresh
      _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen((newToken) async {
        _token = newToken;
        debugPrint('[FCM] Token refreshed');
        final c = client ?? ApiClient();
        await registerTokenWithBackend(c);
      });

      // Foreground handler
      FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
        debugPrint('[FCM] Foreground: ${msg.notification?.title} ${msg.data}');
        await _showLocalNotification(msg);
        handleForegroundMessage(msg.data);
      });

      // Background tap handlers (terminated/background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage msg) {
        debugPrint('[FCM] onMessageOpenedApp: ${msg.data}');
        handleNotificationTap(msg.data);
      });
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        debugPrint('[FCM] getInitialMessage: ${initial.data}');
        // Delay routing until app ready
        Future.delayed(const Duration(seconds: 1), () => handleNotificationTap(initial.data));
      }

      // Local notifications setup for foreground
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      await _localPlugin.initialize(const InitializationSettings(android: androidInit, iOS: iosInit),
          onDidReceiveNotificationResponse: (resp) {
        if (resp.payload != null) {
          try {
            // payload is JSON string
            handleNotificationTap({ 'payload': resp.payload });
          } catch (_) {}
        }
      });

      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] Real init failed: $e');
      // Production must fail loudly, not silently mock (per Phase 6)
      const isProd = bool.fromEnvironment('APP_ENV', defaultValue: false) || bool.fromEnvironment('ENVIRONMENT', defaultValue: false);
      // Check DemoConfig environment via string check
      final env = const String.fromEnvironment('APP_ENV', defaultValue: 'dev');
      final isProductionEnv = env == 'prod' || env == 'production';
      if (isProductionEnv) {
        // In production, rethrow to fail fast - FCM is required but not configured
        debugPrint('[FCM] Production requires real Firebase config - failing');
        rethrow;
      }
      if (DemoConfig.useMockBackend && kDebugMode) {
        _token = 'mock_fcm_token_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        _token = 'pending_real_token';
      }
    }
  }

  Future<void> _showLocalNotification(RemoteMessage msg) async {
    try {
      const androidDetails = AndroidNotificationDetails('procureflow_high', 'ProcureFlow', channelDescription: 'Procurement updates', importance: Importance.high, priority: Priority.high);
      const details = NotificationDetails(android: androidDetails, iOS: DarwinNotificationDetails());
      await _localPlugin.show(
        msg.hashCode,
        msg.notification?.title ?? 'ProcureFlow',
        msg.notification?.body ?? msg.data['body'] ?? '',
        details,
        payload: msg.data.isNotEmpty ? msg.data.toString() : null,
      );
    } catch (_) {}
  }

  Future<void> registerTokenWithBackend(ApiClient client) async {
    if (_token == null || _token!.startsWith('mock') || _token!.startsWith('pending')) {
      // Don't register mock tokens in production
      if (_token?.startsWith('mock') == true && !kDebugMode) return;
    }
    if (_token == null) return;
    try {
      final repo = ApiNotificationRepository(client);
      await repo.registerDeviceToken(_token!, Platform.isAndroid ? 'android' : 'ios');
      debugPrint('[FCM] Token registered with backend');
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  void handleForegroundMessage(Map<String, dynamic> message) {
    debugPrint('[FCM] Foreground: $message');
  }

  void handleNotificationTap(Map<String, dynamic> data) {
    debugPrint('[FCM] Tap: $data');
    try {
      // Deep-link via existing GoRouter (requires context-less navigation)
      // Use AppRouter.router if available, else store for next launch
      // ignore: avoid_dynamic_calls
      final router = _getRouter();
      if (router != null) {
        final type = data['type'] as String? ?? data['notification_type'] as String? ?? 'general';
        final bookingId = data['booking_id'] as String? ?? data['bookingId'] as String?;
        String route = '/notifications';
        switch (type) {
          case 'turn_approaching':
          case 'token_called':
          case 'queue_position_changed':
          case 'queue':
            route = bookingId != null ? '/queue' : '/queue';
            break;
          case 'procurement_stage_updated':
          case 'procurement_completed':
            route = '/procurement';
            break;
          case 'payment_status_updated':
            route = '/payment';
            break;
          case 'slot_confirmed':
            route = '/home';
            break;
          default:
            route = '/notifications';
        }
        router.go(route);
      }
    } catch (e) {
      debugPrint('[FCM] Tap routing failed: $e');
    }
  }

  dynamic _getRouter() {
    try {
      // ignore: avoid_web_libraries_in_flutter
      // Dynamic import to avoid circular dependency
      // Use global via app_router.dart if available
      // This will be set via FCMService.router setter if needed
      return _router;
    } catch (_) {
      return null;
    }
  }

  static dynamic _router;
  static void setRouter(dynamic r) => _router = r;

  void dispose() {
    _refreshSub?.cancel();
  }
}

// Background handler must be top-level
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('[FCM] Background: ${message.data}');
}
