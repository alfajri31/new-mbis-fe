import 'package:flutter/foundation.dart' show kIsWeb;

/// Satu pintu konfigurasi runtime aplikasi (F3 — externalize-config).
///
/// Semua nilai per-environment masuk lewat `--dart-define` (di-set oleh script
/// `scripts/run-*.bat` / `build-apk.bat` dari file `.env` root, atau langsung di CI),
/// BUKAN di-hardcode tersebar di kode. Ganti target environment = ganti nilai
/// `--dart-define`, tanpa mengubah kode.
///
/// Catatan: konfigurasi SSO (`ENTRA_TENANT_ID`, `ENTRA_CLIENT_ID`) untuk sementara
/// masih dibaca di `EntraAuthService`; konsolidasi ke sini menyusul di fase SSO (F7).
class AppConfig {
  const AppConfig._();

  /// Nama environment aktif: `dev` | `staging` | `prod`. `--dart-define=APP_ENV=...`.
  static const String env = String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  static bool get isProd => env == 'prod';

  /// Override base URL API: `--dart-define=API_URL=...`
  /// (dipakai script run-dev/run-app/build-apk untuk HP via adb reverse / target rilis).
  static const String _apiUrlOverride = String.fromEnvironment('API_URL');

  /// Base URL API — SATU sumber (sebelumnya diduplikasi di `ApiClient` & `AuthRepository`).
  /// Resolusi **identik** dengan perilaku lama:
  ///  - bila `API_URL` di-define → pakai itu;
  ///  - selain itu web = same-origin (`''`) karena nginx mem-proxy `/api`;
  ///  - mobile = emulator Android (`http://10.0.2.2:8080`).
  static String get apiBaseUrl {
    if (_apiUrlOverride.isNotEmpty) return _apiUrlOverride;
    return kIsWeb ? '' : 'http://10.0.2.2:8080';
  }
}
