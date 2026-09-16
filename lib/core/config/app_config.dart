/// App-wide environment configuration.
/// Supports dev / staging / prod without hardcoding secrets.

enum AppEnvironment { dev, staging, prod }

class AppConfig {
  final AppEnvironment environment;
  final String appName;
  final bool enableDebugBanner;
  final bool enableLogging;

  const AppConfig._({
    required this.environment,
    required this.appName,
    required this.enableDebugBanner,
    required this.enableLogging,
  });

  static const dev = AppConfig._(
    environment: AppEnvironment.dev,
    appName: 'ProcureFlow (Dev)',
    enableDebugBanner: true,
    enableLogging: true,
  );

  static const prod = AppConfig._(
    environment: AppEnvironment.prod,
    appName: 'ProcureFlow',
    enableDebugBanner: false,
    enableLogging: false,
  );

  static AppConfig get current {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    return env == 'prod' ? prod : dev;
  }

  bool get isDev => environment == AppEnvironment.dev;
  bool get isProd => environment == AppEnvironment.prod;
}
