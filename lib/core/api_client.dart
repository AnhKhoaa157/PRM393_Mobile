part of '../main.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.status, this.code]);
  final String message;
  final int? status;

  /// Structured backend error code (e.g. `BUILDING_REQUIRED`), when provided.
  final String? code;
  @override
  String toString() => message;
}

/// REST adapter for the existing Node backend. API_BASE is read from `.env`.
class ApiClient {
  /// `localhost` on Android refers to the emulator itself, not the development
  /// machine.  Android emulators expose the host at 10.0.2.2.
  String get baseUrl {
    final configuredUrl = dotenv.env['API_BASE']?.trim();
    if (configuredUrl == null || configuredUrl.isEmpty) {
      throw ApiException('Missing API_BASE in .env.');
    }
    return _normaliseBaseUrl(configuredUrl);
  }

  String _normaliseBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return value.replaceFirst(RegExp(r'/$'), '');

    if (kIsWeb && uri.host == '10.0.2.2') {
      return uri
          .replace(host: 'localhost')
          .toString()
          .replaceFirst(RegExp(r'/$'), '');
    }

    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        (uri.host == 'localhost' || uri.host == '127.0.0.1')) {
      return uri
          .replace(host: '10.0.2.2')
          .toString()
          .replaceFirst(RegExp(r'/$'), '');
    }
    return value.replaceFirst(RegExp(r'/$'), '');
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    String? token,
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$path');
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      http.Response response;
      final requestBody = body != null ? jsonEncode(body) : null;

      switch (method.toUpperCase()) {
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: requestBody)
              .timeout(const Duration(seconds: 20));
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: requestBody)
              .timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers, body: requestBody)
              .timeout(const Duration(seconds: 20));
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: requestBody)
              .timeout(const Duration(seconds: 20));
          break;
        default:
          response = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
      }

      final text = response.body;
      dynamic payload;
      try {
        payload = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      } on FormatException {
        payload = <String, dynamic>{};
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = payload is Map && payload['message'] != null
            ? payload['message'].toString()
            : 'Request failed (${response.statusCode})';
        final code = payload is Map
            ? (payload['errorCode'] ?? payload['code'])?.toString()
            : null;
        throw ApiException(message, response.statusCode, code);
      }
      return payload;
    } on ApiException catch (e) {
      rethrow;
    } on TimeoutException {
      throw ApiException('The parking server at $baseUrl took too long to respond.');
    } catch (e) {
      throw ApiException('Cannot connect to $baseUrl. Check that the backend is running and API_BASE is reachable from this device.');
    }
  }
}

class SessionController extends ChangeNotifier {
  SessionController(this.api);
  final ApiClient api;
  static const _tokenKey = 'pbms_token';
  final _storage = const FlutterSecureStorage();
  User? user;
  String? token;
  bool restoring = true;

  Future<void> restore() async {
    try {
      token = await _storage.read(key: _tokenKey);
      if (token != null) await reloadProfile();
    } catch (_) {
      token = null;
      user = null;
      await _storage.delete(key: _tokenKey);
    } finally {
      restoring = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final result =
        await api.request('/users/auth/login', method: 'POST', body: {
      'email': email.trim().toLowerCase(),
      'password': password,
    });
    final data = _data(result);
    final rawUser = _map(data['user']);
    final nextToken = data['token']?.toString();
    if (rawUser == null || nextToken == null)
      throw ApiException('Invalid login response.');
    token = nextToken;
    user = User.fromJson(rawUser);
    await _storage.write(key: _tokenKey, value: token);
    notifyListeners();
  }

  Future<void> register(
      String name, String email, String password, String phone) async {
    final result =
        await api.request('/users/auth/register', method: 'POST', body: {
      'fullName': name.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'phone': phone.trim(),
    });
    final data = _data(result);
    final rawUser = _map(data['user']);
    final nextToken = data['token']?.toString();
    if (rawUser == null || nextToken == null)
      throw ApiException('Invalid registration response.');
    token = nextToken;
    user = User.fromJson(rawUser);
    await _storage.write(key: _tokenKey, value: token);
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    token = null;
    user = null;
    notifyListeners();
  }

  Future<void> reloadProfile() async {
    if (token == null) return;
    final result = await api.request('/users/auth/me', token: token);
    final raw = _map(_data(result)['user']);
    if (raw != null) {
      user = User.fromJson(raw);
      notifyListeners();
    }
  }
}

Map<String, dynamic> _data(dynamic value) => _map(value)?['data'] is Map
    ? Map<String, dynamic>.from(_map(value)!['data'] as Map)
    : <String, dynamic>{};
Map<String, dynamic>? _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : null;
List<Map<String, dynamic>> _items(dynamic value, [String name = 'items']) {
  final data = _data(value);
  final list = data[name] is List ? data[name] as List : <dynamic>[];
  return list
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
