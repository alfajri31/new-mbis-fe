import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/presentation/widgets/visit_edit_sheet.dart';
import 'package:mbis/src/network/api_client.dart';
import 'package:mbis/src/visit/visit_repository.dart';

/// Kunjungan yang sudah tercatat kini bisa diperbaiki catatannya.
///
/// Yang dijaga di sini: hanya CATATAN yang bisa diubah. Tag lokasi & foto adalah
/// bukti bahwa RM benar-benar berada di tempat itu pada saat itu — begitu bisa
/// diganti setelah fakta, nilainya sebagai bukti habis. Kalau suatu saat field
/// itu ikut masuk ke formulir, test ini yang lebih dulu merah.
class _FakeVisitRepository extends VisitRepository {
  _FakeVisitRepository() : super(apiClient: ApiClient());

  int calls = 0;
  String? sentNotes;
  String? sentActionPlan;
  String? sentFollowup;

  @override
  Future<VisitModel> updateVisit({
    required String visitId,
    String? notes,
    String? nextFollowupDate,
    String? actionPlan,
  }) async {
    calls++;
    sentNotes = notes;
    sentActionPlan = actionPlan;
    sentFollowup = nextFollowupDate;
    return VisitModel(
      id: visitId,
      type: 'VISIT',
      notes: notes,
      actionPlan: actionPlan,
      nextFollowupDate: nextFollowupDate,
      canEdit: true,
    );
  }
}

VisitModel _visit() => VisitModel(
      id: 'V-1',
      type: 'VISIT',
      notes: 'Bertemu PIC, membahas perpanjangan polis.',
      actionPlan: 'Kirim penawaran revisi',
      nextFollowupDate: '2026-09-10T14:30',
      gpsLatitude: '-6.2',
      gpsLongitude: '106.8',
      photoUrl: '/api/files/visits/foo.jpg',
      canEdit: true,
    );

void main() {
  late _FakeVisitRepository repo;
  VisitModel? hasil;

  Future<void> openSheet(WidgetTester tester) async {
    repo = _FakeVisitRepository();
    hasil = null;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                hasil = await showVisitEditSheet(context, repo, _visit());
              },
              child: const Text('buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('terisi dari kunjungan tersimpan; lokasi & foto tidak ada', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text('Edit Aktivitas'), findsOneWidget);
    expect(
      find.text('Bertemu PIC, membahas perpanjangan polis.'),
      findsOneWidget,
    );
    expect(find.text('Kirim penawaran revisi'), findsOneWidget);
    expect(find.text('10/9/2026'), findsOneWidget);

    // Bukti kunjungan tidak boleh bisa disunting.
    expect(find.textContaining('Lokasi'), findsNothing);
    expect(find.textContaining('Foto'), findsNothing);
  });

  testWidgets('Simpan mengirim tiga field yang boleh diubah', (tester) async {
    await openSheet(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Kirim penawaran revisi'),
      'Kirim penawaran final',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(repo.calls, 1);
    expect(repo.sentNotes, 'Bertemu PIC, membahas perpanjangan polis.');
    expect(repo.sentActionPlan, 'Kirim penawaran final');
    // Waktu dinding lokal tanpa offset — konvensi endpoint kunjungan.
    expect(repo.sentFollowup, '2026-09-10T14:30:00.000');
    expect(hasil, isNotNull);
  });

  testWidgets('Hapus follow-up mengosongkan tanggalnya, bukan menolak simpan', (
    tester,
  ) async {
    await openSheet(tester);

    await tester.tap(find.text('Hapus follow-up'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Simpan'));
    await tester.pumpAndSettle();

    expect(repo.calls, 1);
    expect(repo.sentFollowup, isNull);
  });
}
