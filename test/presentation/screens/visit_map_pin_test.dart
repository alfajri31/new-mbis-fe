import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/screens/visit_map_screen.dart';
import 'package:mbis/src/dashboard/dashboard_repository.dart';
import 'package:mbis/src/network/api_client.dart';

/// CR-10 pada layar yang BENAR.
///
/// Kriterianya menyebut "Peta Kunjungan", dan layar dengan judul itu adalah
/// [VisitMapScreen] — bukan GPS Tracking Kunjungan, yang sempat dikerjakan lebih
/// dulu karena catatan teknis backlog menunjuk berkas itu. Di layar ini dulu peta
/// hanya menempati 3/5 tinggi (sisanya daftar) dan menekan pin CUMA menggeser-
/// memperbesar peta: tidak ada ringkasan, tidak ada jalan ke customer-nya.
///
/// Dua kriteria itu diuji apa adanya: ukuran peta diukur, dan pin-nya benar-benar
/// diketuk.
class _FakeDashboardRepository extends DashboardRepository {
  _FakeDashboardRepository(this.locations, {this.summary})
      : super(apiClient: ApiClient());

  final List<VisitLocation> locations;
  final VisitTrackingSummary? summary;

  /// Kosong = peran RM (server memang tak memberi opsi kantor untuk OWNER),
  /// jadi penyaring kantor otomatis tidak tampil.
  @override
  Future<List<ScopeOffice>> getScopeOffices() async => [];

  @override
  Future<List<VisitLocation>> getVisitLocations({String? officeId}) async =>
      locations;

  @override
  Future<VisitTrackingSummary> getVisitTrackingSummary({String? officeId}) async =>
      summary ?? const VisitTrackingSummary();
}

VisitLocation _loc({
  required String visitId,
  String? customerId = 'cust-7',
  String customerName = 'PT Kunjungan Satu',
}) =>
    VisitLocation(
      visitId: visitId,
      rmName: 'RM Satu',
      officeName: 'KC Jakarta',
      customerId: customerId,
      customerName: customerName,
      latitude: -6.15,
      longitude: 106.84,
      activityDate: '2026-07-23T08:51:56.444707Z',
      visitType: 'VISIT',
    );

Future<void> _pump(
  WidgetTester tester,
  List<VisitLocation> locations, {
  VisitTrackingSummary? summary,
}) async {
  final router = GoRouter(
    initialLocation: '/tools/visit-map',
    routes: [
      GoRoute(
          path: '/tools/visit-map', builder: (_, _) => const VisitMapScreen()),
      GoRoute(
        path: '/customer/:customerId',
        builder: (_, s) => Scaffold(
          body: Text('halaman customer ${s.pathParameters['customerId']}'),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        dashboardRepoProvider.overrideWithValue(
            _FakeDashboardRepository(locations, summary: summary)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('peta memenuhi layar, bukan 3/5 dengan daftar di bawahnya', (
    tester,
  ) async {
    await _pump(tester, [_loc(visitId: 'v1')]);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final mapSize = tester.getSize(find.byType(FlutterMap));
    expect(mapSize.width, closeTo(screen.width, 0.5));
    expect(
      mapSize.height,
      closeTo(screen.height, 0.5),
      reason: 'tata letak lama menyisakan 2/5 layar untuk daftar, jadi tinggi '
          'peta SELALU kurang dari layar — inilah yang membedakannya',
    );
  });

  testWidgets('pin diketuk: ringkasan muncul, lalu tautannya membuka customer', (
    tester,
  ) async {
    await _pump(tester, [_loc(visitId: 'v1', customerId: 'cust-7')]);

    // Sebelum diketuk belum ada ringkasan — kalau sudah tampil sejak awal,
    // ketukan di bawah tidak membuktikan apa pun.
    expect(find.text('Buka halaman customer'), findsNothing);

    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pump();

    expect(find.text('PT Kunjungan Satu'), findsOneWidget);
    expect(find.textContaining('RM Satu'), findsOneWidget);

    await tester.tap(find.text('Buka halaman customer'));
    await tester.pumpAndSettle();

    expect(
      find.text('halaman customer cust-7'),
      findsOneWidget,
      reason: 'pin harus menuju customer miliknya sendiri',
    );
  });

  testWidgets('kunjungan tanpa id customer: ringkasan tetap, tautan disembunyikan', (
    tester,
  ) async {
    await _pump(tester, [_loc(visitId: 'v1', customerId: null)]);

    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pump();

    expect(find.text('PT Kunjungan Satu'), findsOneWidget);
    expect(find.text('Buka halaman customer'), findsNothing);
  });

  // ── Peleburan layar GPS Tracking ke sini ──────────────────────────────────
  // Yang dijaga: RM tidak kehilangan apa pun saat layarnya dihapus.

  testWidgets('statistik kunjungan ikut pindah ke peta bersama', (tester) async {
    await _pump(
      tester,
      [_loc(visitId: 'v1')],
      summary: const VisitTrackingSummary(totalVisits: 12, thisMonth: 3),
    );

    expect(find.text('Total Visit'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Visit Bulan Ini'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    // "Dengan Titik GPS" dihitung dari jumlah pin, bukan dari server — jadi
    // angkanya mustahil bertentangan dengan peta di belakangnya.
    expect(find.text('Dengan Titik GPS'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('peta kosong padahal ada kunjungan: dijelaskan, bukan dibiarkan', (
    tester,
  ) async {
    await _pump(
      tester,
      const [],
      summary: const VisitTrackingSummary(totalVisits: 12, thisMonth: 3),
    );

    // Inilah satu-satunya isi layar lama yang butuh angka dari server: tanpa
    // totalVisits, "belum pernah berkunjung" dan "berkunjung tanpa koordinat"
    // sama-sama tampil sebagai peta kosong.
    expect(find.text('Belum ada kunjungan dengan titik GPS'), findsOneWidget);
    expect(find.textContaining('12 kunjungan tercatat'), findsOneWidget);
    expect(find.textContaining('izinkan akses lokasi'), findsOneWidget);
  });

  testWidgets('belum ada kunjungan sama sekali: kalimatnya berbeda', (
    tester,
  ) async {
    await _pump(tester, const [],
        summary: const VisitTrackingSummary(totalVisits: 0));

    expect(find.textContaining('Belum ada kunjungan tercatat'), findsOneWidget);
    expect(find.textContaining('kunjungan tercatat, tapi'), findsNothing);
  });

  testWidgets('popup membawa bukti kunjungan: badge GPS + koordinatnya', (
    tester,
  ) async {
    await _pump(tester, [_loc(visitId: 'v1')]);

    await tester.tap(find.byIcon(Icons.location_on));
    await tester.pump();

    expect(find.text('GPS Verified'), findsOneWidget);
    expect(find.textContaining('-6.15000'), findsOneWidget);
    // Kunjungan uji ini tanpa foto — placeholder-nya yang muncul, bukan ruang
    // kosong yang membingungkan.
    expect(find.text('Tanpa foto'), findsOneWidget);
  });
}
