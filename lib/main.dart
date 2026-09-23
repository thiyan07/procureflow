import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'core/storage/local_storage.dart';
import 'core/notifications/fcm_service.dart';
import 'core/config/demo_config.dart';
import 'services/providers.dart';
import 'l10n/app_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Production fails fast if misconfigured — never silently use mock
  DemoConfig.validateProduction();
  await LocalStorage.instance.init();
  // Firebase must be initialized before FCM
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (_) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (_) {}
  }
  try {
    await FCMService.instance.initialize();
  } catch (_) {}
  // Wire router for notification tap deep-links
  try {
    FCMService.setRouter(AppRouter.router);
  } catch (_) {}
  runApp(const ProviderScope(child: ProcureFlowApp()));
}

class ProcureFlowApp extends ConsumerWidget {
  const ProcureFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageCodeProvider);
    return MaterialApp.router(
      title: 'ProcureFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: AppRouter.router,
      locale: Locale(lang),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('ta'),
      ],
    );
  }
}
