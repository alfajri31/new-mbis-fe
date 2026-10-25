import 'dart:convert';
import '../network/api_client.dart';
import '../../features/visit_rm/models/visit_monitor_models.dart';

/// Repository for the Visit Monitor API (`/api/visit-monitor/**`).
/// Handles request querying, deserialization, and HTTP error mapping.
class VisitMonitorRepository {
  final ApiClient apiClient;

  VisitMonitorRepository({required this.apiClient});

  /// GET /api/visit-monitor/summary
  /// Mengambil ringkasan metrik visit (total, active RM, idle RM, avg, reviewed)
  Future<VisitMonitorSummary> getSummary(VisitMonitorFilter filter) async {
    final params = filter.toQueryParams();
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final url = query.isEmpty
        ? '/api/visit-monitor/summary'
        : '/api/visit-monitor/summary?$query';

    final response = await apiClient.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return VisitMonitorSummary.fromJson(data);
      }
      throw Exception('Format data ringkasan tidak valid');
    } else {
      throw Exception('Gagal memuat ringkasan kunjungan (HTTP ${response.statusCode})');
    }
  }

  /// GET /api/visit-monitor/visits
  /// Mengambil daftar kunjungan terpaginasi
  Future<VisitMonitorPage<VisitMonitorRow>> getVisits({
    int page = 0,
    int size = 20,
    required VisitMonitorFilter filter,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'size': '$size',
      ...filter.toQueryParams(),
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final response = await apiClient.get('/api/visit-monitor/visits?$query');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return VisitMonitorPage<VisitMonitorRow>.fromJson(
          data,
          (item) => VisitMonitorRow.fromJson(item),
        );
      }
      throw Exception('Format data daftar kunjungan tidak valid');
    } else {
      throw Exception('Gagal memuat daftar kunjungan (HTTP ${response.statusCode})');
    }
  }

  /// GET /api/visit-monitor/rms
  /// Mengambil daftar RM dan aktivitas visit-nya terpaginasi
  Future<VisitMonitorPage<VisitMonitorRmRow>> getRms({
    int page = 0,
    int size = 20,
    required VisitMonitorFilter filter,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'size': '$size',
      ...filter.toQueryParams(),
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final response = await apiClient.get('/api/visit-monitor/rms?$query');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return VisitMonitorPage<VisitMonitorRmRow>.fromJson(
          data,
          (item) => VisitMonitorRmRow.fromJson(item),
        );
      }
      throw Exception('Format data daftar RM tidak valid');
    } else {
      throw Exception('Gagal memuat daftar RM (HTTP ${response.statusCode})');
    }
  }

  /// GET /api/visit-monitor/visits/{id}
  /// Mengambil detail lengkap kunjungan berdasarkan ID
  Future<VisitMonitorDetail> getVisitDetail(String id) async {
    final response = await apiClient.get('/api/visit-monitor/visits/$id');
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return VisitMonitorDetail.fromJson(data);
      }
      throw Exception('Format data detail kunjungan tidak valid');
    } else {
      throw Exception('Gagal memuat detail kunjungan (HTTP ${response.statusCode})');
    }
  }

  /// GET /api/export/visits
  /// Mengunduh data kunjungan dalam bentuk berkas Excel (.xlsx)
  Future<({List<int> bytes, String fileName})> exportVisits({
    required String from,
    required String to,
    String? regionId,
    String? branchId,
    String? rmId,
  }) async {
    final params = <String, String>{
      'from': from,
      'to': to,
      if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (rmId != null && rmId.isNotEmpty) 'rmId': rmId,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');

    final response = await apiClient.get(
      '/api/export/visits?$query',
      timeout: const Duration(minutes: 5),
    );
    if (response.statusCode == 200) {
      final cd = response.headers['content-disposition'] ?? '';
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
      return (
        bytes: response.bodyBytes,
        fileName: m?.group(1) ?? 'Visit_RM_${from}_$to.xlsx',
      );

    }
    throw Exception('Gagal mengekspor data kunjungan (HTTP ${response.statusCode})');
  }
}



