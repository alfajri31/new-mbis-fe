import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/presentation/widgets/pipeline_detail/pipeline_schedule_card.dart';
import 'package:mbis/src/pipeline/pipeline_repository.dart';

/// Jadwal yang TELAT harus tetap bisa ditutup.
///
/// Dilaporkan 2026-08-20: pada pipeline ber-stage WON, seluruh jadwalnya kehilangan
/// titik tiga, sehingga jadwal yang sudah lewat tidak bisa ditandai selesai maupun
/// dibatalkan. Gejalanya terbaca sebagai "khusus jadwal telat", padahal sebabnya
/// pipeline-nya terkunci siklus hidup. Kartu ini sendiri tidak pernah melihat tanggal
/// — gerbangnya cuma [PipelineScheduleCard.editable] + status OPEN — jadi yang dijaga
/// di sini: telat tidak boleh mengubah apa pun, dan menunya wajib memuat tiga aksi.
PipelineScheduleModel _s({required String status, required String date}) =>
    PipelineScheduleModel(id: 'S1', title: 'Follow-up', date: date, status: status);

Future<void> _pump(WidgetTester tester, PipelineScheduleModel s,
    {bool editable = true, List<String>? tapped}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PipelineScheduleCard(
        schedule: s,
        editable: editable,
        onEdit: (_) => tapped?.add('edit'),
        onCancel: (_) => tapped?.add('cancel'),
        onComplete: (_) => tapped?.add('done'),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  // Jauh di masa lalu / masa depan relatif terhadap tanggal jalannya test.
  final telat = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
  final mendatang = DateTime.now().add(const Duration(days: 30)).toIso8601String();

  testWidgets('jadwal TELAT tetap punya titik tiga', (tester) async {
    await _pump(tester, _s(status: 'OPEN', date: telat));
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(find.text('Terlambat'), findsOneWidget);
  });

  testWidgets('jadwal mendatang juga punya titik tiga', (tester) async {
    await _pump(tester, _s(status: 'OPEN', date: mendatang));
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('menu memuat tiga aksi, dan tandai selesai memanggil callback',
      (tester) async {
    final tapped = <String>[];
    await _pump(tester, _s(status: 'OPEN', date: telat), tapped: tapped);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Tandai selesai'), findsOneWidget);
    expect(find.text('Ubah jadwal'), findsOneWidget);
    expect(find.text('Batalkan jadwal'), findsOneWidget);

    await tester.tap(find.text('Tandai selesai'));
    await tester.pumpAndSettle();
    expect(tapped, ['done']);
  });

  testWidgets('tanpa hak tulis, menu tidak muncul', (tester) async {
    await _pump(tester, _s(status: 'OPEN', date: telat), editable: false);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('jadwal yang sudah selesai tidak bisa diapa-apakan lagi', (tester) async {
    await _pump(tester, _s(status: 'DONE', date: telat));
    expect(find.byIcon(Icons.more_vert), findsNothing);
    expect(find.text('Selesai'), findsOneWidget);
  });
}
