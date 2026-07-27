import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/screens/gps_tracking_screen.dart';
import 'package:mbis/src/network/api_client.dart';
import 'package:mbis/src/visit/visit_repository.dart';

/// BUG RM: pinpoint kunjungan tidak muncul di GPS Tracking. Data & API sudah
/// benar (kunjungan ber-GPS dikembalikan `/api/visits/me`), jadi test ini
/// mengunci sisi render: satu kunjungan ber-GPS harus menghasilkan satu marker.
class _FakeVisitRepository extends VisitRepository {
  _FakeVisitRepository(this.rows) : super(apiClient: ApiClient());

  final List<VisitModel> rows;

  @override
  Future<List<VisitModel>> getMyVisits() async => rows;
}

VisitModel _visit({
  required String id,
  String? lat,
  String? lng,
}) =>
    VisitModel(
      id: id,
      type: 'VISIT',
      customerName: 'CV Uji',
      activityDate: '2026-07-23T08:51:56.444707Z',
      gpsLatitude: lat,
      gpsLongitude: lng,
    );

Future<void> _pump(WidgetTester tester, List<VisitModel> rows) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        visitRepoProvider.overrideWithValue(_FakeVisitRepository(rows)),
      ],
      child: const MaterialApp(home: GpsTrackingScreen()),
    ),
  );
  await tester.pump(); // post-frame start()
  await tester.pump(); // future selesai
}

void main() {
  testWidgets('kunjungan ber-GPS menghasilkan marker di peta', (tester) async {
    await _pump(tester, [
      _visit(id: 'v1', lat: '-6.1560047', lng: '106.8442859'),
      _visit(id: 'v2'), // tanpa GPS — tetap dihitung di statistik, tanpa marker
    ]);

    final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(
      markerLayer.markers.length,
      1,
      reason: 'hanya kunjungan dengan koordinat yang dapat pin',
    );
    // Statistik tetap menghitung SEMUA kunjungan, dan menyebut berapa yang
    // punya titik GPS — angka yang menjelaskan kenapa peta bisa kosong.
    expect(find.text('Dengan Titik GPS'), findsOneWidget);
    expect(find.text('Total Visit'), findsOneWidget);
  });

  testWidgets('peta terpusat pada kunjungan ber-GPS, bukan fallback Jakarta', (
    tester,
  ) async {
    await _pump(tester, [_visit(id: 'v1', lat: '-7.2575', lng: '112.7521')]);

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final center = map.options.initialCenter;
    expect(center.latitude, closeTo(-7.2575, 0.0001));
    expect(center.longitude, closeTo(112.7521, 0.0001));
  });

  testWidgets('tanpa kunjungan ber-GPS: tidak ada marker, tapi ADA penjelasan', (
    tester,
  ) async {
    await _pump(tester, [_visit(id: 'v1')]);

    final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markerLayer.markers, isEmpty);
    // Peta kosong tanpa keterangan bikin user mengira fiturnya rusak.
    expect(
      find.text('Belum ada kunjungan dengan titik GPS'),
      findsOneWidget,
    );
    expect(find.textContaining('izinkan akses lokasi'), findsOneWidget);
  });

  testWidgets('beberapa pin dirangkum agar semuanya masuk layar', (
    tester,
  ) async {
    await _pump(tester, [
      _visit(id: 'v1', lat: '-6.1560047', lng: '106.8442859'),
      _visit(id: 'v2', lat: '-6.1580047', lng: '106.8462859'),
    ]);

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(
      map.options.initialCameraFit,
      isNotNull,
      reason: 'tanpa camera fit, pin kedua berada di luar layar',
    );
  });
}
