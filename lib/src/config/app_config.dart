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
  /// Resolusi:
  ///  - bila `API_URL` di-define → pakai itu (garis miring di akhir dibuang);
  ///  - selain itu web = same-origin (`''`) karena nginx mem-proxy `/api`;
  ///  - mobile = emulator Android (`http://10.0.2.2:8080`).
  ///
  /// Nilainya boleh memuat **path**, bukan hanya host. Prod menaruh backend di bawah
  /// prefix `/v2` (`https://mbis.askrindo.co.id/v2`) karena domain itu dibagi beberapa
  /// aplikasi; seluruh kode fitur menempelkan path root-absolute (`/api/customers`) di
  /// belakangnya, jadi tidak ada satu pun file fitur yang perlu diubah.
  ///
  /// Web prod TIDAK boleh lagi mengandalkan same-origin: bundle-nya dilayani terpisah
  /// (IP privat) dari API, jadi `API_URL` wajib diisi saat build web prod — lihat
  /// `Dockerfile` dan `docs/MIGRASI-DOMAIN-PROD-V2.md`. Staging tetap same-origin.
  static String get apiBaseUrl {
    if (_apiUrlOverride.isNotEmpty) return _stripTrailingSlash(_apiUrlOverride);
    return kIsWeb ? '' : 'http://10.0.2.2:8080';
  }

  /// Buang garis miring di akhir supaya `.../v2/` + `/api/x` tidak jadi `.../v2//api/x`.
  /// Sebagian server memperlakukan `//` sebagai path lain dan membalas 404 — kesalahan
  /// ketik yang gampang terjadi begitu base URL memuat path, dan mahal didiagnosis.
  static String _stripTrailingSlash(String url) {
    var result = url;
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }

  /// URL kebijakan privasi. `--dart-define=PRIVACY_POLICY_URL=...`
  ///
  /// Google Play mewajibkan tautan kebijakan privasi **dapat dibuka dari dalam
  /// aplikasi**, bukan hanya dari halaman store. Nilainya tidak di-hardcode
  /// karena URL final ditentukan legal/korporat; `scripts/build-aab.*` menolak
  /// membangun rilis prod kalau nilai ini kosong.
  static const String privacyPolicyUrl =
      String.fromEnvironment('PRIVACY_POLICY_URL');

  /// URL halaman permintaan penghapusan akun. `--dart-define=ACCOUNT_DELETION_URL=...`
  ///
  /// Play mensyaratkan halaman ini bisa diakses **tanpa memasang aplikasi**, dan
  /// URL-nya dilampirkan di Data safety form. Akun M-BIS dibuat oleh admin (tidak
  /// ada pendaftaran mandiri), sehingga alurnya berupa *permintaan* penghapusan —
  /// lihat layar Privasi & Akun.
  static const String accountDeletionUrl =
      String.fromEnvironment('ACCOUNT_DELETION_URL');

  /// Alamat email unit yang memproses permintaan penghapusan akun & pertanyaan
  /// privasi. `--dart-define=PRIVACY_CONTACT_EMAIL=...`
  static const String privacyContactEmail =
      String.fromEnvironment('PRIVACY_CONTACT_EMAIL');
}
