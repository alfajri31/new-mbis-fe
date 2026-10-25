import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/widgets/pipeline_tab/pipeline_tab_view.dart';
import 'package:mbis/src/network/api_client.dart';
import 'package:mbis/src/pipeline/pipeline_repository.dart';

class _FakeApiClient extends Fake implements ApiClient {}

class _FakePipelineRepo extends PipelineRepository {
  _FakePipelineRepo() : super(apiClient: _FakeApiClient());

  @override
  Future<List<PipelineListModel>> getPipelines({String? customerId}) async {
    return [
      PipelineListModel(
        id: 'PL-1',
        customerName: 'PT Maju Bersama',
        stage: 'P3',
        product: 'PSAKDI',
        sourceType: 'Direct',
        tsiIdr: 250000000,
        potensiPremi: 5000000,
        rmName: 'Mohammad Ridwan Majid',
        kanwil: 'Kantor Wilayah 1',
        kc: 'Padang',
        isBumn: false,
      ),
      PipelineListModel(
        id: 'PL-2',
        customerName: 'PT Adhi Karya',
        stage: 'P2',
        product: 'PA Xtra',
        sourceType: 'BUMN',
        tsiIdr: 1000000000,
        potensiPremi: 20000000,
        rmName: 'Siti Rahmawati',
        kanwil: 'Kantor Wilayah 2',
        kc: 'KC Jakarta Selatan',
        isBumn: true,
      ),
    ];
  }
}

void main() {
  testWidgets('renders pipeline tab with search, chips, filters, summary and cards', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pipelineRepoProvider.overrideWithValue(_FakePipelineRepo()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                PipelineTabView(topInset: 0),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifikasi Search
    expect(find.text('Cari customer, BUMN, atau produk'), findsOneWidget);

    // Verifikasi Chips Tahap
    expect(find.text('Semua (2)'), findsOneWidget);
    expect(find.text('P3 (1)'), findsOneWidget);
    expect(find.text('P2 (1)'), findsOneWidget);

    // Verifikasi Summary
    expect(find.textContaining('2 pipeline · Potensi'), findsOneWidget);

    // Verifikasi Kartu Pipeline 1
    expect(find.text('PSAKDI'), findsOneWidget);
    expect(find.text('PT Maju Bersama'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('P3 · Prospek'), findsOneWidget);

    // Verifikasi Kartu Pipeline 2
    expect(find.text('PA Xtra'), findsOneWidget);
    expect(find.text('PT Adhi Karya'), findsOneWidget);
    expect(find.text('BUMN'), findsWidgets);
    expect(find.text('P2 · Proses'), findsOneWidget);
  });
}
