import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/presentation/widgets/kpi_drilldown_sheet.dart';

/// CR-06 — bottom banner rincian kartu KPI (layar Broker & BUMN).
///
/// Dua janji yang paling mudah rusak diam-diam dikunci di sini: jumlah baris yang
/// ditulis di kepala banner (pembaca memakainya untuk mencocokkan dengan angka di
/// kartu yang barusan ditekan), dan banner yang HARUS tertutup sebelum berpindah
/// halaman — kalau tidak, ia tertinggal menutupi halaman tujuan.
Future<void> _open(
  WidgetTester tester, {
  required List<KpiDrilldownRow> rows,
  String emptyMessage = 'Kosong.',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showKpiDrilldownSheet(
              context,
              title: 'Pipeline P3',
              subtitle: 'Tekan satu baris untuk membuka pipeline-nya',
              rows: rows,
              emptyMessage: emptyMessage,
            ),
            child: const Text('buka'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('buka'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('baris pipeline menyebut customer-nya, bukan hanya angka', (
    tester,
  ) async {
    await _open(tester, rows: [
      const KpiDrilldownRow(
        title: 'PT Customer Satu',
        subtitle: 'Broker Alfa · P3',
        trailing: 'Rp 1,2 M',
      ),
    ]);

    // Nama customer adalah judul barisnya — tanpa ini daftar pipeline tidak
    // menjawab "punya siapa", yang justru pertanyaan pertama pembacanya.
    expect(find.text('PT Customer Satu'), findsOneWidget);
    expect(find.text('Broker Alfa · P3'), findsOneWidget);
    expect(find.text('Rp 1,2 M'), findsOneWidget);
  });

  testWidgets('kepala banner menulis jumlah baris agar bisa dicocokkan', (
    tester,
  ) async {
    await _open(tester, rows: [
      const KpiDrilldownRow(title: 'PT Satu'),
      const KpiDrilldownRow(title: 'PT Dua'),
      const KpiDrilldownRow(title: 'PT Tiga'),
    ]);

    expect(find.text('Pipeline P3'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('ketukan menutup banner DULU baru menjalankan tujuannya', (
    tester,
  ) async {
    var opened = 0;
    await _open(tester, rows: [
      KpiDrilldownRow(title: 'PT Satu', onTap: () => opened++),
    ]);

    await tester.tap(find.text('PT Satu'));
    await tester.pumpAndSettle();

    expect(opened, 1);
    expect(
      find.text('PT Satu'),
      findsNothing,
      reason: 'banner yang tertinggal akan menutupi halaman tujuan',
    );
  });

  testWidgets('baris tanpa tujuan tidak bisa ditekan, tapi tetap tampil', (
    tester,
  ) async {
    await _open(tester, rows: [
      const KpiDrilldownRow(
        title: 'Broker Tanpa Pipeline',
        subtitle: 'belum ada pipeline di cakupan Anda',
      ),
    ]);

    expect(find.text('Broker Tanpa Pipeline'), findsOneWidget);
    final tile = tester.widget<ListTile>(find.byType(ListTile));
    expect(
      tile.onTap,
      isNull,
      reason: 'baris yang bisa ditekan tapi tidak ke mana-mana lebih buruk '
          'daripada baris yang jelas tidak bisa ditekan',
    );
  });

  testWidgets('tanpa baris: penjelasan, bukan banner kosong', (tester) async {
    await _open(tester,
        rows: const [], emptyMessage: 'Belum ada pipeline pada tahap ini.');

    expect(find.text('Belum ada pipeline pada tahap ini.'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });
}
