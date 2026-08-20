import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/presentation/widgets/ai_result_view.dart';
import 'package:mbis/src/assistant/assistant_repository.dart';

/// Hasil AI tidak boleh menampilkan daftar produk dua kali.
///
/// Prompt sudah meminta model menaruh rekomendasi HANYA di field `recommendations`, tetapi itu
/// permintaan tanpa penegakan — model tetap sering menuliskannya ULANG sebagai section biasa,
/// dan kartu "Rekomendasi Produk" bawaan tampil di bawahnya, jadi RM melihat daftar yang sama
/// berturut-turut. Penyaringnya sengaja di sisi render supaya hasil LAMA yang sudah tersimpan
/// ikut rapi tanpa perlu dijalankan ulang (dan tanpa membakar kuota harian).
Future<void> _pump(WidgetTester tester, AiStructuredResult result) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: AiResultView(result: result)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'section produk tulisan model dibuang saat recommendations terisi',
    (tester) async {
      await _pump(
        tester,
        AiStructuredResult(
          judul: 'Profil',
          sections: [
            AiSection(
              heading: 'Indikasi Kebutuhan',
              items: ['Risiko proyek konstruksi.'],
            ),
            AiSection(
              heading: 'Rekomendasi Produk Askrindo',
              items: ['Property All Risk', 'Surety Bond'],
            ),
          ],
          recommendations: [
            AiRecommendation(
              produk: 'Property All Risk',
              alasan: 'Aset besar.',
            ),
            AiRecommendation(produk: 'Surety Bond', alasan: 'Kontraktor.'),
          ],
        ),
      );

      expect(find.text('Rekomendasi Produk Askrindo'), findsNothing);
      expect(find.text('Rekomendasi Produk'), findsOneWidget);
      expect(find.text('Indikasi Kebutuhan'), findsOneWidget);
    },
  );

  testWidgets('section produk DIPERTAHANKAN bila recommendations kosong', (
    tester,
  ) async {
    // Jangan sampai penyaring itu justru menghapus satu-satunya tempat produk disebut.
    await _pump(
      tester,
      AiStructuredResult(
        judul: 'Profil',
        sections: [
          AiSection(
            heading: 'Rekomendasi Produk',
            items: ['Property All Risk'],
          ),
        ],
      ),
    );

    expect(find.text('Rekomendasi Produk'), findsOneWidget);
    expect(find.text('Property All Risk'), findsOneWidget);
  });

  testWidgets('section tanpa isi tidak menghasilkan kartu kosong', (
    tester,
  ) async {
    await _pump(
      tester,
      AiStructuredResult(
        judul: 'Profil',
        sections: [
          AiSection(heading: 'Profil Singkat', items: ['Kontraktor nasional.']),
          AiSection(heading: 'Bagian Menggantung', items: []),
          AiSection(heading: 'Hanya Hiasan', items: ['**', '  ']),
        ],
      ),
    );

    expect(find.text('Profil Singkat'), findsOneWidget);
    expect(find.text('Bagian Menggantung'), findsNothing);
    expect(find.text('Hanya Hiasan'), findsNothing);
  });

  testWidgets('heading mirip tapi bukan daftar produk tetap tampil', (
    tester,
  ) async {
    await _pump(
      tester,
      AiStructuredResult(
        judul: 'Profil',
        sections: [
          AiSection(
            heading: 'Langkah Rekomendasi',
            items: ['Jadwalkan kunjungan.'],
          ),
          AiSection(heading: 'Produk Existing', items: ['Surety Bond aktif.']),
        ],
        recommendations: [AiRecommendation(produk: 'Property All Risk')],
      ),
    );

    expect(find.text('Langkah Rekomendasi'), findsOneWidget);
    expect(find.text('Produk Existing'), findsOneWidget);
  });

  testWidgets('isi kartu produk rata kiri & sejajar antar-kartu', (
    tester,
  ) async {
    // Panjang alasan sengaja jauh berbeda. Sebelum diperbaiki, isi kartu ter-CENTER sehingga
    // tepi kirinya bergeser mengikuti panjang teks dan antar-produk terlihat bertingkat.
    const pendek = 'Singkat.';
    const panjang =
        'Melindungi seluruh fasilitas operasional dari berbagai risiko kerusakan '
        'maupun kerugian yang dapat timbul selama masa pertanggungan berlangsung.';

    await _pump(
      tester,
      AiStructuredResult(
        recommendations: [
          AiRecommendation(produk: 'Produk A', alasan: pendek),
          AiRecommendation(produk: 'Produk B', alasan: panjang),
        ],
      ),
    );

    await tester.tap(find.text('Produk A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Produk B'));
    await tester.pumpAndSettle();

    final kiriA = tester.getTopLeft(find.text(pendek)).dx;
    final kiriB = tester.getTopLeft(find.text(panjang)).dx;
    expect(
      kiriA,
      kiriB,
      reason: 'alasan kedua kartu harus mulai di x yang sama',
    );

    // Tombol "Lihat detail produk" diwakili ikonnya (satu per kartu).
    final tombol = find.byIcon(Icons.menu_book_outlined);
    expect(tombol, findsNWidgets(2));
    expect(
      tester.getTopLeft(tombol.at(0)).dx,
      tester.getTopLeft(tombol.at(1)).dx,
      reason: 'tombol kedua kartu harus mulai di x yang sama',
    );

    // Dan benar-benar di kiri, bukan sekadar konsisten di tengah.
    expect(
      kiriA,
      lessThan(tester.getSize(find.byType(AiResultView)).width / 4),
    );
  });
}
