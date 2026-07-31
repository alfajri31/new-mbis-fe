import 'dart:convert';

import '../config/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_session.dart';

/// The verified Microsoft account has no MBIS mapping yet and has been queued for
/// admin review (backend returns HTTP 202). The login screen shows a "waiting for
/// approval" state rather than a hard error.
class EntraPendingException implements Exception {
  EntraPendingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// An admin has explicitly denied this Microsoft account (backend returns HTTP 403).
class EntraDeniedException implements Exception {
  EntraDeniedException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository({
    required this.sharedPreferences,
    FlutterSecureStorage? secureStorage,
  }) : secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _sessionKey = 'mbis.auth.session';
  final SharedPreferences sharedPreferences;
  final FlutterSecureStorage secureStorage;

  // Base URL dari satu pintu [AppConfig] (sebelumnya diduplikasi di sini & ApiClient).
  Uri _endpoint(String path) => Uri.parse('${AppConfig.apiBaseUrl}/api/auth$path');

  Future<AuthSession?> loadSession() async {
    var raw = await secureStorage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) {
      // Migrasi sekali jalan: build lama menyimpan sesi (termasuk refresh token)
      // sebagai teks biasa di SharedPreferences. Pindahkan ke secure storage lalu
      // hapus salinan plaintext-nya, tanpa memaksa user login ulang.
      final legacy = sharedPreferences.getString(_sessionKey);
      if (legacy == null || legacy.isEmpty) return null;
      await secureStorage.write(key: _sessionKey, value: legacy);
      await sharedPreferences.remove(_sessionKey);
      raw = legacy;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AuthSession.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(AuthSession session) async {
    final raw = jsonEncode(session.toJson());
    await secureStorage.write(key: _sessionKey, value: raw);
  }

  Future<void> clearSession() async {
    await secureStorage.delete(key: _sessionKey);
    // Defensif: bersihkan juga sisa salinan plaintext dari build lama.
    await sharedPreferences.remove(_sessionKey);
  }

  Future<AuthSession> login({required String identifier, required String password}) async {
    final response = await http.post(
      _endpoint('/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'identifier': identifier, 'password': password}),
    );
    return _handleAuthResponse(response);
  }

  /// Exchanges a Microsoft OIDC id_token for an MBIS session. Distinguishes the
  /// two "not a hard error" outcomes so the UI can react: 202 -> queued for admin
  /// ([EntraPendingException]); 403 -> denied by admin ([EntraDeniedException]).
  Future<AuthSession> exchangeEntra(String idToken) async {
    final response = await http.post(
      _endpoint('/entra/exchange'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );
    if (response.statusCode == 202) {
      throw EntraPendingException(_extractMessage(response));
    }
    if (response.statusCode == 403) {
      throw EntraDeniedException(_extractMessage(response));
    }
    return _handleAuthResponse(response);
  }

  /// Batas waktu default, disamakan dengan [ApiClient] (30 detik) supaya perilaku
  /// jaringan seragam di seluruh aplikasi.
  static const Duration _refreshTimeout = Duration(seconds: 30);

  /// [timeout] bisa dipersingkat oleh pemanggil yang berada di JALUR KRITIS startup
  /// (lihat `main.dart`): di sana `http.post` tanpa batas waktu menahan `runApp()`,
  /// sehingga sinyal yang "nyangkut" (TCP menggantung, bukan gagal) membuat layar
  /// kosong sampai timeout OS — dan di iOS berisiko dibunuh watchdog peluncuran.
  Future<AuthSession> refresh(String refreshToken,
      {Duration timeout = _refreshTimeout}) async {
    final response = await http
        .post(
          _endpoint('/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(timeout);
    return _handleAuthResponse(response);
  }

  Future<void> logout(String refreshToken) async {
    final response = await http.post(
      _endpoint('/logout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );
    if (response.statusCode >= 400) {
      throw Exception(_extractMessage(response));
    }
  }

  Future<AuthSession> _handleAuthResponse(http.Response response) async {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractMessage(response));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final session = AuthSession.fromJson(decoded);
    await saveSession(session);
    return session;
  }

  String _extractMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['message']?.toString() ?? 'Request failed';
    } catch (_) {
      return 'Request failed (${response.statusCode})';
    }
  }
}
