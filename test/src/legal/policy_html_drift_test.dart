@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/policy_html.dart';

/// Menjaga halaman kebijakan HTML di `web/` tetap sama dengan naskah Dart.
///
/// **Kenapa test ini ada.** Naskah kebijakan hidup satu kali, sebagai data
/// terstruktur di `lib/src/legal/`. Aplikasi merendernya untuk versi in-app;
/// berkas HTML di `web/` adalah **turunan**-nya, dibangkitkan
/// `dart run tool/gen_policy_html.dart`, dan itulah yang dilihat pemeriksa
/// otomatis Google Play — mereka mengambil URL-nya tanpa menjalankan JS/WASM,
/// sehingga versi SPA tampil kosong bagi mereka.
///
/// Tanpa penjaga ini, revisi Legal berikutnya akan memperbarui versi in-app
/// sementara versi publik diam-diam tertinggal — dan yang tertinggal justru versi
/// yang dibaca reviewer Google dan regulator.
///
/// **Selalu berjalan.** Dulu test ini di-skip di CI karena berkasnya ada di repo
/// backend tetangga yang tidak ikut ter-checkout. Sejak keluarannya pindah ke
/// `web/` repo ini, tidak ada lagi alasan melewat — dan justru CI-lah tempat
/// penjaga ini paling berguna.
void main() {
  final dir = Directory(folderKeluaranWeb);

  group('halaman kebijakan HTML di web/', () {
    test('folder keluaran ada', () {
      expect(dir.existsSync(), isTrue,
          reason: 'Folder "$folderKeluaranWeb/" tidak ditemukan dari '
              '${Directory.current.absolute.path}. Test harus dijalankan dari '
              'akar repo.');
    });

    renderSemuaHalaman().forEach((rute, html) {
      final nama = berkasKeluaran[rute]!;

      test('$nama sama dengan hasil render naskah Dart', () {
        final berkas = File('${dir.path}/$nama');

        expect(
          berkas.existsSync(),
          isTrue,
          reason: '$nama belum pernah dibangkitkan. '
              'Jalankan: dart run tool/gen_policy_html.dart',
        );

        expect(
          berkas.readAsStringSync(),
          html,
          reason: 'Halaman publik $nama tidak lagi sama dengan naskah Dart.\n'
              'Naskah berubah tanpa membangkitkan ulang HTML-nya, atau HTML-nya '
              'diedit tangan.\n'
              'Perbaiki dengan: dart run tool/gen_policy_html.dart',
        );
      });
    });

    test('naskah yang wajib ada ikut terbawa ke HTML publik', () {
      // Bukan sekadar "berkasnya sama": kalau renderer diam-diam menjatuhkan
      // sebuah jenis blok, kedua sisi tetap sama tapi sama-sama salah.
      final html = renderKebijakanPrivasiHtml();

      expect(html, contains('Kebijakan Privasi M-BIS'));
      expect(html, contains('PT Asuransi Kredit Indonesia (Persero)'));
      expect(html, contains('Pengendali Data'));
      // Tabel, daftar, dan kotak sorot dipakai naskahnya — pastikan terender.
      expect(html, contains('<table>'));
      expect(html, contains('<li>'));
      expect(html, contains('class="callout'));
      // Tautan silang ke halaman hapus akun (kebijakan bagian 11).
      expect(html, contains('href="hapus-akun"'));
    });

    test('karakter khas HTML di naskah di-escape, bukan bocor sebagai markup', () {
      // Naskahnya memuat & dan tanda kutip. Satu karakter tak ter-escape bisa
      // merusak sisa dokumen pada halaman yang dibaca regulator.
      final html = renderPolicyHtml(
        pageTitle: 'Uji',
        documentTitle: 'Uji <script>alert(1)</script>',
        subtitle: 'A & B',
        meta: const [],
        banner: null,
        sections: const [],
      );

      expect(html, isNot(contains('<script>alert(1)</script>')));
      expect(html, contains('&lt;script&gt;'));
      expect(html, contains('A &amp; B'));
    });
  });
}
