import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:procureflow/core/storage/local_storage.dart';
import 'package:procureflow/services/mock/mock_repositories.dart';
import 'package:procureflow/core/constants/app_constants.dart';
import 'package:procureflow/core/utils/form_validators.dart';

void main() {
  group('Phase 2 AuthRepository Mock', () {
    late MockAuthRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.instance.init();
      await LocalStorage.instance.clear();
      repo = MockAuthRepository();
    });

    test('sendOtp succeeds with valid mobile', () async {
      await repo.sendOtp('9876543210');
    });

    test('loginWithMobileAndOtp validates demo OTP 123456', () async {
      final user = await repo.loginWithMobileAndOtp(AppConstants.demoFarmerMobile, '123456');
      expect(user.mobile, AppConstants.demoFarmerMobile);
      expect(user.role, 'FARMER');
      expect(user.farmer, isNotNull);
    });

    test('login fails with wrong OTP', () async {
      expect(
        () => repo.loginWithMobileAndOtp(AppConstants.demoFarmerMobile, '000000'),
        throwsException,
      );
    });

    test('operator login via demo operator mobile', () async {
      final user = await repo.loginWithMobileAndOtp(AppConstants.demoOperatorMobile, '123456');
      expect(user.role, 'CENTRE_OPERATOR');
      expect(user.farmer, isNull);
    });

    test('registerFarmer creates user and persists session', () async {
      final user = await repo.registerFarmer(
        fullName: 'Test Farmer',
        mobile: '9999999999',
        farmerId: 'FARM-TEST-001',
        village: 'TestVillage',
        district: 'Erode',
        languageCode: 'ta',
        primaryCommodity: 'Paddy',
      );
      expect(user.farmer?.fullName, 'Test Farmer');
      expect(user.farmer?.languageCode, 'ta');
      final current = await repo.getCurrentUser();
      expect(current?.mobile, '9999999999');
      expect(current?.farmer?.village, 'TestVillage');
    });

    test('logout clears session', () async {
      await repo.loginWithMobileAndOtp(AppConstants.demoFarmerMobile, '123456');
      expect(await repo.getCurrentUser(), isNotNull);
      await repo.logout();
      expect(await repo.getCurrentUser(), isNull);
      expect(LocalStorage.instance.isLoggedIn, false);
    });

    test('getCurrentUser returns null when not logged in', () async {
      expect(await repo.getCurrentUser(), isNull);
    });

    test('FormValidators mobile validation', () {
      expect(FormValidators.mobile(''), isNotNull);
      expect(FormValidators.mobile('123'), isNotNull);
      expect(FormValidators.mobile('9876543210'), isNull);
      expect(FormValidators.mobile(' 98765 43210 '), isNull);
    });

    test('FormValidators OTP validation', () {
      expect(FormValidators.otp(''), isNotNull);
      expect(FormValidators.otp('123'), isNotNull);
      expect(FormValidators.otp('123456'), isNull);
    });
  });

  group('LocalStorage session persistence', () {
    test('language persisted', () async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.instance.init();
      await LocalStorage.instance.clear();
      await LocalStorage.instance.saveLanguage('hi');
      expect(LocalStorage.instance.languageCode, 'hi');
      await LocalStorage.instance.saveLanguage('ta');
      expect(LocalStorage.instance.languageCode, 'ta');
    });
  });
}
