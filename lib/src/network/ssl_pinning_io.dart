import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'ssl_pinning.dart';

/// Implementasi certificate pinning untuk platform ber-`dart:io` (Android & iOS).
///
/// Penegakannya bertumpu pada `SecurityContext(withTrustedRoots: false)`: root
/// store bawaan sistem (±150 CA publik) DIBUANG untuk host yang dikunci, dan
/// hanya rantai sertifikat yang ikut di dalam aplikasi yang menjadi trust anchor.
/// Sertifikat dari CA mana pun di luar rantai itu ditolak saat handshake TLS,
/// sebelum satu byte permintaan terkirim.
///
/// Yang TIDAK dilakukan di sini: penyempitan tambahan ke satu intermediate
/// tertentu (mis. "issuer harus Sectigo R36"). `package:http` tidak menyediakan
/// kait untuk memeriksa sertifikat peer pada handshake yang berhasil — kait itu
/// hanya ada di `dio` (`validateCertificate`). Dampaknya kecil: membatasi trust
/// anchor ke satu rantai sudah menutup ancaman utama (CA lain menerbitkan
/// sertifikat palsu untuk domain kita). Bila penyempitan itu tetap diinginkan,
/// konsekuensinya menambah dependensi `dio` — keputusan terpisah.
Future<http.Client> createAppHttpClient(SslPinningConfig config) async {
  if (!config.enabled) {
    // Pembungkus diagnostik tetap dipasang meski pinning mati: kegagalan
    // verifikasi sertifikat jauh lebih sering berasal dari sisi server
    // (sertifikat bawaan perangkat, rantai intermediate tidak dikirim) daripada
    // dari pinning, dan justru pada build tanpa pinning-lah pesan mentah
    // `CERTIFICATE_VERIFY_FAILED` paling menyesatkan — terbaca seperti server
    // sedang mati, padahal sertifikatnya yang salah.
    return _TlsDiagnosticClient(inner: http.Client(), pinnedHosts: const {});
  }

  final Uint8List certBytes;
  try {
    final data = await rootBundle.load(config.certAsset);
    certBytes = data.buffer.asUint8List();
  } catch (e) {
    // Gagal-tertutup, dan ini disengaja. Keberadaan aset bersifat deterministik
    // saat build: kalau berkasnya tidak ikut, SETIAP peluncuran build itu gagal
    // di sini — mustahil lolos diam-diam ke pengguna. Sebaliknya, mematikan
    // pinning secara senyap akan menghasilkan build rilis yang tampak normal
    // padahal tanpa perlindungan sama sekali.
    throw StateError(
      'SSL pinning diminta untuk ${config.pinnedHosts.join(", ")} tetapi aset '
      '"${config.certAsset}" tidak dapat dimuat ($e).\n'
      'Pastikan berkas rantai sertifikat ada dan sudah terdaftar pada bagian '
      '`assets:` di pubspec.yaml. Untuk menonaktifkan pinning, kosongkan '
      '--dart-define=SSL_PINNED_HOSTS.',
    );
  }

  final pinnedContext = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificatesBytes(certBytes);

  debugPrint('SSL pinning aktif untuk: ${config.pinnedHosts.join(", ")}');

  return _TlsDiagnosticClient(
    inner: _HostRoutingClient(
      pinnedHosts: config.pinnedHosts,
      pinned: IOClient(HttpClient(context: pinnedContext)),
      fallback: http.Client(),
    ),
    pinnedHosts: config.pinnedHosts,
  );
}

/// Menerjemahkan `HandshakeException` menjadi [TlsTrustException].
///
/// Membungkus, bukan menggantikan, verifikasi TLS: tidak ada sertifikat yang
/// jadi diterima karenanya. Satu-satunya yang berubah adalah bentuk galat yang
/// sampai ke pemanggil — dari teks BoringSSL yang menyebut nomor baris C++
/// menjadi kalimat yang menyebut host, status pinning, dan perintah untuk
/// memeriksanya.
class _TlsDiagnosticClient extends http.BaseClient {
  _TlsDiagnosticClient({required this.inner, required this.pinnedHosts});

  final http.Client inner;
  final Set<String> pinnedHosts;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      return await inner.send(request);
    } on HandshakeException catch (e) {
      final host = request.url.host;
      final failure = TlsTrustException(
        host: host,
        pinned: pinnedHosts.contains(host),
        cause: e,
      );
      // Uraian teknisnya hanya ada di sini: `toString()` sengaja pendek karena
      // langsung tampil di banner login, sedangkan yang memperbaikinya butuh
      // host, status pinning, dan galat BoringSSL aslinya.
      debugPrint(failure.details);
      throw failure;
    }
  }

  @override
  void close() {
    inner.close();
    super.close();
  }
}

/// Merutekan tiap permintaan ke klien yang tepat berdasarkan host tujuan.
///
/// WAJIB per-host. Aplikasi menghubungi `nominatim.openstreetmap.org`,
/// `api.frankfurter.dev`, dan `login.microsoftonline.com` — ketiganya memakai CA
/// publik yang TIDAK ada di rantai Askrindo. Satu klien global dengan trust store
/// terbatas akan mematikan pencarian alamat, kurs, dan SSO sekaligus.
class _HostRoutingClient extends http.BaseClient {
  _HostRoutingClient({
    required this.pinnedHosts,
    required this.pinned,
    required this.fallback,
  });

  // Field sengaja tidak berawalan underscore: kelasnya sendiri sudah privat,
  // sehingga privasi per-field tidak menambah apa pun — sementara named
  // parameter di Dart tidak boleh berawalan underscore, jadi bentuk ini yang
  // memungkinkan initializing formal.
  final Set<String> pinnedHosts;
  final http.Client pinned;
  final http.Client fallback;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // `Uri.host` sudah huruf kecil; pinnedHosts dinormalkan saat konfigurasi
    // dibaca, jadi perbandingannya aman tanpa normalisasi ulang.
    final pinnedForThisHost = pinnedHosts.contains(request.url.host);
    return (pinnedForThisHost ? pinned : fallback).send(request);
  }

  @override
  void close() {
    pinned.close();
    fallback.close();
    super.close();
  }
}
