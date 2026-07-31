import 'dart:convert';
import '../network/api_client.dart';

/// Impor excel target bulanan RM (admin). Mirror `TargetImportController`
/// (`/api/admin/import/targets`) di backend.
class TargetImportRepository {
  final ApiClient apiClient;

  TargetImportRepository({required this.apiClient});

  /// File target setahun untuk banyak RM bisa besar; beri ruang lebih dari
  /// timeout API biasa (30 dtk).
  static const Duration _timeout = Duration(minutes: 5);

  /// Unduh template .xlsx (header + 12 baris contoh + sheet Petunjuk).
  Future<({List<int> bytes, String fileName})> downloadTemplate(int year) async {
    final res = await apiClient.get('/api/admin/import/targets/template?year=$year',
        timeout: _timeout);
    if (res.statusCode == 200) {
      final cd = res.headers['content-disposition'] ?? '';
      final m = RegExp(r'filename="?([^";]+)"?').firstMatch(cd);
      return (
        bytes: res.bodyBytes,
        fileName: m?.group(1) ?? 'template-target-rm-$year.xlsx',
      );
    }
    throw Exception(_message(res.body, 'Gagal mengunduh template'));
  }

  /// Unggah excel target. [year] dipakai untuk baris yang kolom Tahun-nya kosong;
  /// [syncYearly] ikut menulis target setahun (dipakai kartu Manajemen RM).
  Future<TargetImportResult> importTargets(
    List<int> bytes,
    String fileName, {
    required int year,
    required bool syncYearly,
  }) async {
    final res = await apiClient.postMultipart(
      '/api/admin/import/targets',
      fields: {'year': '$year', 'syncYearly': '$syncYearly'},
      fileField: 'file',
      fileBytes: bytes,
      fileName: fileName,
    );
    if (res.statusCode == 200) {
      return TargetImportResult.fromJson(jsonDecode(res.body));
    }
    throw Exception(_message(res.body, 'Gagal mengimpor target'));
  }

  static String _message(String body, String fallback) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['message'] is String) return j['message'] as String;
    } catch (_) {}
    return fallback;
  }
}

/// Ringkasan hasil impor target (mirror TargetImportResponse backend).
class TargetImportResult {
  final int year;
  final int rows;
  final int upserted;
  final int failed;
  final int rmCount;
  final int yearlyUpdated;
  final List<({int row, String message})> errors;

  const TargetImportResult({
    required this.year,
    required this.rows,
    required this.upserted,
    required this.failed,
    required this.rmCount,
    required this.yearlyUpdated,
    required this.errors,
  });

  factory TargetImportResult.fromJson(Map<String, dynamic> j) {
    final list = (j['errors'] as List<dynamic>? ?? const [])
        .map((e) => (
              row: (e['row'] ?? 0) as int,
              message: (e['message'] ?? '').toString(),
            ))
        .toList();
    return TargetImportResult(
      year: (j['year'] ?? 0) as int,
      rows: (j['rows'] ?? 0) as int,
      upserted: (j['upserted'] ?? 0) as int,
      failed: (j['failed'] ?? 0) as int,
      rmCount: (j['rmCount'] ?? 0) as int,
      yearlyUpdated: (j['yearlyUpdated'] ?? 0) as int,
      errors: list,
    );
  }
}
