/// Demo / Development Configuration — Phase 1
/// Clearly separates mock/demo from production.
/// All mock repositories read from this single source; switching to
/// production FastAPI only requires flipping `useMockBackend` and
/// providing `apiBaseUrl` via --dart-define or env.

class DemoConfig {
  const DemoConfig._();

  /// Set to false when backend (FastAPI) is ready.
  /// When false, repository providers should return Api* implementations
  /// instead of Mock* (see lib/services/providers.dart).
  /// Override via --dart-define=USE_MOCK=false
  static const bool useMockBackend = bool.fromEnvironment('USE_MOCK', defaultValue: false);

  /// Mock OTP for development - NEVER use in production.
  static const String demoOtp = '123456';

  /// Demo users
  static const String demoFarmerMobile = '9876543210';
  static const String demoOperatorMobile = '9876543211';
  static const String demoFarmerName = 'Ravi Kumar';

  /// Mock network delay to simulate real API latency
  static const Duration mockDelay = Duration(milliseconds: 800);

  /// Feature flags - allows toggling AI/rule-based implementations
  static const bool enableMockAI = true;
  static const bool enableMockNotifications = true;

  /// Production defaults — online Render URL; override via --dart-define for local dev.
  /// Local dev: --dart-define=API_BASE_URL=http://127.0.0.1:8000
  /// Android emulator: --dart-define=API_BASE_URL=http://10.0.2.2:8000
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://procureflow-api.onrender.com');
  static const String apiKey = String.fromEnvironment('API_KEY', defaultValue: '');

  static bool get isDemoMode => useMockBackend;

  /// Label shown in UI to clearly indicate demo data
  static const String demoBadgeLabel = 'DEMO MODE • Mock backend';

  /// Production check — fail fast if production is misconfigured
  static void validateProduction() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    const apiUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://procureflow-api.onrender.com');
    if (env == 'prod') {
      if (useMockBackend) {
        throw StateError('Production must not use Mock backend: set --dart-define=USE_MOCK=false');
      }
      if (apiUrl.contains('127.0.0.1') || apiUrl.contains('localhost')) {
        throw StateError('Production API_BASE_URL must not be localhost: $apiUrl');
      }
      // kept for backward compat - no longer needed since default is now prod URL
      // if apiUrl is still localhost, the check above already throws
    }
  }

  /// Documentation for future migration:
  /// 1. Implement ApiAuthRepository, ApiSlotRepository, etc. in lib/services/api/
  /// 2. In lib/services/providers.dart, switch providers:
  ///    final authRepositoryProvider = Provider<AuthRepository>((ref) => useMockBackend ? MockAuthRepository() : ApiAuthRepository(dio));
  /// 3. No UI changes required - UI depends only on abstract interfaces in lib/services/repositories.dart
}
