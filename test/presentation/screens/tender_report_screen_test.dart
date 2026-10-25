import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/screens/tender_report_screen.dart';
import 'package:mbis/src/network/api_client.dart';
import 'package:mbis/src/tender/tender_repository.dart';

class _FakeTenderRepository extends TenderRepository {
  _FakeTenderRepository() : super(apiClient: ApiClient());

  @override
  Future<TenderReport> getReport() async {
    return const TenderReport(
      wonCount: 1,
      lossCount: 1,
      activeCount: 1,
      won: [
        TenderItem(
          pipelineId: 'p1',
          tenderNo: 'TDR/ADHI/2026/0451',
          tenderName: 'Asuransi CAR Pembangunan Gedung',
          customerName: 'PT Adhi Karya (Persero) Tbk',
          status: 'Menang',
          premi: 18000000,
          tsi: 15000000000,
          product: 'CAR / Contractor All Risk',
          metode: 'Tender Terbuka',
          kanwil: 'Kantor Wilayah 1',
          kc: 'KC Padang',
          rmName: 'Mohammad Ridwan Majid',
        ),
      ],
      loss: [
        TenderItem(
          pipelineId: 'p2',
          tenderNo: 'TDR/APG/2026/0198',
          tenderName: 'Asuransi Kecelakaan Diri Pekerja',
          customerName: 'PT Adhi Persada Gedung',
          status: 'Kalah',
          premi: 2400000,
          tsi: 1600000000,
          product: 'PSAKDI',
          lossReason: 'Kalah harga',
        ),
      ],
    );
  }
}

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        tenderRepoProvider.overrideWithValue(_FakeTenderRepository()),
      ],
      child: const MaterialApp(
        home: TenderReportScreen(),
      ),
    );
  }

  testWidgets('renders tender report screen matching prototype layout and functionality', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. Header & Title
    expect(find.text('Report Tender'), findsOneWidget);

    // 2. Summary stats
    expect(find.text('Menang'), findsWidgets);
    expect(find.text('Kalah'), findsWidgets);
    expect(find.text('Win Rate'), findsOneWidget);
    expect(find.text('33%'), findsOneWidget); // 1 won out of 3 total with active = 33%
    expect(
      find.text('Win rate dari 3 tender, termasuk 1 yang masih berjalan.'),
      findsOneWidget,
    );

    // 3. Filter chips
    expect(find.text('Semua (2)'), findsOneWidget);
    expect(find.text('Menang (1)'), findsOneWidget);
    expect(find.text('Kalah (1)'), findsOneWidget);

    // 4. Section headers & tender items
    expect(find.text('Tender Menang (1)'), findsOneWidget);
    expect(find.text('Asuransi CAR Pembangunan Gedung'), findsOneWidget);
    expect(find.text('Tender Kalah (1)'), findsOneWidget);
    expect(find.text('Asuransi Kecelakaan Diri Pekerja'), findsOneWidget);

    // 5. Expand accordion on tap
    expect(find.text('No. Tender'), findsNothing);
    await tester.tap(find.text('Asuransi CAR Pembangunan Gedung'));
    await tester.pumpAndSettle();

    expect(find.text('No. Tender'), findsOneWidget);
    expect(find.text('TDR/ADHI/2026/0451'), findsOneWidget);
    expect(find.text('Lihat Pipeline'), findsOneWidget);

    // 6. Test filter chips
    await tester.tap(find.text('Kalah (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Tender Menang (1)'), findsNothing);
    expect(find.text('Tender Kalah (1)'), findsOneWidget);
  });
}
