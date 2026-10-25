import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/screens/bumn_detail_screen.dart';
import 'package:mbis/presentation/screens/bumn_screen.dart';
import 'package:mbis/src/bumn/bumn_repository.dart';
import 'package:mbis/src/common/partner_kpi.dart';
import 'package:mbis/src/network/api_client.dart';

class _FakeBumnRepository extends BumnRepository {
  _FakeBumnRepository() : super(apiClient: ApiClient());

  @override
  Future<List<BumnTreeCustomer>> getBumnCustomerTree() async {
    return [
      const BumnTreeCustomer(
        id: 'b1',
        name: 'PT Bank Mandiri (Persero) Tbk',
        level: 'Induk',
        pipelineCount: 3,
        wonCount: 1,
        own: PartnerKpi(p3: 1, p2: 1, p1: 0, won: 1),
        links: [
          BumnLink(
            pipelineId: 'pipe-1',
            stage: 'P2',
            premi: 25000000,
            customer: BumnCustomer('c1', 'PT Bank Mandiri (Persero) Tbk'),
            kanwil: 'Kantor Wilayah 1',
            kc: 'Padang',
            rm: 'Mohammad Ridwan Majid',
          ),
        ],
        children: [
          BumnTreeCustomer(
            id: 'b1a',
            name: 'PT Mandiri Sekuritas',
            level: 'Anak',
            pipelineCount: 1,
            wonCount: 0,
            own: PartnerKpi(p3: 1, p2: 0, p1: 0, won: 0),
          ),
        ],
      ),
    ];
  }

  @override
  Future<PartnerKpi> getBumnKpi() async {
    return const PartnerKpi(
      total: 515,
      withPipeline: 50,
      everWon: 25,
      totalRealisasiPremi: 100000000,
      p3: 10,
      p2: 15,
      p1: 5,
      won: 25,
    );
  }
}

void main() {
  testWidgets('BumnDetailScreen renders header, KPIs, anak usaha, and pipeline cards', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const node = BumnTreeCustomer(
      id: 'b1',
      name: 'PT Bank Mandiri (Persero) Tbk',
      level: 'Induk',
      pipelineCount: 2,
      wonCount: 1,
      own: PartnerKpi(p3: 1, p2: 1, p1: 0, won: 1),
      links: [
        BumnLink(
          pipelineId: 'pipe-1',
          stage: 'P2',
          premi: 25000000,
          customer: BumnCustomer('c1', 'PT Bank Mandiri (Persero) Tbk'),
          kanwil: 'Kantor Wilayah 1',
          kc: 'Padang',
          rm: 'Mohammad Ridwan Majid',
        ),
      ],
      children: [
        BumnTreeCustomer(
          id: 'b1a',
          name: 'PT Mandiri Sekuritas',
          level: 'Anak',
          pipelineCount: 1,
          wonCount: 0,
        ),
      ],
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: BumnDetailScreen(node: node),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Detail BUMN'), findsOneWidget);
    expect(find.text('PT Bank Mandiri (Persero) Tbk'), findsWidgets);
    expect(find.text('Induk · 1 anak usaha'), findsOneWidget);

    // KPI cards
    expect(find.text('Pipeline P3'), findsOneWidget);
    expect(find.text('Pipeline P2'), findsOneWidget);
    expect(find.text('Pipeline P1'), findsOneWidget);
    expect(find.text('Won'), findsOneWidget);

    // Anak usaha
    expect(find.text('Anak Usaha'), findsOneWidget);
    expect(find.text('PT Mandiri Sekuritas'), findsOneWidget);

    // Pipeline card
    expect(find.text('Estimasi Premi'), findsOneWidget);
  });

  testWidgets('clicking _treeRow in BumnScreen navigates to BumnDetailScreen while preserving clicks', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bumnRepoProvider.overrideWithValue(_FakeBumnRepository()),
        ],
        child: const MaterialApp(
          home: BumnScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PT Bank Mandiri (Persero) Tbk'), findsWidgets);

    // Tap on tree row item specifically
    await tester.tap(find.text('PT Bank Mandiri (Persero) Tbk').last);
    await tester.pumpAndSettle();

    // Verify navigates to BumnDetailScreen
    expect(find.text('Detail BUMN'), findsOneWidget);

    // Back to BumnScreen
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.text('Detail BUMN'), findsNothing);
    expect(find.text('PT Bank Mandiri (Persero) Tbk'), findsWidgets);
  });
}
