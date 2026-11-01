import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente mínimo de Supabase por REST (sin paquetes extra): inicio de sesión
/// anónimo, llamadas a funciones (RPC) y lectura/escritura de tablas.

class SupabaseException implements Exception {
  final int statusCode;
  final String message;
  const SupabaseException(this.statusCode, this.message);

  @override
  String toString() => 'SupabaseException($statusCode): $message';
}

class SupabaseSession {
  final String accessToken;
  final String refreshToken;
  final String userId;
  final DateTime expiresAt;

  const SupabaseSession({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
    required this.expiresAt,
  });

  bool get expiresSoon => DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 2)));

  Map<String, dynamic> toMap() => {
        'a': accessToken,
        'r': refreshToken,
        'u': userId,
        'e': expiresAt.millisecondsSinceEpoch,
      };

  static SupabaseSession? fromMap(dynamic map) {
    if (map is! Map) return null;
    try {
      return SupabaseSession(
        accessToken: map['a'].toString(),
        refreshToken: map['r'].toString(),
        userId: map['u'].toString(),
        expiresAt: DateTime.fromMillisecondsSinceEpoch((map['e'] as num).toInt()),
      );
    } catch (_) {
      return null;
    }
  }
}

class SupabaseRest {
  final String url;
  final String key;
  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 20);

  SupabaseRest({required this.url, required this.key, http.Client? client}) : _client = client ?? http.Client();

  Map<String, String> _headers([String? token, Map<String, String>? extra]) => {
        'apikey': key,
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        ...?extra,
      };

  dynamic _decode(http.Response r) {
    if (r.statusCode < 200 || r.statusCode >= 300) {
      String message = r.body;
      try {
        final dynamic j = jsonDecode(r.body);
        if (j is Map) message = (j['message'] ?? j['msg'] ?? j['error_description'] ?? j['error'] ?? r.body).toString();
      } catch (_) {}
      throw SupabaseException(r.statusCode, message);
    }
    if (r.body.isEmpty) return null;
    return jsonDecode(r.body);
  }

  SupabaseSession _sessionFrom(dynamic j) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(j as Map);
    final Map? user = m['user'] as Map?;
    final int? expiresAtSec = (m['expires_at'] as num?)?.toInt();
    final int expiresIn = (m['expires_in'] as num?)?.toInt() ?? 3600;
    return SupabaseSession(
      accessToken: m['access_token'].toString(),
      refreshToken: m['refresh_token'].toString(),
      userId: (user?['id'] ?? '').toString(),
      expiresAt: expiresAtSec != null
          ? DateTime.fromMillisecondsSinceEpoch(expiresAtSec * 1000)
          : DateTime.now().add(Duration(seconds: expiresIn)),
    );
  }

  /// Crea un usuario anónimo (sin correo ni contraseña).
  Future<SupabaseSession> signInAnonymously() async {
    final http.Response r = await _client
        .post(Uri.parse('$url/auth/v1/signup'), headers: _headers(), body: jsonEncode({'data': {}}))
        .timeout(_timeout);
    return _sessionFrom(_decode(r));
  }

  Future<SupabaseSession> refresh(String refreshToken) async {
    final http.Response r = await _client
        .post(
          Uri.parse('$url/auth/v1/token?grant_type=refresh_token'),
          headers: _headers(),
          body: jsonEncode({'refresh_token': refreshToken}),
        )
        .timeout(_timeout);
    return _sessionFrom(_decode(r));
  }

  Future<dynamic> rpc(String function, Map<String, dynamic> args, String token) async {
    final http.Response r = await _client
        .post(Uri.parse('$url/rest/v1/rpc/$function'), headers: _headers(token), body: jsonEncode(args))
        .timeout(_timeout);
    return _decode(r);
  }

  Future<List<dynamic>> select(String table, Map<String, String> query, String token) async {
    final Uri uri = Uri.parse('$url/rest/v1/$table').replace(queryParameters: query);
    final http.Response r = await _client.get(uri, headers: _headers(token)).timeout(_timeout);
    final dynamic data = _decode(r);
    return data is List ? data : const [];
  }

  /// Inserta o actualiza filas (clave de conflicto en [onConflict]).
  Future<void> upsert(String table, List<Map<String, dynamic>> rows, String onConflict, String token) async {
    if (rows.isEmpty) return;
    final Uri uri = Uri.parse('$url/rest/v1/$table').replace(queryParameters: {'on_conflict': onConflict});
    final http.Response r = await _client
        .post(
          uri,
          headers: _headers(token, {'Prefer': 'resolution=merge-duplicates,return=minimal'}),
          body: jsonEncode(rows),
        )
        .timeout(_timeout);
    _decode(r);
  }

  Future<void> delete(String table, Map<String, String> query, String token) async {
    final Uri uri = Uri.parse('$url/rest/v1/$table').replace(queryParameters: query);
    final http.Response r = await _client.delete(uri, headers: _headers(token)).timeout(_timeout);
    _decode(r);
  }
}
