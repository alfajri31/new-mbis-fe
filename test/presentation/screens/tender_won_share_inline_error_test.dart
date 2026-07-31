import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/screens/tender_status_screen.dart';
import 'package:mbis/src/network/api_client.dart';
import 'package:mbis/src/pipeline/pipeline_repository.dart';

/// TEMUAN-01 (SIT-34 · REQ-03 · F-010) — peringatan total share co-insurance
/// muncul terlambat.
///
/// Form Won adalah modal bottom sheet, tapi penolakan "total share harus 100%"
/// dulu dikirim lewat SnackBar. SnackBar dirender `ScaffoldMessenger` milik
/// halaman DI BELAKANG sheet, jadi tertutup selama sheet terbuka: RM melihat
/// simpan ditolak tanpa alasan, lalu alasannya muncul justru setelah sheet
/// ditutup — saat datanya sudah benar.
///
/// Test ini mengunci keempat kriteria terima temuan tersebut.
class _FakePipelineRepository extends PipelineRepository {
  _FakePipelineRepository() : super(apiClient: ApiClient());

  /// Bukti integritas data: form yang ditolak TIDAK boleh sampai ke server.
  final List<Map<String, dynamic>> advanceCalls = [];

  @override
  Future<void> advanceTender(String id, Map<String, dynamic> body) async {
    advanceCalls.add(body);
  }
}

/// Pipeline tender yang sedang di langkah Scoring dan siap maju ke Won.
/// Semua tanggal terisi supaya dialog "Detail tender belum lengkap" tidak
/// menghalangi, dan premi awal dikosongkan supaya dialog konfirmasi perubahan
/// premi juga tidak muncul — yang diuji di sini hanya validasi share.
PipelineDetailModel _tenderPipeline() => PipelineDetailModel(
  id: 'P-1',
  stage: 'PROSPECT',
  isTender: true,
  tsiIdr: 0,
  tenderRole: 'LEADER',
  tenderCurrentSeq: 0,
  schedules: const [],
  tenderProcesses: [
    PipelineTenderModel(
      processType: 'SCORING_PENGUMUMAN',
      seq: 0,
      startDate: '2026-07-01',
      endDate: '2026-07-10',
    ),
    PipelineTenderModel(
      processType: 'WON_TENDER',
      seq: 1,
      startDate: '2026-07-11',
      endDate: '2026-07-20',
    ),
  ],
);

/// Periode polis wajib diisi sejak nomor & masa berlaku polis dicatat sekaligus
/// saat WON. Pemilih tanggal bawaan Material dibuka lalu dikonfirmasi apa adanya
/// (default hari ini) — case ini menguji validasi share, bukan pemilihan tanggal.
Future<void> _isiPeriodePolis(WidgetTester tester) async {
  for (final label in ['Mulai Polis', 'Selesai Polis']) {
    // Ketuk InkWell pembungkusnya, bukan label-nya: label hanya teks di dalam
    // InputDecorator sehingga titik tengahnya belum tentu menerima pointer.
    final field = find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }
}

/// Baris share member pertama. Tidak bisa dicari lewat teks: hint '%' pada
/// field persentase sama dengan suffix field "Share Askrindo (%)".
final _memberName = find.byKey(const ValueKey('share-name-member-0'));
final _memberPct = find.byKey(const ValueKey('share-pct-member-0'));

