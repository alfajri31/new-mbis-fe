import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/data/premi_rates.dart';
import 'package:mbis/presentation/widgets/kalkulator_premi/premi_result_card.dart';

/// CR-21 — biaya admin pada Kalkulator Premi.
///
/// Yang dikunci di sini adalah janji yang paling mudah rusak diam-diam: biaya
/// admin BUKAN bagian dari premi, ia hanya menambah total. Kalau suatu saat ada
/// yang melipatnya ke dalam premi, angka premi di dokumen resmi ikut berubah
/// tanpa ada yang menyadarinya.
Future<void> _pump(WidgetTester tester, {num biayaAdmin = 0}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: PremiResultCard(
          category: PremiCategory.asuransiUmum,
          rate: 0.5,
          diskon: 0,
          currency: 'IDR',
          tsiOriginal: 100000000,
          tsiIdr: 100000000,
          minPremiApplied: false,
          premi: 500000,
          biayaAdmin: biayaAdmin,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('tanpa biaya admin: kartu tampil seperti sebelum CR-21', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Estimasi Premi'), findsOneWidget);
    expect(find.text('Biaya Admin'), findsNothing);
    expect(
      find.text('Total'),
      findsNothing,
      reason: 'tanpa biaya admin tidak ada yang perlu dijumlahkan',
    );
  });

  testWidgets('dengan biaya admin: premi & biaya dirinci, total = jumlahnya', (
    tester,
  ) async {
    await _pump(tester, biayaAdmin: 25000);

    // Premi TETAP 500.000 — biaya admin tidak boleh terserap ke dalamnya.
    expect(find.text('Rp 500.000'), findsOneWidget);
    expect(find.text('Biaya Admin'), findsOneWidget);
    expect(find.text('Rp 25.000'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('Rp 525.000'), findsOneWidget);
  });

  testWidgets('total boleh dipasok pemanggil, tapi bawaannya premi + biaya', (
    tester,
  ) async {
    await _pump(tester, biayaAdmin: 25000);

    final card = tester.widget<PremiResultCard>(find.byType(PremiResultCard));
    expect(card.totalTagihan, 525000);
  });
}
