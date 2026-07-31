@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tool/policy_html.dart';

/// Menjaga halaman kebijakan HTML di repo backend tetap sama dengan naskah Dart.
///
/// **Kenapa test ini ada.** Naskah kebijakan hidup satu kali, sebagai data
/// terstruktur di `lib/src/legal/`. Aplikasi merendernya untuk versi in-app;
/// backend menyajikan versi HTML-nya sebagai halaman publik (satu-satunya
/// komponen M-BIS yang punya alamat publik di produksi). Berkas HTML itu
/// **turunan**, dibangkitkan `dart run tool/gen_policy_html.dart`.
///
/// Tanpa penjaga ini, revisi Legal berikutnya akan memperbarui versi in-app
/// sementara versi publik diam-diam tertinggal — dan yang tertinggal justru versi
/// yang dibaca reviewer Google dan regulator.
///
/// **Melewat bila repo backend tidak ada di sebelah.** CI meng-checkout satu repo
/// saja, jadi di sana test ini di-skip. Di mesin pengembang (kedua repo
/// bersebelahan di folder umbrella) ia berjalan — dan di situlah naskah diubah.
void main() {
  // Pasangan repo dipilih dari NAMA folder repo ini, bukan "cari yang ada
  // duluan" — keempat repo biasanya bersebelahan, jadi pencarian berurutan akan
  // menunjuk repo yang salah. Lihat folderLegalBackendPerRepo.
  final repo = Directory.current.absolute.path
      .replaceAll('\\', '/')
      .split('/')
      .where((s) => s.isNotEmpty)
      .last;
  final tujuan = folderLegalBackendPerRepo[repo];
  final dir = tujuan == null ? null : Directory(tujuan);

  group('halaman kebijakan HTML di backend', () {
    if (dir == null || !dir.existsSync()) {
      test('dilewati: repo backend pasangan tidak ada di sebelah', () {},
          skip: 'repo "$repo" -> ${tujuan ?? "pasangan tidak terdaftar"}');
      return;
    }

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
              'Perbaiki dengan: dart run tool/gen_policy_html.dart '
              '(lalu commit juga di repo MBIS-backend).',
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
