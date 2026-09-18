import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../../core/storage/local_storage.dart';
import '../../core/network/api_client.dart';
import '../../models/farmer.dart';
import '../repositories.dart';

class ApiAuthRepository implements AuthRepository {
  final ApiClient _client;
  ApiAuthRepository(this._client);

  @override
  Future<AppUser?> getCurrentUser() async {
    final token = LocalStorage.instance.authToken;
    final jsonStr = LocalStorage.instance.getString(AppConstants.keyUserJson);
    if (token == null || jsonStr == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> sendOtp(String mobile) async {
    await _client.post('/api/v1/auth/send-otp', body: {'mobile': mobile}, auth: false);
  }

  @override
  Future<AppUser> loginWithMobileAndOtp(String mobile, String otp) async {
    final res = await _client.post('/api/v1/auth/verify-otp', body: {'mobile': mobile, 'otp': otp}, auth: false);
    final access = res['access_token'] as String;
    final role = res['role'] as String? ?? 'FARMER';
    final userId = res['user_id'] as String? ?? mobile;
    // fetch profile if farmer? Try to get farmer profile, but not required for login
    AppUser user;
    try {
      final me = await _client.get('/api/v1/auth/me');
      final farmerJson = me['farmer'];
      Farmer? farmer;
      if (farmerJson != null) {
        // map backend farmer fields to Flutter Farmer
        farmer = Farmer.fromJson({
          'id': farmerJson['id'],
          'fullName': farmerJson['full_name'] ?? farmerJson['fullName'],
          'mobile': farmerJson['mobile'],
          'farmerId': farmerJson['farmer_id'] ?? farmerJson['farmerId'],
          'village': farmerJson['village'],
          'district': farmerJson['district'],
          'languageCode': farmerJson['language_code'] ?? 'en',
          'primaryCommodity': farmerJson['primary_commodity'] ?? 'Paddy',
        });
      }
      user = AppUser(id: userId, mobile: mobile, role: role, farmer: farmer);
    } catch (_) {
      user = AppUser(id: userId, mobile: mobile, role: role, farmer: null);
    }
    await LocalStorage.instance.saveAuth(access, UserRoleX.fromString(role), jsonEncode(user.toJson()));
    // store refresh token
    if (res['refresh_token'] != null) {
      await LocalStorage.instance.setString('refresh_token', res['refresh_token'] as String);
    }
    return user;
  }

  @override
  Future<AppUser> registerFarmer({
    required String fullName,
    required String mobile,
    required String farmerId,
    required String village,
    required String district,
    required String languageCode,
    required String primaryCommodity,
  }) async {
    // Ensure authenticated first; backend requires auth to create farmer profile.
    // If no token, create user via OTP flow first is expected. Here we just call farmer endpoint.
    final res = await _client.post('/api/v1/farmers', body: {
      'full_name': fullName,
      'mobile': mobile,
      'farmer_id': farmerId,
      'village': village,
      'district': district,
      'language_code': languageCode,
      'primary_commodity': primaryCommodity,
    });
    final farmer = Farmer(
      id: res['id'] as String,
      fullName: res['full_name'] as String? ?? fullName,
      mobile: res['mobile'] as String,
      farmerId: res['farmer_id'] as String? ?? farmerId,
      village: res['village'] as String,
      district: res['district'] as String,
      languageCode: res['language_code'] as String? ?? languageCode,
      primaryCommodity: res['primary_commodity'] as String? ?? primaryCommodity,
    );
    final userJson = LocalStorage.instance.getString(AppConstants.keyUserJson);
    AppUser? existing;
    if (userJson != null) {
      try {
        existing = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {}
    }
    final user = AppUser(id: existing?.id ?? farmer.id, mobile: mobile, role: existing?.role ?? 'FARMER', farmer: farmer);
    final token = LocalStorage.instance.authToken ?? '';
    await LocalStorage.instance.saveAuth(token, UserRoleX.fromString(user.role), jsonEncode(user.toJson()));
    await LocalStorage.instance.saveLanguage(languageCode);
    return user;
  }

  @override
  Future<void> logout() async {
    await LocalStorage.instance.remove(AppConstants.keyAuthToken);
    await LocalStorage.instance.remove(AppConstants.keyUserJson);
    await LocalStorage.instance.remove(AppConstants.keyUserRole);
    await LocalStorage.instance.remove('refresh_token');
  }
}
