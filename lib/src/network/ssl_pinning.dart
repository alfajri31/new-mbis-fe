import 'package:http/http.dart' as http;

import 'ssl_pinning_stub.dart'
    if (dart.library.io) 'ssl_pinning_io.dart' as impl;

/// Certificate pinning untuk API M-BIS.
///
/// ## Status: KERANGKA — nonaktif secara bawaan
///
/// Belum ada domain maupun berkas sertifikat yang dikunci. Pinning baru menyala
/// bila [SslPinningConfig.pinnedHosts] diisi lewat `--dart-define`. Tanpa itu,
/// [createAppHttpClient] mengembalikan `http.Client()` biasa dan perilaku
/// aplikasi sama persis seperti sebelum berkas ini ada.
///
/// ## Kenapa opt-in, bukan langsung menyala
///
/// Sertifikat staging (Coolify) dan produksi (server internal) BERBEDA, dan
/// domain produksi belum ditetapkan. Mengunci sekarang berarti mengunci ke
/// target yang masih bergerak — begitu endpoint berpindah, aplikasi yang sudah
/// terpasang di HP pengguna tidak bisa lagi terhubung sampai mereka memperbarui.
/// Karena itu penyalaannya ditunda sampai TLS produksi final.
///
/// ## Yang dilindungi dan yang tidak
///
/// - **Android & iOS** — dilindungi saat dinyalakan.
/// - **Web** — TIDAK dan tidak akan pernah. `dart:io` tak tersedia di browser,
///   dan TLS sepenuhnya dikendalikan browser. Bukan keterbatasan Flutter: HPKP
///   (pinning versi web) sengaja dihapus Chrome pada 2018 karena terlalu banyak
///   situs mengunci diri sendiri. Padanan web-nya adalah CAA record + Certificate
///   Transparency monitoring + HSTS, yang semuanya berada di luar repo ini.
///
/// ## Pinning bersifat PER-HOST — ini wajib
///
/// Aplikasi menghubungi empat pihak, tiga di antaranya bukan milik Askrindo:
/// `nominatim.openstreetmap.org` (pencarian alamat), `api.frankfurter.dev`
/// (kurs), dan `login.microsoftonline.com` (SSO). Mengganti trust store secara
/// global akan mematikan ketiganya. [createAppHttpClient] karena itu merutekan
/// per host: hanya host yang terdaftar memakai trust store terbatas, sisanya
/// memakai CA bawaan sistem.
class SslPinningConfig {
  const SslPinningConfig({
    required this.pinnedHosts,
    required this.certAsset,
  });

  /// Host yang trust store-nya dipersempit ke [certAsset].
  ///
  /// Diisi lewat `--dart-define=SSL_PINNED_HOSTS=host1,host2`. Kosong = pinning
  /// mati. Sengaja berupa daftar, bukan satu nilai, karena staging dan produksi
  /// memakai domain berbeda dan satu build (mis. staging) bisa perlu keduanya.
  final Set<String> pinnedHosts;

  /// Lintasan aset rantai sertifikat (PEM, fullchain).
  ///
  /// Dapat diganti lewat `--dart-define=SSL_CERT_ASSET=...` supaya build staging
  /// dan produksi bisa membawa berkas berbeda tanpa mengubah kode.
  ///
  /// Nilai bawaan menunjuk berkas produksi. Perhatikan namanya memuat rentang
  /// tahun: saat sertifikat diperpanjang, berkas baru akan bernama lain, sehingga
  /// nilai bawaan ini HARUS ikut diperbarui — atau lintasannya ditimpa lewat
  /// dart-define. Kelalaian pada titik ini menyebabkan build gagal saat start,
  /// bukan diam-diam berjalan tanpa proteksi (lihat `AppHttpClient.initialize`).
  final String certAsset;

  static const String _hostsRaw = String.fromEnvironment('SSL_PINNED_HOSTS');
  static const String _assetRaw = String.fromEnvironment(
    'SSL_CERT_ASSET',
    defaultValue: 'assets/ssl/askrindo-fullchain-2026-2027.crt',
  );

  /// Konfigurasi dari `--dart-define`. Host dipisah koma, spasi diabaikan,
  /// dan dinormalkan ke huruf kecil agar cocok dengan `Uri.host`.
  factory SslPinningConfig.fromEnvironment() => SslPinningConfig(
    pinnedHosts: _hostsRaw
        .split(',')
        .map((h) => h.trim().toLowerCase())
        .where((h) => h.isNotEmpty)
        .toSet(),
    certAsset: _assetRaw,
  );

  bool get enabled => pinnedHosts.isNotEmpty;

  @override
  String toString() => enabled
      ? 'SslPinningConfig(hosts: ${pinnedHosts.join(", ")}, asset: $certAsset)'
      : 'SslPinningConfig(nonaktif)';
}

/// Klien HTTP tunggal untuk seluruh aplikasi.
///
/// Panggil [initialize] SEKALI sebelum `runApp()`, lalu pakai [instance] di
/// mana pun `http.Client` dibutuhkan. Satu klien dipakai bersama supaya
/// connection pool TLS tidak dibangun ulang per layar — sekaligus supaya
/// pinning berlaku menyeluruh, bukan hanya di kelas yang kebetulan diperbarui.
class AppHttpClient {
  AppHttpClient._();

  static http.Client? _instance;

  /// Klien bersama. Sebelum [initialize] dipanggil, mengembalikan klien biasa
  /// agar kode lama (dan test) tetap berfungsi tanpa inisialisasi eksplisit.
  static http.Client get instance => _instance ??= http.Client();

  /// Menyiapkan klien sesuai [config].
  ///
  /// Melempar [StateError] bila pinning diminta tetapi aset sertifikat tidak
  /// dapat dimuat. Ini DISENGAJA gagal-tertutup: keberadaan aset bersifat
  /// deterministik saat build, jadi kesalahan ini pasti terlihat pada percobaan
  /// pertama build mana pun dan tidak mungkin lolos diam-diam ke pengguna.
  /// Membiarkannya gagal-terbuka justru berbahaya — build rilis akan terlihat
  /// normal padahal perlindungannya tidak ada.
  static Future<void> initialize([SslPinningConfig? config]) async {
    final cfg = config ?? SslPinningConfig.fromEnvironment();
    _instance = await impl.createAppHttpClient(cfg);
  }

  /// Hanya untuk pengujian.
  static void overrideForTest(http.Client client) => _instance = client;

  /// Hanya untuk pengujian.
  static void resetForTest() => _instance = null;
}
