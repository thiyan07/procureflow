import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../storage/local_storage.dart';
import '../config/demo_config.dart';

/// Lightweight API client - wraps http, injects auth header, parses errors.
/// Backend error format: {"detail": {"code": "...", "message": "..."}} or {"error": {...}}
class ApiClient {
  final String baseUrl;
  final http.Client _http;

  ApiClient({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? _resolveBaseUrl(),
        _http = client ?? http.Client();

  static String _resolveBaseUrl() {
    // Use web-friendly base for all platforms; emulator will fallback via host
    // If dart-define provides API_BASE_URL it wins (via DemoConfig.apiBaseUrl)
    final envUrl = DemoConfig.apiBaseUrl;
    // If envUrl is the android emulator address but running on linux/web, prefer 127.0.0.1
    if (envUrl.contains('10.0.2.2')) {
      // For web/linux/desktop, 10.0.2.2 is unreachable; use localhost
      // Detect via not android? For simplicity try 127.0.0.1 as fallback in client timeout logic
      // Keep as is - caller can override via constructor; fallback logic below
    }
    return envUrl;
  }

  Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final token = LocalStorage.instance.authToken;
      if (token != null) h['Authorization'] = 'Bearer $token';
    }
    final rid = DateTime.now().millisecondsSinceEpoch.toString();
    h['X-Request-ID'] = rid;
    return h;
  }

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final p = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$p');
    if (query == null || query.isEmpty) return uri;
    final q = <String, String>{};
    query.forEach((k, v) {
      if (v != null) q[k] = v.toString();
    });
    return uri.replace(queryParameters: {...uri.queryParameters, ...q});
  }

  String _errorMessage(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map) {
        if (j['detail'] is Map && j['detail']['message'] != null) return j['detail']['message'].toString();
        if (j['detail'] is String) return j['detail'].toString();
        if (j['error'] is Map && j['error']['message'] != null) return j['error']['message'].toString();
        if (j['message'] != null) return j['message'].toString();
      }
    } catch (_) {}
    return 'Request failed (${res.statusCode})';
  }

  // Render free cold start can be 60-120s on first wake, so use 60s + 2 retries
  Future<http.Response> _withRetry(Future<http.Response> Function() fn) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        return await fn().timeout(const Duration(seconds: 60));
      } on Exception catch (e) {
        final isTimeout = e.toString().contains('TimeoutException');
        if (attempt < 2 && isTimeout) {
          await Future.delayed(Duration(seconds: 4 * (attempt + 1)));
          continue;
        }
        final msg = isTimeout
            ? 'Server waking up (Render free tier cold start — can take 2-3 min on first request). Please wait 30s and tap Login again. Check https://procureflow-api.onrender.com/health'
            : 'Network error: $e';
        throw HttpException(msg);
      }
    }
    throw HttpException('Server waking up — please retry in 30s');
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query, bool auth = true}) async {
    final res = await _withRetry(() => _http.get(_uri(path, query), headers: _headers(auth: auth)));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is List) return {'data': decoded};
      return {'data': decoded};
    }
    throw HttpException(_errorMessage(res), uri: _uri(path, query));
  }

  Future<Map<String, dynamic>> post(String path, {Object? body, Map<String, dynamic>? query, bool auth = true}) async {
    final res = await _withRetry(() => _http.post(_uri(path, query), headers: _headers(auth: auth), body: body != null ? jsonEncode(body) : null));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }
    throw HttpException(_errorMessage(res), uri: _uri(path, query));
  }

  Future<Map<String, dynamic>> patch(String path, {Object? body, bool auth = true}) async {
    final res = await _withRetry(() => _http.patch(_uri(path), headers: _headers(auth: auth), body: body != null ? jsonEncode(body) : null));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }
    throw HttpException(_errorMessage(res), uri: _uri(path));
  }

  Future<List<dynamic>> getList(String path, {Map<String, dynamic>? query, bool auth = true}) async {
    final res = await _withRetry(() => _http.get(_uri(path, query), headers: _headers(auth: auth)));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return [];
      final decoded = jsonDecode(res.body);
      if (decoded is List) return decoded;
      if (decoded is Map && decoded['data'] is List) return decoded['data'] as List;
      return [decoded];
    }
    throw HttpException(_errorMessage(res));
  }

  Future<List<int>> getBytes(String path, {Map<String, dynamic>? query, bool auth = true}) async {
    final res = await _withRetry(() => _http.get(_uri(path, query), headers: _headers(auth: auth)));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.bodyBytes;
    }
    throw HttpException(_errorMessage(res), uri: _uri(path, query));
  }
}
