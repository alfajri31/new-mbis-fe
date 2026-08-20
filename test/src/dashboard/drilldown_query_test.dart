import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mbis/src/dashboard/dashboard_repository.dart';
import 'package:mbis/src/network/api_client.dart';

/// CR-09 — kategori terpilih ikut dikirim ke drill-down.
///
/// Yang diuji perakitan query-nya, bukan angkanya: tahun dan kategori sama-sama
/// opsional, jadi ada empat kombinasi dan satu tanda tanya/ampersand yang salah
/// membuat server mengabaikan kategori TANPA error apa pun — layar tetap tampil,
/// hanya angkanya diam-diam angka semua produk.
class _CapturingApiClient extends ApiClient {
  _CapturingApiClient() : super();

  final List<String> paths = [];

  @override
  Future<http.Response> get(String path, {Duration? timeout}) async {
    paths.add(path);
    return http.Response(
      jsonEncode({
        'monthly': <dynamic>[],
        'byCob': <dynamic>[],
        'successRate': {'won': 0, 'decline': 0, 'total': 0, 'items': <dynamic>[]},
        'category': null,
      }),
      200,
    );
  }
}

void main() {
  test('tanpa tahun & kategori: path polos seperti sebelumnya', () async {
    final client = _CapturingApiClient();
    await DashboardRepository(apiClient: client).getDrilldown();

    expect(client.paths.single, '/api/dashboard/drilldown');
  });

  test('kategori saja: dipasang sebagai parameter pertama', () async {
    final client = _CapturingApiClient();
    await DashboardRepository(apiClient: client).getDrilldown(category: 'KUR');

    expect(client.paths.single, '/api/dashboard/drilldown?cob=KUR');
  });

  test('tahun + kategori: kategori disambung, bukan menimpa tahun', () async {
    final client = _CapturingApiClient();
    await DashboardRepository(apiClient: client)
        .getDrilldown(year: 2025, category: 'ASUM');

    expect(client.paths.single, '/api/dashboard/drilldown?year=2025&cob=ASUM');
  });

  test('kategori kosong diperlakukan seperti tanpa kategori', () async {
    final client = _CapturingApiClient();
    await DashboardRepository(apiClient: client).getDrilldown(category: '');

    expect(client.paths.single, '/api/dashboard/drilldown');
  });

  test('kategori dipantulkan server yang dipakai, bukan yang diminta', () {
    // Server memperlakukan kategori tak dikenal sebagai "tanpa penyaringan" dan
    // memantulkan null; model harus meneruskan apa adanya supaya layar tidak
    // memberi label kategori pada angka yang sebenarnya semua produk.
    final parsed = DashboardDrilldown.fromJson({
      'monthly': [
        {'label': 'Jan 2026', 'visits': 10, 'visitsKur': 4, 'visitsCategory': 0},
      ],
      'category': null,
    });

    expect(parsed.category, isNull);
    expect(parsed.monthly.single.visits, 10);
    expect(parsed.monthly.single.visitsKur, 4);
    expect(parsed.monthly.single.visitsCategory, 0);
  });
}
