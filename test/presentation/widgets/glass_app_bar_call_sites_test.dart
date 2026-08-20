import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Setiap pemakai GlassAppBar wajib menyatakan lebar kolom konten body-nya.
///
/// Nilai bawaan `contentMaxWidth` adalah cap responsif 1200/1440/1800, yang hanya benar
/// untuk layar yang body-nya memang memakai cap itu. Untuk layar full-bleed atau yang
/// memakai MaxWidthBody 800, membiarkannya bawaan membuat judul melayang jauh dari
/// isinya — terukur meleset 240-292 px di layar 1920.
///
/// Kesalahan ini TIDAK terlihat di ponsel dan tidak memicu error apa pun, jadi ia lolos
/// review dengan mudah: `visit_map_screen` masuk lewat merge staging dengan nilai bawaan
/// padahal petanya memenuhi layar. Test ini yang lebih dulu merah lain kali.
///
/// Kalau sebuah layar BARU memang memakai cap responsif, tambahkan namanya ke
/// [_pakaiCapResponsif] beserta alasannya — bukan dengan melonggarkan test ini.
const Set<String> _pakaiCapResponsif = {
  // Body-nya membungkus konten dengan Responsive.contentMaxWidthFor, sama persis
  // dengan bawaan GlassAppBar, jadi tidak perlu dinyatakan ulang.
  'broker_screen.dart',
  'bumn_screen.dart',
  'customer_list_screen.dart',
  'referral_management_screen.dart',
  'rm_performance_screen.dart',
  'tender_report_screen.dart',
};

void main() {
  test('semua pemakai GlassAppBar menyatakan lebar kolom konten', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'test dijalankan dari akar paket');

    final lalai = <String>[];
    for (final f in lib.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.path.replaceAll(r'\', '/').endsWith('widgets/glass_app_bar.dart')) continue;

      final isi = f.readAsStringSync();
      if (!isi.contains('GlassAppBar(')) continue;

      final nama = f.uri.pathSegments.last;
      if (_pakaiCapResponsif.contains(nama)) continue;
      if (isi.contains('contentMaxWidth:')) continue;
      lalai.add(nama);
    }

    expect(
      lalai,
      isEmpty,
      reason:
          'Berkas berikut memakai GlassAppBar tanpa menyatakan contentMaxWidth. '
          'Isi MaxWidthBody.defaultMaxWidth untuk konsol admin, angka sendiri untuk '
          'form ber-cap khusus, atau double.infinity bila body-nya full-bleed: $lalai',
    );
  });
}