void main() {
  late _FakePipelineRepository pipelineRepo;

  Future<void> pumpScreen(WidgetTester tester) async {
    // Layar ponsel penuh: sheet Won cukup panjang, dengan 800x600 bawaan test
    // sebagian isinya di luar viewport.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    pipelineRepo = _FakePipelineRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [pipelineRepoProvider.overrideWithValue(pipelineRepo)],
        child: MaterialApp(
          home: TenderStatusScreen(
            pipeline: _tenderPipeline(),
            apiClient: ApiClient(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Buka sheet Won lalu isi semua field wajib; share Askrindo + member
  /// sengaja hanya berjumlah [totalShare] persen.
  Future<void> openWonSheetWithShare(
    WidgetTester tester, {
    required double askrindo,
    required double member,
  }) async {
    await tester.tap(find.text('Maju ke Proses'));
    await tester.pumpAndSettle();
    expect(find.text('Won — Leader'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'No. Polis'),
      'POL-001',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Share Askrindo (%)'),
      '$askrindo',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Premi'), '1000000');
    await _isiPeriodePolis(tester);
    await tester.enterText(_memberName, 'PT Mitra');
    await tester.enterText(_memberPct, '$member');
    await tester.pumpAndSettle();
  }

  Future<void> tapSimpanWon(WidgetTester tester) async {
    final simpan = find.text('Simpan Won');
    await tester.ensureVisible(simpan);
    await tester.pumpAndSettle();
    await tester.tap(simpan);
    await tester.pumpAndSettle();
  }

  testWidgets('total < 100% — pesan langsung terlihat DI DALAM sheet', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openWonSheetWithShare(tester, askrindo: 60, member: 30);
    await tapSimpanWon(tester);

    // Kriteria 1: pesannya terlihat tanpa menutup sheet…
    expect(find.text('Won — Leader'), findsOneWidget); // sheet masih terbuka
    expect(
      find.textContaining('Total share harus 100%'),
      findsOneWidget,
      reason: 'pesan harus dirender di dalam sheet, bukan lewat SnackBar',
    );
    // …dan menyebut selisihnya, bukan cuma "tidak 100%".
    expect(find.textContaining('kurang 10.00%'), findsOneWidget);

    // Kriteria 4: tidak ada SnackBar sama sekali — kalau ada, ia tersembunyi di
    // belakang sheet dan baru muncul setelah sheet ditutup.
    expect(find.byType(SnackBar), findsNothing);

    // Kriteria 3: penolakannya nyata, data tidak dikirim ke server.
    expect(pipelineRepo.advanceCalls, isEmpty);
  });

  testWidgets('dibetulkan sampai 100% — pesan hilang sendiri tanpa Simpan', (
    tester,
  ) async {
    await pumpScreen(tester);
    await openWonSheetWithShare(tester, askrindo: 60, member: 30);
    await tapSimpanWon(tester);
    expect(find.textContaining('Total share harus 100%'), findsOneWidget);

    // Kriteria 2: cukup membetulkan angkanya — tanpa menekan Simpan lagi.
    await tester.enterText(_memberPct, '40');
    await tester.pumpAndSettle();

    expect(find.textContaining('Total share harus 100%'), findsNothing);
    expect(find.text('Total: 100.0%'), findsOneWidget);
    expect(pipelineRepo.advanceCalls, isEmpty); // belum disimpan
  });

  testWidgets('total 100% — Simpan diterima dan sheet ditutup', (tester) async {
    await pumpScreen(tester);
    await openWonSheetWithShare(tester, askrindo: 60, member: 40);
    await tapSimpanWon(tester);

    expect(pipelineRepo.advanceCalls, hasLength(1));
    expect(pipelineRepo.advanceCalls.single['shareAskrindo'], 60.0);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('isian wajib kosong — ringkasannya juga inline, bukan SnackBar', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.text('Maju ke Proses'));
    await tester.pumpAndSettle();

    await tapSimpanWon(tester);

    // Penyakit yang sama dengan pesan total share: snackbar di dalam sheet.
    expect(find.textContaining('isian wajib belum lengkap'), findsOneWidget);
    expect(find.text('• No. Polis'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(pipelineRepo.advanceCalls, isEmpty);

    // Ringkasan ikut hilang begitu user mulai membetulkan.
    await tester.enterText(
      find.widgetWithText(TextField, 'No. Polis'),
      'POL-001',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('isian wajib belum lengkap'), findsNothing);
  });
}
