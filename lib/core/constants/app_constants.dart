class AppConstants {
  static const String appName = 'ProcureFlow';
  static const String tagline = 'Smart Procurement. Less Waiting.';
  static const String demoOtp = '123456';
  static const String demoFarmerMobile = '9876543210';
  static const String demoOperatorMobile = '9876543211';

  // Storage keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserRole = 'user_role';
  static const String keyUserJson = 'user_json';
  static const String keyLanguage = 'language_code';
  static const String keyOnboardingDone = 'onboarding_done';

  // Mock API delay
  static const Duration mockDelay = Duration(milliseconds: 800);

  // Queue
  static const int avgProcessingMinutes = 3;
  static const int defaultCounters = 3;

  // Real MSP commodities (2025-26 KMS, TNCSC DPC)
  // Rates in seed: Paddy 2369, Paddy Grade A 2389, Ragi 4886, Maize 2400, Pulses Tur 8000
  static const List<String> commodities = [
    'Paddy',
    'Paddy Grade A',
    'Ragi',
    'Maize',
    'Pulses (Tur)',
  ];
  static const Map<String, double> mspRates = {
    'Paddy': 2369,
    'Paddy Grade A': 2389,
    'Ragi': 4886,
    'Maize': 2400,
    'Pulses (Tur)': 8000,
  };
}

enum UserRole { farmer, centreOperator, admin }

extension UserRoleX on UserRole {
  String get nameStr => switch (this) {
        UserRole.farmer => 'FARMER',
        UserRole.centreOperator => 'CENTRE_OPERATOR',
        UserRole.admin => 'ADMIN',
      };

  static UserRole fromString(String v) => switch (v) {
        'CENTRE_OPERATOR' => UserRole.centreOperator,
        'ADMIN' => UserRole.admin,
        _ => UserRole.farmer,
      };
}

enum QueueStatus {
  waiting,
  called,
  arrived,
  processing,
  completed,
  cancelled,
  noShow,
}

enum ProcurementStage {
  bookingConfirmed,
  arrivedAtCentre,
  weighment,
  qualityCheck,
  procurement,
  completed,
  paymentProcessing,
  paymentCompleted,
}

enum PaymentStatus { pending, processing, completed, failed }
