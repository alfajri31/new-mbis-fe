import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/screens/broker_screen.dart';
import 'package:mbis/src/broker/broker_repository.dart';
import 'package:mbis/src/common/partner_kpi.dart';
import 'package:mbis/src/network/api_client.dart';

/// CR-06 — kartu KPI layar Broker BENAR-BENAR bisa ditekan.
///
/// Test komponen banner-nya sendiri sudah ada; yang dikunci di sini adalah
/// sambungannya: kartu di layar harus punya tujuan ketukan, dan yang muncul
/// setelah ditekan harus rincian dari angka pada kartu ITU — bukan kartu lain.
/// Tanpa test ini, kartu yang lupa diberi `onTap` lolos analyzer tanpa keluhan.
class _FakeBrokerRepository extends BrokerRepository {
  _FakeBrokerRepository(this.views, this.kpi) : super(apiClient: ApiClient());

  final List<BrokerView> views;
  final PartnerKpi kpi;

  @override
  Future<List<BrokerView>> getBrokerViews() async => views;

  @override
  Future<PartnerKpi> getBrokerKpi() async => kpi;
}

BrokerView _view({
  required String id,
  required String name,
  required List<BrokerLink> links,
}) =>
    BrokerView(
      broker: BrokerModel(id: id, code: id.toUpperCase(), name: name),
      links: links,
    );

BrokerLink _link({
  required String pipelineId,
  required String stage,
  required String customerName,
  double? premi,
}) =>
    BrokerLink(
      pipelineId: pipelineId,
      stage: stage,
      premi: premi,
      customer: BrokerCustomer('cust-$pipelineId', customerName),
    );

Future<void> _pump(WidgetTester tester) async {
  final views = [
    _view(id: 'brk-1', name: 'Broker Alfa', links: [
      _link(pipelineId: 'p-1', stage: 'P3', customerName: 'PT Satu', premi: 1),
      _link(pipelineId: 'p-2', stage: 'WON', customerName: 'PT Dua', premi: 2),
    ]),
    _view(id: 'brk-2', name: 'Broker Beta', links: [
      _link(pipelineId: 'p-3', stage: 'P3', customerName: 'PT Tiga', premi: 3),
    ]),
  ];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        brokerRepoProvider.overrideWithValue(
          _FakeBrokerRepository(
            views,
            const PartnerKpi(
                total: 150, withPipeline: 2, everWon: 1, p3: 2, won: 1),
          ),
        ),
      ],
      child: const MaterialApp(home: BrokerScreen()),
    ),
  );
  await tester.pump(); // post-frame start()
  await tester.pump(); // future daftar + KPI selesai
}

/// Nama customer juga muncul sebagai chip pada kartu broker DI BELAKANG banner,
/// jadi pencarian teks polos akan menemukan dua-duanya dan tidak membuktikan apa
/// pun tentang isi banner. Semua assertion di bawah dipersempit ke baris banner.
Finder _bannerRow(String text) =>
    find.descendant(of: find.byType(ListTile), matching: find.text(text));

void main() {
  testWidgets('kartu "Pipeline P3" ditekan → daftar pipeline P3, bukan tahap lain', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Pipeline P3'));
    await tester.pumpAndSettle();

    // Judul baris = nama customer (permintaan eksplisit CR-06), dan hanya
    // pipeline P3 yang ikut — PT Dua ber-tahap WON harus absen.
    expect(_bannerRow('PT Satu'), findsOneWidget);
    expect(_bannerRow('PT Tiga'), findsOneWidget);
    expect(
      _bannerRow('PT Dua'),
      findsNothing,
      reason: 'pipeline WON tidak boleh bocor ke rincian kartu P3',
    );
    // Broker asalnya jadi keterangan, jadi barisnya tetap bisa ditelusuri.
    expect(_bannerRow('Broker Alfa · P3'), findsOneWidget);
  });

  testWidgets('kartu "Broker ber-Pipeline" ditekan → daftar brokernya', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Broker ber-Pipeline'));
    await tester.pumpAndSettle();

    expect(_bannerRow('Broker Alfa'), findsOneWidget);
    expect(_bannerRow('Broker Beta'), findsOneWidget);
    // Keterangannya menyebut jumlah pipeline broker itu.
    expect(_bannerRow('BRK-1 · 2 pipeline'), findsOneWidget);
  });

  testWidgets('kartu "Pipeline Declined" tanpa isi → penjelasan, bukan banner kosong', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text('Pipeline Declined'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Belum ada pipeline broker pada tahap DECLINE'),
        findsOneWidget);
  });
}
