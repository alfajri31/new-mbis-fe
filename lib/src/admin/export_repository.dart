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

  // `downloadMyVisits` (`/api/export/visits/me`) dihapus bersama layar "Ekspor
  // Kunjungan Saya" (CR-13): satu-satunya pemakainya. [downloadScoped] dengan
  // dataset 'visits' memberi hasil yang sama persis untuk seorang RM — server
  // yang menggerbang scope-nya, jadi RM tanpa filter tetap hanya dapat miliknya.
  //
  // Endpoint backend-nya SENGAJA tidak ikut dihapus: klien lama yang belum
  // diperbarui masih memanggilnya, dan menghapusnya tidak memberi manfaat apa pun.

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

  /// Unduh template .xlsx impor pipeline (header + 1 baris contoh).
  Future<({List<int> bytes, String fileName})> downloadImportTemplate() async {
    final res = await apiClient.get('/api/admin/import/pipelines/template',
        timeout: _exportTimeout);
    if (res.statusCode == 200) {
      final cd = res.headers['content-disposition'] ?? '';
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
      return (
        bytes: res.bodyBytes,
        fileName: m?.group(1) ?? 'template-import-pipeline.xlsx',
      );
    }
    throw Exception(_message(res.body, 'Gagal mengunduh template'));
  }

  /// Impor excel pipeline WON (admin). Mengembalikan ringkasan hasil.
  Future<PipelineImportResult> importPipelines(
      List<int> bytes, String fileName) async {
    final res = await apiClient.postMultipart(
      '/api/admin/import/pipelines',
      fileField: 'file',
      fileBytes: bytes,
      fileName: fileName,
    );
    if (res.statusCode == 200) {
      return PipelineImportResult.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal mengimpor pipeline'));
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

/// Ringkasan hasil impor pipeline (mirror PipelineImportResponse backend).
class PipelineImportResult {
  final int total;
  final int inserted;
  final int skippedDuplicate;
  final int failed;
  final List<({int row, String message})> errors;

  const PipelineImportResult({
    required this.total,
    required this.inserted,
    required this.skippedDuplicate,
    required this.failed,
    required this.errors,
  });

  factory PipelineImportResult.fromJson(Map<String, dynamic> j) {
    final list = (j['errors'] as List<dynamic>? ?? const [])
        .map((e) => (
              row: (e['row'] ?? 0) as int,
              message: (e['message'] ?? '').toString(),
            ))
        .toList();
    return PipelineImportResult(
      total: (j['total'] ?? 0) as int,
      inserted: (j['inserted'] ?? 0) as int,
      skippedDuplicate: (j['skippedDuplicate'] ?? 0) as int,
      failed: (j['failed'] ?? 0) as int,
      errors: list,
    );
  }
}
