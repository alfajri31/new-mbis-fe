import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ssl_pinning.dart';

/// Implementasi untuk platform TANPA `dart:io` — dalam praktiknya: Flutter Web.
///
/// Certificate pinning tidak mungkin di browser. `SecurityContext` dan
/// `HttpClient` berasal dari `dart:io` yang tidak tersedia, dan verifikasi TLS
/// sepenuhnya dikendalikan browser tanpa titik sisip untuk aplikasi.
///
/// Ini bukan celah yang bisa ditutup dari sisi kode. Padanan perlindungannya di
/// web berada di lapis DNS dan server:
///   - **CAA record** — membatasi CA mana yang boleh menerbitkan sertifikat untuk
///     domain Askrindo. Melindungi web DAN mobile sekaligus, tanpa perlu rilis
///     aplikasi dan tanpa tanggal kedaluwarsa.
///   - **Certificate Transparency monitoring** — peringatan bila ada sertifikat
///     diterbitkan untuk domain Askrindo tanpa izin.
///   - **HSTS** — memaksa HTTPS sehingga koneksi tak bisa diturunkan ke HTTP.
///
/// Berkas ini sengaja mengembalikan klien biasa, bukan melempar galat: build web
/// harus tetap berjalan normal walau `SSL_PINNED_HOSTS` diisi (satu perintah
/// build sering memakai dart-define yang sama untuk semua target).
Future<http.Client> createAppHttpClient(SslPinningConfig config) async {
  if (config.enabled) {
    debugPrint(
      'SSL pinning dilewati: tidak didukung di web. '
      'Perlindungan setara ditangani CAA record, Certificate Transparency, dan HSTS.',
    );
  }
  return http.Client();
}
