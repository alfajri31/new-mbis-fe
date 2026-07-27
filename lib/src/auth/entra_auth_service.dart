import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// The actual "open Microsoft and capture the redirect" step is platform-specific.
// On web it uses package:web (WASM-safe); on native it's not wired yet (see stub).
import 'entra_authenticator_stub.dart'
    if (dart.library.js_interop) 'entra_authenticator_web.dart';

/// Drives the Microsoft Entra ID (Azure AD) sign-in and returns an OIDC `id_token`
/// that the backend then verifies and exchanges for an MBIS session.
///
/// Uses the Authorization Code + PKCE flow (public client — no secret on the
/// browser), the same model MSAL uses. Deliberately CDN-free and WASM-safe: the
/// browser interaction goes through package:web and the token exchange is a plain
/// HTTPS POST, so nothing extra is fetched from a third-party host at runtime.
///
/// Configuration comes from `--dart-define` (public values, safe to ship):
///   ENTRA_TENANT_ID    Directory (tenant) ID from the IT App Registration
///   ENTRA_CLIENT_ID    Application (client) ID
class EntraAuthService {
  static const String tenantId = String.fromEnvironment('ENTRA_TENANT_ID');
  static const String clientId = String.fromEnvironment('ENTRA_CLIENT_ID');

  static const String _scope = 'openid profile email offline_access';

  /// The Microsoft button only appears when a tenant + client id are present, so a
  /// build without SSO configured simply falls back to local login.
  static bool get isConfigured => tenantId.isNotEmpty && clientId.isNotEmpty;

  /// SSO is currently wired for web only; native (Android/iOS) sign-in still needs a
  /// deep-link handler and is deferred, so the button is hidden there for now.
  static bool get isSupportedPlatform => kIsWeb;

  String get _authorizeUrl =>
      'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize';
  String get _tokenUrl =>
      'https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token';

  // Web always redirects the sign-in popup to <origin>/auth.html, which posts the
  // result back to the app. Register this exact URL as a "SPA" redirect in Entra.
  String get _redirectUri => '${Uri.base.origin}/auth.html';

  /// Opens Microsoft sign-in and returns the OIDC id_token. Returns `null` when the
  /// user cancels/closes the window. Throws [Exception] on a real failure.
  Future<String?> signIn() async {
    if (!isConfigured) {
      throw Exception('SSO Microsoft belum dikonfigurasi.');
    }

    final verifier = _randomString(64);
    final challenge = _codeChallenge(verifier);
    final state = _randomString(24);

    final authUrl = Uri.parse(_authorizeUrl).replace(queryParameters: {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUri,
      'response_mode': 'query',
      'scope': _scope,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
      'state': state,
      'prompt': 'select_account',
    }).toString();

    // Returns the full callback URL (…/auth.html?code=…&state=…), or null if cancelled.
    final callback = await openEntraAuthWindow(authUrl, _redirectUri);
    if (callback == null) return null;

    final params = Uri.parse(callback).queryParameters;
    if (params['state'] != state) {
      throw Exception('SSO gagal: state tidak cocok (kemungkinan diretas).');
    }
    final error = params['error_description'] ?? params['error'];
    if (error != null && error.isNotEmpty) {
      throw Exception('SSO gagal: $error');
    }
    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw Exception('SSO gagal: kode otorisasi tidak diterima.');
    }

    // Public-client PKCE token exchange: no client_secret. On web this succeeds only
    // when IT registers the redirect URI as a "SPA" platform (Microsoft enables CORS
    // on the token endpoint for SPA redirects).
    final tokenResp = await http.post(
      Uri.parse(_tokenUrl),
      body: {
        'client_id': clientId,
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'code_verifier': verifier,
        'scope': _scope,
      },
    );
    if (tokenResp.statusCode != 200) {
      throw Exception('SSO gagal menukar token (${tokenResp.statusCode}).');
    }
    final body = jsonDecode(tokenResp.body) as Map<String, dynamic>;
    final idToken = body['id_token'] as String?;
    if (idToken == null || idToken.isEmpty) {
      throw Exception('SSO gagal: id_token tidak ada pada respons.');
    }
    return idToken;
  }

  String _randomString(int length) {
    // RFC 7636 unreserved characters for the code verifier / state.
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _codeChallenge(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
