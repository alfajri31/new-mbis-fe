import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/presentation/screens/rm_performance_screen.dart';
import 'package:mbis/src/dashboard/dashboard_repository.dart';
import 'package:mbis/src/network/api_client.dart';

/// CR-06 — kartu KPI layar RM BENAR-BENAR memasang saringannya.
///
/// Roster RM ber-halaman, jadi kartunya menyaring daftar di bawahnya alih-alih
/// membuka banner. Yang dikunci di sini: nilai saringan yang dikirim ke server
/// untuk tiap kartu, dan bahwa menekan kartu yang sama dua kali melepaskannya
/// kembali. Nilainya tidak boleh asal — server menolak yang di luar daftar putih
/// dengan 400, jadi salah tulis di layar akan mematikan halaman ini sepenuhnya.
class _FakeDashboardRepository extends DashboardRepository {
  _FakeDashboardRepository() : super(apiClient: ApiClient());

  /// Semua nilai pipelineFilter yang diminta layar, berurutan.
  final List<String?> requested = [];

  @override
  Future<List<ScopeOffice>> getScopeOffices() async => [];

  @override
  Future<RmPerformancePage> getRmPerformance({
    int page = 0,
    int size = 20,
    String? search,
    String? regionId,
    String? branchId,
    bool connectOnly = false,
    String? pipelineFilter,
  }) async {
    requested.add(pipelineFilter);
    return RmPerformancePage(
      content: const [],
      page: page,
      size: size,
      totalElements: 0,
      totalPages: 1,
      last: true,
    );
  }
}

Future<_FakeDashboardRepository> _pump(WidgetTester tester) async {
  final repo = _FakeDashboardRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [dashboardRepoProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: RmPerformanceScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('tiap kartu mengirim saringan pipeline miliknya sendiri', (
    tester,
  ) async {
    final repo = await _pump(tester);
    final firstLoads = repo.requested.length;

    await tester.tap(find.text('RM Tanpa Pipeline'));
    await tester.pumpAndSettle();
    expect(repo.requested.last, 'NONE');

    await tester.tap(find.text('Pipeline Aktif'));
    await tester.pumpAndSettle();
    expect(repo.requested.last, 'ACTIVE');

    await tester.tap(find.text('Pipeline P3'));
    await tester.pumpAndSettle();
    expect(repo.requested.last, 'P3');

    await tester.tap(find.text('Pipeline Declined'));
    await tester.pumpAndSettle();
    expect(repo.requested.last, 'DECLINE');

    expect(
      repo.requested.length,
      greaterThan(firstLoads),
      reason: 'kartu yang ditekan harus memuat ulang daftarnya, bukan diam',
    );
  });

  testWidgets('menekan kartu yang sama dua kali melepas saringannya', (
    tester,
  ) async {
    final repo = await _pump(tester);

    await tester.tap(find.text('Pipeline P3'));
    await tester.pumpAndSettle();
    expect(repo.requested.last, 'P3');

    await tester.tap(find.text('Pipeline P3'));
    await tester.pumpAndSettle();
    expect(
      repo.requested.last,
      isNull,
      reason: 'tanpa jalan keluar, pemakai terjebak pada satu tahap',
    );
  });

  testWidgets('kartu "Total RM" melepas saringan dari kartu mana pun', (
    tester,
  ) async {
    final repo = await _pump(tester);

    await tester.tap(find.text('Pipeline Won'));
    await tester.pumpAndSettle();
    expect(repo.requested.last, 'WON');

    await tester.tap(find.text('Total RM'));
    await tester.pumpAndSettle();
    expect(repo.requested.last, isNull);
  });
}
