/// Membangkitkan halaman kebijakan HTML ke repo backend.
///
/// Jalankan dari folder MBIS-Frontend setiap kali naskah di `lib/src/legal/`
/// berubah:
///
///     dart run tool/gen_policy_html.dart
///
/// Keluarannya masuk ke repo TETANGGA (MBIS-backend), yang menyajikannya sebagai
/// halaman publik — lihat `LegalPageController` di sana. Backend adalah satu-satunya
/// komponen M-BIS yang punya alamat publik di topologi prod, sementara Google
/// mensyaratkan kebijakan privasi & jalur hapus akun dapat dibuka tanpa memasang
/// aplikasi.
///
/// Kalau repo backend tidak ada di sebelah, perintah ini berhenti dengan pesan
/// jelas alih-alih diam-diam tidak menulis apa pun.
library;

import 'dart:io';

import 'policy_html.dart';

/// Nama folder repo tempat perintah ini dijalankan, dipakai memilih pasangan
/// backend yang benar (lihat [folderLegalBackendPerRepo]).
String namaRepoIni() =>
    Directory.current.absolute.path.replaceAll('\\', '/').split('/').where((s) => s.isNotEmpty).last;

void main(List<String> args) {
  final cek = args.contains('--check');
  final repo = namaRepoIni();
  final tujuan = folderLegalBackendPerRepo[repo];

  if (tujuan == null) {
    stderr.writeln(
      'Repo "$repo" tidak dikenal. Jalankan dari salah satu folder berikut:\n'
      '${folderLegalBackendPerRepo.keys.map((k) => '  - $k').join('\n')}\n'
      'Kalau ada pasangan repo baru, tambahkan di folderLegalBackendPerRepo '
      '(tool/policy_html.dart).',
    );
    exit(2);
  }

  final dir = Directory(tujuan);
  if (!dir.existsSync() && !dir.parent.existsSync()) {
    stderr.writeln(
      'Repo backend pasangan "$repo" tidak ada di sebelah.\n'
      'Dicari di: ${dir.absolute.path}',
    );
    exit(2);
  }
  stdout.writeln('Repo ini: $repo  ->  backend: ${dir.parent.absolute.path}');
  if (!cek) dir.createSync(recursive: true);

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
      : '\n$berubah halaman diperbarui. Commit juga perubahan di repo MBIS-backend.');
}
