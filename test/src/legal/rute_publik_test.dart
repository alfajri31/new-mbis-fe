import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mbis/src/legal/hapus_akun_content.dart';
import 'package:mbis/src/legal/kebijakan_privasi_content.dart';
import 'package:mbis/src/legal/legal_routes.dart';
import 'package:mbis/src/router.dart';

/// Kedua halaman kebijakan **wajib** dapat dibuka tanpa login — reviewer Google
/// membukanya dari browser biasa, tanpa akun, dan halaman kebijakan yang tidak
/// terbuka dianggap sama dengan tidak ada.
///
/// Sejak halaman HTML statisnya dihapus, satu-satunya yang menjaga syarat itu
/// adalah pengecualian di gerbang auth `buildRouter`. Pengecualian itu mudah
/// hilang tanpa sengaja saat aturan redirect disunting, dan kegagalannya sunyi:
/// aplikasi tetap jalan, hanya URL yang dikirim ke Play Console yang mendarat di
/// layar login. Test ini yang membuatnya berisik.
void main() {
  Future<GoRouter> pumpTanpaSesi(WidgetTester tester, String lokasi) async {
    final router = buildRouter(currentSession: () => null);
    addTearDown(router.dispose);
    router.go(lokasi);
    // ProviderScope dipasang karena cabang "ditolak" mendarat di LoginScreen,
    // yang memakai Riverpod. Tanpa ini test yang membuktikan pagar masih bekerja
    // justru gagal karena alasan yang tidak ada hubungannya.
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    return router;
  }

  group('tanpa sesi', () {
    testWidgets('$rutePublikKebijakan terbuka, bukan dilempar ke login',
        (tester) async {
      final router = await pumpTanpaSesi(tester, rutePublikKebijakan);

      expect(router.routerDelegate.currentConfiguration.uri.path,
          rutePublikKebijakan);
      expect(find.text(judulKebijakan), findsOneWidget);
    });

    testWidgets('$rutePublikHapusAkun terbuka, bukan dilempar ke login',
        (tester) async {
      final router = await pumpTanpaSesi(tester, rutePublikHapusAkun);

      expect(router.routerDelegate.currentConfiguration.uri.path,
          rutePublikHapusAkun);
      expect(find.text(judulHapusAkun), findsOneWidget);
    });

    testWidgets('rute lain TETAP dipagari — pengecualiannya tidak kebablasan',
        (tester) async {
      // Kalau pengecualiannya ditulis terlalu longgar (mis. prefix match), ini
      // yang menangkapnya: layar bisnis tidak boleh ikut terbuka.
      final router = await pumpTanpaSesi(tester, '/customer');

      expect(router.routerDelegate.currentConfiguration.uri.path, '/login');
    });
  });

  testWidgets('tanpa tombol kembali di rute publik', (tester) async {
    // Rute publik bisa mendarat sebagai halaman pertama — tidak ada apa pun
    // untuk dituju kembali, dan tombol yang tidak menuju ke mana-mana adalah
    // persis jenis temuan yang ditandai reviewer.
    await pumpTanpaSesi(tester, rutePublikKebijakan);

    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });
}
