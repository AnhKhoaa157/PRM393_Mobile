part of '../main.dart';

class ApiException implements Exception {
  ApiException(this.message, [this.status]);
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// REST adapter for the existing Node backend. Set API_BASE at build/run time.
class ApiClient {
  String get baseUrl {
    const definedUrl = String.fromEnvironment('API_BASE');
    return definedUrl.isNotEmpty
        ? definedUrl
        : dotenv.env['API_BASE'] ?? 'http://10.0.2.2:5000/api';
  }

  Future<dynamic> request(
    String path, {
    String method = 'GET',
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('$baseUrl$path');
      final request = await client
          .openUrl(method, uri)
          .timeout(const Duration(seconds: 20));
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (token != null && token.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) request.write(jsonEncode(body));
      final response =
          await request.close().timeout(const Duration(seconds: 20));
      final text = await response.transform(utf8.decoder).join();
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
        throw ApiException(message, response.statusCode);
      }
      return payload;
    } on SocketException {
      throw ApiException(
          'Cannot connect to the parking server. Check API_BASE.');
    } on TimeoutException {
      throw ApiException('The parking server took too long to respond.');
    } finally {
      client.close(force: true);
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
