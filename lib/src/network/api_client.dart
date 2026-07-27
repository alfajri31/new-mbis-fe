import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_session.dart';
import '../config/app_config.dart';

class ApiClient {
  /// Global hook invoked whenever any request returns 401 Unauthorized.
  /// Wired in [MbisAppState] to clear the session and return to login.
  static void Function()? onUnauthorized;

  /// Global hook that returns the CURRENT access token before each request,
  /// refreshing the session first when it is about to expire (single-flight,
  /// see [MbisAppState]). Needed because screens construct an [ApiClient] with
  /// a session snapshot — after a background refresh that snapshot's token is
  /// stale. Null (e.g. in tests) falls back to the snapshot token.
  static Future<String?> Function()? tokenProvider;

  /// Global hook returning the access token of the session yang AKTIF sekarang
  /// (tanpa refresh). Dipakai [_check] untuk membedakan 401 dari sesi lama.
  static String? Function()? currentAccessToken;

  final AuthSession? session;
  final http.Client _inner = http.Client();

  ApiClient({this.session});

  /// Guards against a hung TLS connection freezing a screen forever. Uploads get
  /// a longer budget since large files legitimately take longer.
  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _uploadTimeout = Duration(seconds: 120);

  http.Response _check(http.Response response, String? usedToken) {
    if (response.statusCode == 401 && !_isStaleSession(usedToken)) {
      onUnauthorized?.call();
    }
    return response;
  }

  /// True bila 401 ini berasal dari request yang membawa token sesi LAMA —
  /// mis. request yang masih menggantung (server lambat) saat user ke-logout
  /// lalu login ulang, atau token yang baru saja di-refresh. 401 seperti itu
  /// TIDAK boleh menendang sesi baru yang sehat kembali ke halaman login.
  bool _isStaleSession(String? usedToken) {
    final current = currentAccessToken?.call();
    return usedToken != null &&
        current != null &&
        current.isNotEmpty &&
        usedToken != current;
  }

  /// Base URL API — dibaca dari satu pintu [AppConfig] (sebelumnya diduplikasi di sini
  /// dan di AuthRepository). Perilaku resolusi tidak berubah.
  String get baseUrl => AppConfig.apiBaseUrl;

  /// Access token to send: the live one from [tokenProvider] when wired
  /// (already refreshed if it was near expiry), else this client's snapshot.
  Future<String?> _accessToken() async {
    if (session == null || session!.accessToken.isEmpty) return null;
    if (tokenProvider != null) {
      try {
        final fresh = await tokenProvider!();
        if (fresh != null && fresh.isNotEmpty) return fresh;
      } catch (_) {
        // Fall through to the snapshot token; a 401 is handled globally.
      }
    }
    return session!.accessToken;
  }

  Map<String, String> _headersWith(String? token) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// [timeout] opsional untuk request yang memang lama (mis. export xlsx
  /// rentang panjang); default tetap [_timeout] 30 detik.
  Future<http.Response> get(String path, {Duration? timeout}) async {
    final uri = Uri.parse('$baseUrl$path');
    final token = await _accessToken();
    return _check(
        await _inner.get(uri, headers: _headersWith(token)).timeout(timeout ?? _timeout),
        token);
  }

  /// [timeout] opsional untuk operasi batch yang memang lama (mis. pindah RM
  /// / pemindahan cabang yang menyentuh ratusan baris); default [_timeout].
  Future<http.Response> post(String path, {dynamic body, Duration? timeout}) async {
    final uri = Uri.parse('$baseUrl$path');
    final token = await _accessToken();
    return _check(
        await _inner
            .post(uri, headers: _headersWith(token), body: body != null ? jsonEncode(body) : null)
            .timeout(timeout ?? _timeout),
        token);
  }

  /// [timeout] opsional untuk operasi batch yang memang lama (mis. pindah RM
  /// / pemindahan cabang yang menyentuh ratusan baris); default [_timeout].
  Future<http.Response> put(String path, {dynamic body, Duration? timeout}) async {
    final uri = Uri.parse('$baseUrl$path');
    final token = await _accessToken();
    return _check(
        await _inner
            .put(uri, headers: _headersWith(token), body: body != null ? jsonEncode(body) : null)
            .timeout(timeout ?? _timeout),
        token);
  }

  /// [timeout] opsional untuk operasi batch yang memang lama (mis. pindah RM
  /// / pemindahan cabang yang menyentuh ratusan baris); default [_timeout].
  Future<http.Response> delete(String path, {dynamic body, Duration? timeout}) async {
    final uri = Uri.parse('$baseUrl$path');
    final token = await _accessToken();
    return _check(
        await _inner
            .delete(uri, headers: _headersWith(token), body: body != null ? jsonEncode(body) : null)
            .timeout(timeout ?? _timeout),
        token);
  }

  /// Sends a multipart/form-data POST. File bytes are used (instead of a path)
  /// so the same call works on mobile and web. [fileBytes] is optional.
  Future<http.Response> postMultipart(
    String path, {
    Map<String, String> fields = const {},
    String? fileField,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri);
    final token = await _accessToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    if (fileField != null && fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName ?? 'upload',
      ));
    }
    final streamed = await _inner.send(request).timeout(_uploadTimeout);
    return _check(await http.Response.fromStream(streamed), token);
  }

  /// Sends a multipart/form-data PUT (e.g. replacing a stored template file).
  Future<http.Response> putMultipart(
    String path, {
    Map<String, String> fields = const {},
    String? fileField,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('PUT', uri);
    final token = await _accessToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    if (fileField != null && fileBytes != null) {
      request.files.add(http.MultipartFile.fromBytes(
        fileField,
        fileBytes,
        filename: fileName ?? 'upload',
      ));
    }
    final streamed = await _inner.send(request).timeout(_uploadTimeout);
    return _check(await http.Response.fromStream(streamed), token);
  }
}
