import 'dart:convert';

import '../config/app_config.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../network/ssl_pinning.dart';
import 'auth_session.dart';
import 'session_store.dart';

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
    http.Client? httpClient,
    SessionStore? sessionStore,
  })  : _sessionStore = sessionStore ??
            createSessionStore(
              preferences: sharedPreferences,
              secureStorage: secureStorage ?? const FlutterSecureStorage(),
            ),
        _http = httpClient ?? AppHttpClient.instance;

  final SharedPreferences sharedPreferences;

  /// Penyimpanan sesi. Bukan `FlutterSecureStorage` langsung: di web pada origin HTTP
  /// polos paket itu melempar `only works in secure contexts`, sehingga pemilihan
  /// implementasinya dipusatkan di [createSessionStore] — termasuk pagar yang mencegah
  /// build prod ikut memakai jalur fallback-nya.
  final SessionStore _sessionStore;

  /// Klien bersama dari [AppHttpClient] — BUKAN fungsi `http.post` tingkat-atas.
  ///
  /// `http.post` membuat `Client` sekali pakai sendiri, sehingga tidak pernah
  /// melewati `_HostRoutingClient` dan certificate pinning TIDAK berlaku di sana.
  /// Kelas ini justru memegang tiga panggilan paling sensitif — login (kata sandi),
  /// tukar id_token Entra, dan refresh token — jadi memakai `http.post` di sini
  /// berarti build yang tampak "pinning aktif" sebenarnya membiarkan kredensial
  /// lewat jalur tanpa proteksi, tanpa error dan tanpa tes merah.
  ///
  /// [AppHttpClient.initialize] sudah selesai sebelum kelas ini dibuat
  /// (`main.dart` menunggunya di `Future.wait` sebelum `AuthRepository(...)`),
  /// jadi field ini menangkap klien yang sudah ter-pin, bukan yang polos.
  final http.Client _http;

  // Base URL dari satu pintu [AppConfig] (sebelumnya diduplikasi di sini & ApiClient).
  Uri _endpoint(String path) => Uri.parse('${AppConfig.apiBaseUrl}/api/auth$path');

  Future<AuthSession?> loadSession() async {
    // Migrasi dari build lama yang menyimpan sesi sebagai teks biasa kini ditangani
    // SecureSessionStore.read().
    final raw = await _sessionStore.read();
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return AuthSession.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(AuthSession session) async {
    await _sessionStore.write(jsonEncode(session.toJson()));
  }

  Future<void> clearSession() async {
    await _sessionStore.delete();
  }

  Future<AuthSession> login({required String identifier, required String password}) async {
    final response = await _http.post(
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
    final response = await _http.post(
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
    final response = await _http
        .post(
          _endpoint('/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        )
        .timeout(timeout);
    return _handleAuthResponse(response);
  }

  Future<void> logout(String refreshToken) async {
    final response = await _http.post(
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
