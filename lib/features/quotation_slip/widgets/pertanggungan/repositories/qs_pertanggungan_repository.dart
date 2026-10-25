import 'dart:convert';
import 'dart:typed_data';
import 'package:mbis/src/network/api_client.dart';
import 'qs_pertanggungan_model.dart';

abstract class QsPertanggunganRepository {
  Future<QsPertanggunganResponse> getPertanggungan({
    required String pipelineId,
    required String productCode,
  });

  Future<QuotationSlipResponse> saveQuotationSlip({
    required String pipelineId,
    required String productCode,
    required Map<String, dynamic> payload,
  });

  Future<Uint8List> getPreviewQsPdf({
    required String pipelineId,
    required String productCode,
  });
}

class ApiQsPertanggunganRepository implements QsPertanggunganRepository {
  final ApiClient apiClient;

  ApiQsPertanggunganRepository({required this.apiClient});

  @override
  Future<QsPertanggunganResponse> getPertanggungan({
    required String pipelineId,
    required String productCode,
  }) async {
    final encodedCode = Uri.encodeComponent(productCode);
    final url = '/api/pipelines/$pipelineId/quotation-slips/$encodedCode';
    final response = await apiClient.get(url);
    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('payload') &&
            decoded['payload'] is Map<String, dynamic>) {
          final payloadMap =
              Map<String, dynamic>.from(decoded['payload'] as Map);
          if (decoded['id'] != null) {
            payloadMap['id'] = decoded['id'];
          }
          return QsPertanggunganResponse.fromJson(payloadMap);
        }
        return QsPertanggunganResponse.fromJson(decoded);
      }
      throw Exception('Format data quotation-slips tidak valid');
    }
    String errorMsg = 'Gagal memuat data pertanggungan (${response.statusCode})';
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['message'] != null &&
            decoded['message'].toString().isNotEmpty) {
          errorMsg = decoded['message'].toString();
        } else if (decoded['error'] != null &&
            decoded['error'].toString().isNotEmpty) {
          errorMsg = decoded['error'].toString();
        }
      } else if (response.body.isNotEmpty) {
        errorMsg = response.body;
      }
    } catch (_) {
      if (response.body.isNotEmpty) {
        errorMsg = response.body;
      }
    }
    throw Exception(errorMsg);
  }

  @override
  Future<QuotationSlipResponse> saveQuotationSlip({
    required String pipelineId,
    required String productCode,
    required Map<String, dynamic> payload,
  }) async {
    final encodedCode = Uri.encodeComponent(productCode);
    final url = '/api/pipelines/$pipelineId/quotation-slips/$encodedCode';
    final response = await apiClient.post(url, body: payload);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return QuotationSlipResponse.fromJson(decoded);
      }
      throw Exception('Format respon quotation-slips tidak valid');
    }

    String errorMsg = 'Gagal menyimpan quotation slip (${response.statusCode})';
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['message'] != null &&
            decoded['message'].toString().isNotEmpty) {
          errorMsg = decoded['message'].toString();
        } else if (decoded['error'] != null &&
            decoded['error'].toString().isNotEmpty) {
          errorMsg = decoded['error'].toString();
        }
      } else if (response.body.isNotEmpty) {
        errorMsg = response.body;
      }
    } catch (_) {
      if (response.body.isNotEmpty) {
        errorMsg = response.body;
      }
    }
    throw Exception(errorMsg);
  }

  @override
  Future<Uint8List> getPreviewQsPdf({
    required String pipelineId,
    required String productCode,
  }) async {
    final encodedCode = Uri.encodeComponent(productCode);
    final url =
        '/api/pipelines/$pipelineId/quotation-slips/$encodedCode/preview-qs';
    final response = await apiClient.get(
      url,
      headers: const {
        'Accept': 'application/pdf, application/json, */*',
      },
    );

    if (response.statusCode == 200) {
      final bytes = response.bodyBytes;
      // 1. Cek jika bytes langsung berformat biner PDF (%PDF-)
      if (bytes.length >= 4 &&
          bytes[0] == 0x25 && // %
          bytes[1] == 0x50 && // P
          bytes[2] == 0x44 && // D
          bytes[3] == 0x46) { // F
        return bytes;
      }

      // 2. Cek jika respon dibungkus JSON (mis. {"pdf": "...", "data": "..."})
      try {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final b64 = decoded['pdf'] ??
              decoded['data'] ??
              decoded['base64'] ??
              decoded['content'] ??
              decoded['file'];
          if (b64 is String && b64.isNotEmpty) {
            final clean = b64.contains(',') ? b64.split(',').last : b64;
            return base64Decode(clean.trim());
          }
        }
      } catch (_) {
        // Bukan format JSON, lanjutkan cek base64 murni
      }

      // 3. Cek jika respon berupa string base64 murni (dimulai dengan JVBERi)
      try {
        final text = response.body.trim();
        if (text.startsWith('JVBERi') || text.startsWith('data:application/pdf')) {
          final clean = text.contains(',') ? text.split(',').last : text;
          return base64Decode(clean.trim());
        }
      } catch (_) {}

      // Fallback: kembalikan langsung bodyBytes
      return bytes;
    }

    String errorMsg = 'Gagal memuat preview PDF QS (${response.statusCode})';
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['message'] != null &&
            decoded['message'].toString().isNotEmpty) {
          errorMsg = decoded['message'].toString();
        } else if (decoded['error'] != null &&
            decoded['error'].toString().isNotEmpty) {
          errorMsg = decoded['error'].toString();
        }
      } else if (response.body.isNotEmpty) {
        errorMsg = response.body;
      }
    } catch (_) {
      if (response.body.isNotEmpty) {
        errorMsg = response.body;
      }
    }
    throw Exception(errorMsg);
  }
}

class MockQsPertanggunganRepository implements QsPertanggunganRepository {
  final QsPertanggunganResponse? mockData;
  final QuotationSlipResponse? mockSaveResponse;
  final Uint8List? mockPdfBytes;
  final bool shouldThrow;

  const MockQsPertanggunganRepository({
    this.mockData,
    this.mockSaveResponse,
    this.mockPdfBytes,
    this.shouldThrow = false,
  });

  @override
  Future<QsPertanggunganResponse> getPertanggungan({
    required String pipelineId,
    required String productCode,
  }) async {
    if (shouldThrow) {
      throw Exception('Mock network error');
    }
    return mockData ?? QsPertanggunganResponse();
  }

  @override
  Future<QuotationSlipResponse> saveQuotationSlip({
    required String pipelineId,
    required String productCode,
    required Map<String, dynamic> payload,
  }) async {
    if (shouldThrow) {
      throw Exception('Mock network error');
    }
    return mockSaveResponse ?? QuotationSlipResponse();
  }

  @override
  Future<Uint8List> getPreviewQsPdf({
    required String pipelineId,
    required String productCode,
  }) async {
    if (shouldThrow) {
      throw Exception('Mock network error');
    }
    return mockPdfBytes ?? Uint8List(0);
  }
}
