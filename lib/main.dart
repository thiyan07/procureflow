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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Production fails fast if misconfigured — never silently use mock
  DemoConfig.validateProduction();
  await LocalStorage.instance.init();
  try {
    await FCMService.instance.initialize();
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
