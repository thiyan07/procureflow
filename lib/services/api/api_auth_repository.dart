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
    // Validate token with backend; if 401 then clear stale session (fixes Ravi without input + restart loop)
    try {
      await _client.get('/api/v1/auth/me');
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('Invalid token') || msg.contains('Unauthorized') || msg.contains('INVALID_TOKEN')) {
        // Token expired/invalid -> clear and force login
        await logout();
        return null;
      }
      // Network error: keep cached user for offline use
    }
    try {
      return AppUser.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> sendOtp(String mobile) async {
    throw Exception('OTP authentication deprecated. Use phone number + password. POST /api/v1/auth/login');
  }

  @override
  Future<void> sendOtpToEmail(String email) async {
    throw Exception('OTP authentication deprecated. Use phone number + password. POST /api/v1/auth/login');
  }

  @override
  Future<AppUser> loginWithMobileAndOtp(String mobile, String otp) async {
    throw Exception('OTP authentication deprecated. Use loginWithMobileAndPassword. POST /api/v1/auth/login');
  }

  @override
  Future<AppUser> loginWithMobileAndPassword(String mobile, String password) async {
    // Primary: POST /api/v1/auth/login {mobile, password}
    Map<String, dynamic> res;
    try {
      res = await _client.post('/api/v1/auth/login', body: {'mobile': mobile, 'password': password}, auth: false);
    } catch (e) {
      if (e.toString().contains('404') || e.toString().contains('Not Found')) {
        res = await _client.post('/api/v1/auth/login-password', body: {'mobile': mobile, 'password': password}, auth: false);
      } else {
        rethrow;
      }
    }
    final access = res['access_token'] as String? ?? res['accessToken'] as String? ?? res['token'] as String? ?? '';
    if (access.isEmpty) throw Exception('Login failed: no token returned');
    final role = res['role'] as String? ?? 'FARMER';
    final userId = res['user_id'] as String? ?? res['userId'] as String? ?? mobile;
    // Persist token BEFORE fetching /auth/me so the GET is authenticated (fixes 401 + null farmer)
    await LocalStorage.instance.saveAuth(access, UserRoleX.fromString(role), jsonEncode(AppUser(id: userId, mobile: mobile, role: role, farmer: null).toJson()));
    if (res['refresh_token'] != null) {
      await LocalStorage.instance.setString('refresh_token', res['refresh_token'] as String);
    } else if (res['refreshToken'] != null) {
      await LocalStorage.instance.setString('refresh_token', res['refreshToken'] as String);
    }
    AppUser user;
    try {
      final me = await _client.get('/api/v1/auth/me');
      final farmerJson = me['farmer'];
      Farmer? farmer;
      if (farmerJson != null) {
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
      user = AppUser(id: userId, mobile: farmer?.mobile ?? mobile, role: role, farmer: farmer);
    } catch (_) {
      final existingStr = LocalStorage.instance.getString(AppConstants.keyUserJson);
      if (existingStr != null) {
        try { return AppUser.fromJson(jsonDecode(existingStr) as Map<String, dynamic>); } catch (_) {}
      }
      user = AppUser(id: userId, mobile: mobile, role: role, farmer: null);
    }
    // Update with full farmer if fetched
    await LocalStorage.instance.saveAuth(access, UserRoleX.fromString(role), jsonEncode(user.toJson()));
    return user;
  }

  @override
  Future<AppUser> loginWithEmailAndOtp(String email, String otp) async {
    throw Exception('OTP authentication deprecated. Use phone number + password.');
  }

  @override
  Future<AppUser> registerFarmer({
    required String fullName,
    required String mobile,
    required String password,
    String? email,
    required String farmerId,
    required String village,
    required String district,
    required String languageCode,
    required String primaryCommodity,
  }) async {
    // New auth/register endpoint stores password + account details in DB.
    // Falls back to legacy /api/v1/farmers if auth endpoint not available (for older backend).
    try {
      final res = await _client.post('/api/v1/auth/register', body: {
        'full_name': fullName,
        'mobile': mobile,
        'password': password,
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'farmer_id': farmerId,
        'village': village,
        'district': district,
        'language_code': languageCode,
        'primary_commodity': primaryCommodity,
      }, auth: false);

      // If backend returns tokens directly, save session.
      final access = res['access_token'] as String? ?? res['accessToken'] as String? ?? res['token'] as String?;
      if (access != null && access.isNotEmpty) {
        final role = res['role'] as String? ?? 'FARMER';
        final userId = res['user_id'] as String? ?? res['id'] as String? ?? mobile;
        // Extract farmer if present
        Farmer farmer;
        final farmerJson = res['farmer'] as Map<String, dynamic>?;
        if (farmerJson != null) {
          farmer = Farmer.fromJson({
            'id': farmerJson['id'] ?? userId,
            'fullName': farmerJson['full_name'] ?? farmerJson['fullName'] ?? fullName,
            'mobile': farmerJson['mobile'] ?? mobile,
            'farmerId': farmerJson['farmer_id'] ?? farmerJson['farmerId'] ?? farmerId,
            'village': farmerJson['village'] ?? village,
            'district': farmerJson['district'] ?? district,
            'languageCode': farmerJson['language_code'] ?? languageCode,
            'primaryCommodity': farmerJson['primary_commodity'] ?? primaryCommodity,
          });
        } else {
          farmer = Farmer(
            id: userId,
            fullName: fullName,
            mobile: mobile,
            farmerId: farmerId,
            village: village,
            district: district,
            languageCode: languageCode,
            primaryCommodity: primaryCommodity,
          );
        }
        final user = AppUser(id: userId, mobile: mobile, role: role, farmer: farmer);
        await LocalStorage.instance.saveAuth(access, UserRoleX.fromString(role), jsonEncode(user.toJson()));
        if (res['refresh_token'] != null) {
          await LocalStorage.instance.setString('refresh_token', res['refresh_token'] as String);
        }
        await LocalStorage.instance.saveLanguage(languageCode);
        return user;
      }

      // Otherwise backend created farmer record without token; map response to farmer and use existing token if any
      final farmer = Farmer(
        id: res['id'] as String? ?? 'f_${DateTime.now().millisecondsSinceEpoch}',
        fullName: res['full_name'] as String? ?? fullName,
        mobile: res['mobile'] as String? ?? mobile,
        farmerId: res['farmer_id'] as String? ?? farmerId,
        village: res['village'] as String? ?? village,
        district: res['district'] as String? ?? district,
        languageCode: res['language_code'] as String? ?? languageCode,
        primaryCommodity: res['primary_commodity'] as String? ?? primaryCommodity,
      );
      final userJson = LocalStorage.instance.getString(AppConstants.keyUserJson);
      AppUser? existing;
      if (userJson != null) {
        try { existing = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>); } catch (_) {}
      }
      final user = AppUser(id: existing?.id ?? farmer.id, mobile: mobile, role: existing?.role ?? 'FARMER', farmer: farmer);
      final token = LocalStorage.instance.authToken ?? access ?? '';
      if (token.isNotEmpty) {
        await LocalStorage.instance.saveAuth(token, UserRoleX.fromString(user.role), jsonEncode(user.toJson()));
      } else {
        // No token yet: still persist farmer locally so next login works in offline demo sense; but real login will require /login
        await LocalStorage.instance.setString(AppConstants.keyUserJson, jsonEncode(user.toJson()));
      }
      await LocalStorage.instance.saveLanguage(languageCode);
      return user;
    } catch (e) {
      // If /api/v1/auth/register not found, fallback to legacy farmers endpoint (requires auth but works for mock-backed dev)
      if (!e.toString().contains('404') && !e.toString().contains('Not Found')) rethrow;
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
        try { existing = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>); } catch (_) {}
      }
      final user = AppUser(id: existing?.id ?? farmer.id, mobile: mobile, role: existing?.role ?? 'FARMER', farmer: farmer);
      final token = LocalStorage.instance.authToken ?? '';
      await LocalStorage.instance.saveAuth(token, UserRoleX.fromString(user.role), jsonEncode(user.toJson()));
      await LocalStorage.instance.saveLanguage(languageCode);
      return user;
    }
  }

  @override
  Future<void> logout() async {
    await LocalStorage.instance.remove(AppConstants.keyAuthToken);
    await LocalStorage.instance.remove(AppConstants.keyUserJson);
    await LocalStorage.instance.remove(AppConstants.keyUserRole);
    await LocalStorage.instance.remove('refresh_token');
  }
}
