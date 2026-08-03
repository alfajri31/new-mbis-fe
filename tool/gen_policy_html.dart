/// Membangkitkan halaman kebijakan HTML ke folder `web/` repo ini.
///
/// Jalankan dari akar repo setiap kali naskah di `lib/src/legal/` berubah:
///
///     dart run tool/gen_policy_html.dart
///
/// Tambahkan `--check` untuk memeriksa tanpa menulis (dipakai saat ingin tahu
/// apakah ada yang belum dibangkitkan ulang; drift test melakukan hal setara).
///
/// Keluarannya masuk ke `web/`, ikut tersalin oleh `flutter build web` ke
/// `build/web/`, lalu disajikan nginx sebagai halaman publik — lihat blok
/// `location = /kebijakan-privasi` di `nginx.conf`. Halaman ini wajib berupa HTML
/// jadi karena pemeriksa otomatis Google Play mengambilnya tanpa menjalankan
/// JS/WASM; alasan lengkapnya di `tool/policy_html.dart`.
///
/// Sebelum 3 Agustus 2026 keluarannya menyeberang ke repo backend. Sejak web
/// punya alamat publik sendiri (`https://mbis.askrindo.co.id/app/`), halamannya
/// pulang ke repo ini dan perintah ini tidak lagi bergantung pada repo tetangga.
library;

import 'dart:io';

import 'policy_html.dart';

void main(List<String> args) {
  final cek = args.contains('--check');

  // Gagal-cepat kalau dijalankan dari folder yang salah. Tanpa ini perintahnya
  // akan dengan senang hati membuat `web/` di sembarang tempat lalu melaporkan
  // sukses, dan berkas yang dibangkitkan tidak pernah sampai ke bundel.
  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln(
      'Jalankan dari AKAR repo frontend (tempat pubspec.yaml berada).\n'
      'Sekarang di: ${Directory.current.absolute.path}',
    );
    exit(2);
  }

  final dir = Directory(folderKeluaranWeb);
  if (!dir.existsSync()) {
    stderr.writeln(
      'Folder "$folderKeluaranWeb/" tidak ada di repo ini. '
      'Itu folder bawaan target web Flutter — kalau benar-benar hilang, '
      'jalankan: flutter create --platforms=web .',
    );
    exit(2);
  }
  stdout.writeln('Menulis ke: ${dir.absolute.path}');

  var berubah = 0;
  renderSemuaHalaman().forEach((rute, html) {
    final berkas = File('${dir.path}/${berkasKeluaran[rute]}');
    final lama = berkas.existsSync() ? berkas.readAsStringSync() : null;

    if (lama == html) {
      stdout.writeln('  sama    ${berkas.path}');
      return;
    }
    berubah++;
    if (cek) {
      stdout.writeln('  BEDA    ${berkas.path}');
    } else {
      berkas.writeAsStringSync(html);
      stdout.writeln('  ditulis ${berkas.path} (${html.length} char)');
    }
  });

  if (cek && berubah > 0) {
    stderr.writeln(
      '\n$berubah berkas tidak sinkron dengan naskah Dart.\n'
      'Jalankan: dart run tool/gen_policy_html.dart',
    );
    exit(1);
  }
  stdout.writeln(berubah == 0
      ? '\nSemua halaman sudah sinkron.'
      : '\n$berubah halaman diperbarui. Commit juga berkas di web/.');
}
