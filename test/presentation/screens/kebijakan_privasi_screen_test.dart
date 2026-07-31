import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/presentation/screens/kebijakan_privasi_screen.dart';
import 'package:mbis/src/legal/kebijakan_privasi_content.dart';

/// Layar kebijakan privasi di dalam aplikasi. Yang diuji bukan estetika,
/// melainkan hal-hal yang membuat rilis ditolak atau menyesatkan pengguna kalau
/// hilang: seluruh bagian benar-benar terender, pernyataan yang paling mudah
/// disorot reviewer tetap ada, dan tata letaknya tidak meluber di ponsel.
void main() {
  Future<void> pump(WidgetTester tester, {Size size = const Size(390, 900)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: KebijakanPrivasiScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('merender setiap bagian bernomor dari naskah', (tester) async {
    await pump(tester);

    // ListView me-render malas, jadi tiap judul dicari sambil menggulir — ini
    // sekaligus membuktikan seluruh dokumen benar-benar bisa dicapai pengguna,
    // bukan terpotong di tengah.
    for (final section in kebijakanPrivasi) {
      final heading = find.text('${section.number}. ${section.title}');
      await tester.scrollUntilVisible(heading, 300,
          scrollable: find.byType(Scrollable).first);
      expect(heading, findsOneWidget);
    }
  });

  testWidgets('memuat pernyataan yang wajib ada dan mudah hilang', (tester) async {
    await pump(tester);
    final scrollable = find.byType(Scrollable).first;

    // Data nasabah yang keluar ke layanan AI adalah satu-satunya "Shared = Ya"
    // di Data safety; kalau hilang dari kebijakan, formulirnya jadi tidak cocok.
    await tester.scrollUntilVisible(find.text('6. Fitur Asisten AI'), 300,
        scrollable: scrollable);
    expect(find.textContaining('Google (Gemini)'), findsWidgets);

    // Play mensyaratkan penahanan data dinyatakan, bukan disamarkan.
    await tester.scrollUntilVisible(
        find.text('11. Penghapusan Akun dan Data'), 300,
        scrollable: scrollable);
    expect(find.textContaining('wajib diarsipkan'), findsOneWidget);
    expect(find.text('Buka halaman permintaan penghapusan akun'), findsOneWidget);
  });

  testWidgets('menandai status draf selama belum disahkan Legal', (tester) async {
    await pump(tester);

    expect(find.textContaining('DRAF — belum disahkan'),
        kebijakanMasihDraf ? findsOneWidget : findsNothing);
  });

  // Naskahnya penuh tabel tiga kolom. Di ponsel tabel dipecah jadi kartu
  // berlabel; tanpa itu barisnya melebihi lebar layar dan Flutter melempar
  // overflow. Kedua ambang diuji karena renderer tabel bercabang di 600px.
  //
  // Satu testWidgets per lebar, bukan satu test yang me-`pumpWidget` dua kali:
  // pump ulang pohon widget yang sama mempertahankan posisi gulir, sehingga
  // lebar kedua akan mulai dari dasar dokumen dan tidak pernah menemukan
  // bagian-bagian awal.
  for (final size in const [Size(360, 900), Size(1280, 900)]) {
    testWidgets('tidak ada luapan tata letak pada lebar ${size.width}px',
        (tester) async {
      await pump(tester, size: size);
      final scrollable = find.byType(Scrollable).first;

      for (final section in kebijakanPrivasi) {
        await tester.scrollUntilVisible(
            find.text('${section.number}. ${section.title}'), 300,
            scrollable: scrollable);
        expect(tester.takeException(), isNull,
            reason: 'Luapan tata letak di bagian ${section.number}.');
      }
    });
  }
}
