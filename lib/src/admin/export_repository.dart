import 'dart:convert';
import '../network/api_client.dart';

/// Admin Excel export (report kinerja): customer / pipeline / visit dalam
/// rentang tanggal. Mirrors ExportController (`/api/admin/export/*`) on the
/// backend.
class ExportRepository {
  final ApiClient apiClient;

  ExportRepository({required this.apiClient});

  /// Export rentang panjang bisa lebih lama dari timeout API biasa (30 dtk).
  static const Duration _exportTimeout = Duration(minutes: 5);

  /// Downloads one dataset as an .xlsx file. [dataset] is the backend path
  /// segment: 'customers' | 'pipelines' | 'visits'. Range is inclusive on both ends.
  Future<({List<int> bytes, String fileName})> download(
      String dataset, DateTime from, DateTime to) async {
    final f = _date(from), t = _date(to);
    final res = await apiClient.get('/api/admin/export/$dataset?from=$f&to=$t',
        timeout: _exportTimeout);
    if (res.statusCode == 200) {
      final cd = res.headers['content-disposition'] ?? '';
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
      return (
        bytes: res.bodyBytes,
        fileName: m?.group(1) ?? 'export-$dataset-$f-$t.xlsx',
      );
    }
    throw Exception(_message(res.body, 'Gagal mengekspor data'));
  }

  /// RM self-service export — same report shape as [download]('visits', ...),
  /// but scoped server-side to the logged-in RM's own visits (item 11,
  /// after-piloting feedback).
  Future<({List<int> bytes, String fileName})> downloadMyVisits(
      DateTime from, DateTime to) async {
    final f = _date(from), t = _date(to);
    final res = await apiClient.get('/api/export/visits/me?from=$f&to=$t',
        timeout: _exportTimeout);
    if (res.statusCode == 200) {
      final cd = res.headers['content-disposition'] ?? '';
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
      return (
        bytes: res.bodyBytes,
        fileName: m?.group(1) ?? 'export-visit-saya-$f-$t.xlsx',
      );
    }
    throw Exception(_message(res.body, 'Gagal mengekspor data'));
  }

  /// Scoped export ("Ekspor Data"): [dataset] = 'pipelines' | 'visits' dalam rentang
  /// tanggal. Di-scope server (RM → miliknya, atasan → subtree cabang); atasan bisa
  /// mempersempit dengan filter wilayah/cabang/RM. Mirror `/api/export/{dataset}`.
  Future<({List<int> bytes, String fileName})> downloadScoped(
    String dataset,
    DateTime from,
    DateTime to, {
    String? regionId,
    String? branchId,
    String? rmId,
  }) async {
    final f = _date(from), t = _date(to);
    final params = <String, String>{
      'from': f,
      'to': t,
      if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (rmId != null && rmId.isNotEmpty) 'rmId': rmId,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final res = await apiClient.get('/api/export/$dataset?$query',
        timeout: _exportTimeout);
    if (res.statusCode == 200) {
      final cd = res.headers['content-disposition'] ?? '';
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
      return (
        bytes: res.bodyBytes,
        fileName: m?.group(1) ?? 'export-$dataset-$f-$t.xlsx',
      );
    }
    throw Exception(_message(res.body, 'Gagal mengekspor data'));
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _message(String body, String fallback) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['message'] is String) return j['message'] as String;
    } catch (_) {}
    return fallback;
  }
}
