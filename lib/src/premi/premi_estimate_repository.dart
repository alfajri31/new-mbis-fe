import 'dart:convert';
import '../network/api_client.dart';

/// Result of issuing an Estimasi Premi: the official document number + issuer
/// identity (RM & office) the client stamps onto the PDF.
class PremiEstimateResult {
  final String id;
  final String docNumber;
  final DateTime createdAt;
  final String rmName;
  final String rmNip;
  final String? officeBranchName;
  final String? officeRegionalName;

  PremiEstimateResult({
    required this.id,
    required this.docNumber,
    required this.createdAt,
    required this.rmName,
    required this.rmNip,
    required this.officeBranchName,
    required this.officeRegionalName,
  });

  factory PremiEstimateResult.fromJson(Map<String, dynamic> j) =>
      PremiEstimateResult(
        id: j['id']?.toString() ?? '',
        docNumber: j['docNumber']?.toString() ?? '',
        createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        rmName: j['rmName']?.toString() ?? '-',
        rmNip: j['rmNip']?.toString() ?? '',
        officeBranchName: j['officeBranchName']?.toString(),
        officeRegionalName: j['officeRegionalName']?.toString(),
      );
}

/// API access for proforma Estimasi Premi documents (POST create → returns a
/// numbered record; then upload the rendered PDF which the backend stores
/// gzip-compressed).
class PremiEstimateRepository {
  final ApiClient apiClient;
  PremiEstimateRepository({required this.apiClient});

  Future<PremiEstimateResult> create(Map<String, dynamic> body) async {
    final res = await apiClient.post('/api/premi-estimates', body: body);
    if (res.statusCode == 200) {
      return PremiEstimateResult.fromJson(
          jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception(_message(res.body, 'Gagal menerbitkan nomor dokumen'));
  }

  Future<void> uploadPdf(String id, List<int> pdfBytes) async {
    final res = await apiClient.postMultipart(
      '/api/premi-estimates/${Uri.encodeComponent(id)}/pdf',
      fileField: 'file',
      fileBytes: pdfBytes,
      fileName: '$id.pdf',
    );
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menyimpan PDF ke server'));
    }
  }

  String _message(String body, String fallback) {
    try {
      final j = jsonDecode(body);
      if (j is Map && j['message'] is String) return j['message'] as String;
    } catch (_) {}
    return fallback;
  }
}
