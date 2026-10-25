import 'package:http/http.dart' as http;
import '../dev_tools/http_activity_client.dart';

import 'ssl_pinning_stub.dart'
    if (dart.library.io) 'ssl_pinning_io.dart' as impl;

/// Certificate pinning untuk API M-BIS.
///
/// ## Status: menyala untuk build yang menuju `askrindo.co.id`
///
/// Pinning aktif bila [SslPinningConfig.pinnedHosts] diisi lewat `--dart-define`.
/// `scripts/build-apk.*`, `scripts/build-aab.*`, dan `codemagic.yaml` mengisinya
/// otomatis dari host `API_URL`, terbatas pada domain `askrindo.co.id`. Build lain
/// (dev terhadap backend lokal, staging non-Askrindo) tetap memakai trust store
/// sistem tanpa perubahan perilaku.
///
/// ## Kenapa ini bukan sekadar pengerasan keamanan
///
/// `mbis.askrindo.co.id` mengirim sertifikat **leaf saja** — intermediate Sectigo
/// R36 dan R46 tidak ikut. Browser, `curl`, dan Secure Transport menutupi itu
/// dengan menjemput issuer lewat AIA; Dart/BoringSSL tidak. Jadi build tanpa
/// rantai bundled gagal `CERTIFICATE_VERIFY_FAILED: unable to get local issuer
/// certificate` sejak layar login, sementara `curl` dari laptop yang sama
/// terlihat sehat — kombinasi yang sangat mudah salah dibaca sebagai "server
/// gangguan". Rantai di `assets/ssl` memasok intermediate yang hilang itu.
///
/// Selama server belum dikonfigurasi mengirim fullchain, mematikan pinning berarti
/// mematikan aplikasi. Rinciannya di `assets/ssl/README.md`.
///
/// ## Harga yang dibayar
///
/// Sertifikat leaf berlaku sampai 10 April 2027. Sesudah diperpanjang, aplikasi
/// terpasang yang mem-pin berkas lama tidak dapat terhubung sampai pengguna
/// memperbarui — jadwalkan rilis pengganti sebelum tanggal itu, atau minta server
/// mengirim fullchain lebih dulu supaya ketergantungan ini hilang.
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
/// Kegagalan verifikasi sertifikat TLS, sudah diterjemahkan jadi pesan yang bisa
/// ditindaklanjuti.
///
/// `HandshakeException` mentah dari `dart:io` berbunyi seperti
/// `Handshake error in client (OS Error: CERTIFICATE_VERIFY_FAILED: self signed
/// certificate(handshake.cc:393))` — bagi pengguna maupun pelapor bug, itu tidak
/// membedakan "server salah pasang sertifikat", "pinning ke berkas yang keliru",
/// dan "jaringan disadap". Ketiganya butuh penanganan berbeda, jadi jalur ini
/// menyimpan host tujuan dan status pinning agar laporan langsung menunjuk
/// penyebabnya.
///
/// Kasus nyata yang memunculkan kelas ini: `mbis.askrindo.co.id` mengirim
/// sertifikat leaf tanpa intermediate Sectigo, sehingga build tanpa rantai
/// bundled gagal merangkai sertifikat — sementara `curl` di laptop yang sama
/// lancar karena OS menjemput issuer lewat AIA. Gejalanya terbaca seperti "server
/// gangguan" padahal server sehat, dan waktu terbuang mencari di tempat yang
/// salah. Kelas ini membuat penyebabnya tertulis di pesan galatnya sendiri.
class TlsTrustException implements Exception {
  const TlsTrustException({
    required this.host,
    required this.pinned,
    required this.cause,
  });

  /// Host yang sertifikatnya ditolak.
  final String host;

  /// True bila host ini memakai trust store terbatas (pinning aktif). Membedakan
  /// "sertifikat server memang tidak tepercaya" dari "berkas pin sudah usang".
  final bool pinned;

  /// Galat asli, dipertahankan utuh untuk log dan laporan bug.
  final Object cause;

  /// Pesan untuk layar. Sengaja pendek: `login_screen.dart` menaruh
  /// `e.toString()` apa adanya di banner error, dan paragraf teknis di sana tidak
  /// terbaca. Yang perlu diketahui pengguna hanya bahwa ini masalah sertifikat
  /// server — bukan salah kata sandi, dan bukan sesuatu yang bisa mereka
  /// perbaiki dengan mencoba ulang.
  @override
  String toString() =>
      'Koneksi aman ke $host gagal: sertifikat server tidak tepercaya. '
      'Hubungi tim infrastruktur — bukan masalah akun atau kata sandi.';

  /// Uraian lengkap untuk log, laporan bug, dan `debugPrint`.
  ///
  /// Terpisah dari [toString] karena pembacanya berbeda: yang ini menyebut
  /// hipotesis penyebab dan perintah verifikasinya, dan hanya berguna bagi orang
  /// yang bisa menindaklanjutinya.
  String get details {
    final sebab = pinned
        ? 'Sertifikat $host tidak cocok dengan rantai yang dikunci di aplikasi. '
              'Kemungkinan sertifikat server sudah diperpanjang/diganti sementara '
              'berkas di assets/ssl belum diperbarui, atau host ini menyajikan '
              'sertifikat berbeda dari dalam jaringan kantor (split-horizon DNS).'
        : 'Sertifikat $host tidak tepercaya menurut CA sistem. Umumnya server '
              'menyajikan sertifikat self-signed / bawaan perangkat (mis. cert '
              'pabrikan pada WAF atau load balancer), atau rantai intermediate '
              'tidak ikut dikirim.';
    return 'TlsTrustException: koneksi aman ke $host gagal. $sebab '
        'Verifikasi dengan: openssl s_client -servername $host -connect $host:443 '
        '</dev/null | openssl x509 -noout -subject -issuer -dates. '
        'Galat asli: $cause';
  }
}

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

    final client = await impl.createAppHttpClient(cfg);

    _instance = HttpActivityClient(client);
  }

  /// Hanya untuk pengujian.
  static void overrideForTest(http.Client client) => _instance = client;

  /// Hanya untuk pengujian.
  static void resetForTest() => _instance = null;
}
