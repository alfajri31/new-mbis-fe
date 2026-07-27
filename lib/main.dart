import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/providers/app_providers.dart';
import 'src/app.dart';
import 'src/auth/auth_repository.dart';
import 'src/auth/auth_session.dart';
import 'src/notification/push_service.dart';

/// Compile-time flag for the automated screenshot harness. FALSE in every normal
/// build; only a build invoked with `--dart-define=SCREENSHOT_MODE=true` turns the
/// auto-login path below on. Because it's a `bool.fromEnvironment` const, the tree
/// shaker drops `_screenshotAutoLogin` entirely from release builds.
const bool _kScreenshotMode =
    bool.fromEnvironment('SCREENSHOT_MODE', defaultValue: false);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean web URLs (/dashboard, not /#/dashboard). No-op off web.
  usePathUrlStrategy();
  await _initFirebase();
  final sharedPreferences = await SharedPreferences.getInstance();
  final authRepository = AuthRepository(sharedPreferences: sharedPreferences);
  var session = await authRepository.loadSession();
  // Access token pendek (30 menit) sengaja — sesi diperpanjang lewat refresh
  // token 7 hari. Saat app dibuka lagi setelah lama (mis. keesokan hari),
  // tukarkan dulu di sini supaya user tidak dilempar ke login.
  session = await _restoreFreshSession(authRepository, session);

  // Dev-only: the screenshot harness opens URLs like `/dashboard?login=RM001&pw=...`
  // so the web app boots already authenticated at the requested route, bypassing the
  // CanvasKit login form (which a browser driver can't reliably type into). Inert
  // unless the build was compiled with SCREENSHOT_MODE=true.
  if (_kScreenshotMode) {
    session = await _screenshotAutoLogin(authRepository, session);
  }

  // ProviderScope: akar Riverpod (F12). Aditif — transparan bagi kode lama yang
  // belum memakai Riverpod; mengaktifkan modul fitur baru (mis. features/customer).
  runApp(ProviderScope(
    // Seed sesi awal + suntik AuthRepository ke lapisan Riverpod. MbisAppState
    // mendorong perubahan sesi berikutnya ke sessionProvider (lihat _setSession).
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      sessionProvider.overrideWith(() => SessionNotifier(session)),
    ],
    child: MbisApp(
      authRepository: authRepository,
      initialSession: session,
    ),
  ));
}

/// Exchanges an expired/near-expiry access token for a fresh session before the
/// app builds. No refresh token left (or already past its 7 days) -> clear the
/// session and start at login. Refresh REJECTED or unreachable -> keep the old
/// session and let the global 401 handler decide (a network blip recovers; a
/// revoked session lands on /login at the first API call).
Future<AuthSession?> _restoreFreshSession(
    AuthRepository authRepository, AuthSession? session) async {
  if (session == null) return null;
  final exp = session.accessTokenExpiresAt;
  final stillFresh =
      exp == null || DateTime.now().isBefore(exp.subtract(const Duration(minutes: 2)));
  if (stillFresh) return session;
  final refreshToken = session.refreshToken;
  final refreshExp = session.refreshTokenExpiresAt;
  if (refreshToken == null ||
      refreshToken.isEmpty ||
      (refreshExp != null && DateTime.now().isAfter(refreshExp))) {
    await authRepository.clearSession();
    return null;
  }
  try {
    return await authRepository.refresh(refreshToken); // persists itself
  } catch (_) {
    return session;
  }
}

/// Reads `?login=<nip>&pw=<password>` from the boot URL and logs in as that account,
/// clearing any prior session first so the harness can switch roles between runs.
/// Never compiled into a build without SCREENSHOT_MODE=true.
Future<AuthSession?> _screenshotAutoLogin(
    AuthRepository authRepository, AuthSession? existing) async {
  try {
    final query = Uri.base.queryParameters;
    final nip = query['login'];
    final password = query['pw'];
    if (nip == null || nip.isEmpty || password == null || password.isEmpty) {
      return existing;
    }
    // Reuse the session already stored in this browser context (from the first
    // page load) so we hit /api/auth/login only ONCE per context — the endpoint
    // is rate-limited (5/min per IP), and the harness loads dozens of routes.
    // A fresh Playwright context (new role) starts with empty storage, so this
    // still logs in once per role.
    if (existing != null) return existing;
    return await authRepository.login(identifier: nip, password: password);
  } catch (e) {
    debugPrint('Screenshot auto-login failed: $e');
    return existing;
  }
}

/// Best-effort Firebase init. If Firebase isn't configured (missing/placeholder
/// google-services.json), push is simply disabled — the rest of the app still runs.
Future<void> _initFirebase() async {
  if (kIsWeb) return;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init skipped (push disabled): $e');
  }
}
