import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mbis/presentation/screens/privasi_akun_screen.dart';
import 'package:mbis/src/legal/legal_routes.dart';

/// Layar Privasi & Akun memenuhi kewajiban kebijakan Google Play, jadi yang diuji
/// di sini bukan estetika melainkan hal-hal yang membuat rilis ditolak kalau
/// hilang: kedua judul kewajiban muncul, pernyataan retensi data tetap ada, dan
/// **kedua tombolnya benar-benar sampai ke halamannya**.
///
/// Keduanya kini navigasi di dalam aplikasi, bukan `launchUrl`. Itu yang membuat
/// keduanya terbaca tanpa sinyal dan tidak bisa hilang gara-gara variabel
/// `--dart-define` lupa diisi saat build.
void main() {
  Future<void> pump(WidgetTester tester) async {
    // Viewport default test runner (800x600) memotong kartu hapus akun, dan
    // ListView tetap membangunnya di cache extent — jadi finder menemukannya
    // sementara tap-nya meleset ke luar layar.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: PrivasiAkunScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('menampilkan kedua kewajiban Play: kebijakan privasi & hapus akun',
      (tester) async {
    await pump(tester);

    expect(find.text('Kebijakan Privasi'), findsOneWidget);
    expect(find.text('Hapus Akun'), findsOneWidget);
    expect(find.text('Buka Kebijakan Privasi'), findsOneWidget);
    expect(find.text('Ajukan Penghapusan Akun'), findsOneWidget);
  });

  testWidgets('menyatakan data mana yang ditahan karena ketentuan arsip',
      (tester) async {
    await pump(tester);

    // Play mensyaratkan penahanan data dijelaskan ke pengguna, bukan disamarkan.
    expect(find.textContaining('Yang tetap disimpan'), findsOneWidget);
    expect(find.textContaining('perusahaan asuransi'), findsOneWidget);
  });

  /// Layar ini dipakai dari dua shell dengan prefiks berbeda, jadi yang diuji
  /// adalah tujuan kebijakan dirakit dari `basePath` — bukan path yang
  /// di-hardcode, yang akan melempar pengguna Agen ke shell RM. Tujuan hapus
  /// akun sebaliknya memang mutlak: ia rute publik yang sama untuk semua.
  for (final base in const ['/profil/privasi', '/agent/profil/privasi']) {
    testWidgets('dari $base, kedua tombol sampai ke halamannya', (tester) async {
      // Sama seperti [pump]: kartu hapus akun ada di luar viewport 800x600
      // default, dan ListView tetap membangunnya sehingga finder menemukannya
      // tapi tap-nya meleset.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: base,
        routes: [
          GoRoute(
            path: base,
            builder: (_, _) => PrivasiAkunScreen(basePath: base),
            routes: [
              GoRoute(
                path: 'kebijakan',
                builder: (_, _) =>
                    const Scaffold(body: Text('HALAMAN KEBIJAKAN')),
              ),
            ],
          ),
          GoRoute(
            path: rutePublikHapusAkun,
            builder: (_, _) => const Scaffold(body: Text('HALAMAN HAPUS AKUN')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buka Kebijakan Privasi'));
      await tester.pumpAndSettle();
      expect(find.text('HALAMAN KEBIJAKAN'), findsOneWidget);

      // Kembali ke Privasi & Akun — push, jadi tombol kembali harus memulangkan
      // ke sini, bukan ke shell.
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pop();
      await tester.pumpAndSettle();
      expect(find.text('Ajukan Penghapusan Akun'), findsOneWidget);

      await tester.tap(find.text('Ajukan Penghapusan Akun'));
      await tester.pumpAndSettle();
      expect(find.text('HALAMAN HAPUS AKUN'), findsOneWidget);
    });
  }
}
