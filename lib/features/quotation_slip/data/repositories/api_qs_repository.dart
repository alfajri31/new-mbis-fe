import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../../../../src/network/api_client.dart';
import '../../domain/entities/qs_api_exception.dart';
import '../../domain/entities/qs_entities.dart';
import '../../domain/repositories/qs_repository.dart';

class ApiQsRepository implements QsRepository {
  final ApiClient apiClient;

  ApiQsRepository({required this.apiClient});

  String _extractErrorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['message'] != null &&
            decoded['message'].toString().trim().isNotEmpty) {
          return decoded['message'].toString().trim();
        }
        if (decoded['error'] != null &&
            decoded['error'].toString().trim().isNotEmpty) {
          return decoded['error'].toString().trim();
        }
      }
    } catch (_) {}
    return response.body.isNotEmpty
        ? response.body
        : 'Terjadi kesalahan pada server (${response.statusCode})';
  }

  void _throwIfError(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw QsApiException(response.statusCode, _extractErrorMessage(response));
    }
  }

  @override
  Future<Map<String, dynamic>> getPrefill({
    required String pipelineId,
    String? qsId,
    String? productCode,
  }) async {
    String url = '/api/pipelines/$pipelineId/quotation-slips/prefill';
    if (qsId != null && qsId.isNotEmpty) {
      url += '?qsId=${Uri.encodeComponent(qsId)}';
    }
    final response = await apiClient.get(url);
    _throwIfError(response);

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      if (decoded.containsKey('payload') &&
          decoded['payload'] is Map<String, dynamic>) {
        final payloadMap = Map<String, dynamic>.from(decoded['payload'] as Map);
        if (decoded['id'] != null) {
          payloadMap['id'] = decoded['id'];
        }
        return payloadMap;
      }
      return decoded;
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>> upsertQuotationSlip({
    required String pipelineId,
    String? productCode,
    required Map<String, dynamic> payload,
  }) async {
    String url = '/api/pipelines/$pipelineId/quotation-slips';
    if (productCode != null && productCode.trim().isNotEmpty) {
      url += '/${Uri.encodeComponent(productCode.trim())}';
    }

    final response = await apiClient.post(url, body: payload);
    _throwIfError(response);

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {};
  }

  @override
  Future<QsTotalBiayaResult> calculateTotalBiaya({
    required String pipelineId,
    required Map<String, dynamic> payload,
  }) async {
    final url =
        '/api/pipelines/$pipelineId/quotation-slips/total-biaya-asuransi';
    final response = await apiClient.post(url, body: payload);
    _throwIfError(response);

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return QsTotalBiayaResult.fromJson(decoded);
    }
    throw const QsApiException(500, 'Format hasil perhitungan biaya tidak valid');
  }

  @override
  Future<double> getSaranTarifFlat({
    required String pipelineId,
    required Map<String, dynamic> payload,
  }) async {
    final url =
        '/api/pipelines/$pipelineId/quotation-slips/saran-tarif-flat';
    final response = await apiClient.post(url, body: payload);
    _throwIfError(response);

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      if (decoded['saranFlatPerHari'] is num) {
        return (decoded['saranFlatPerHari'] as num).toDouble();
      } else if (decoded['saran'] is num) {
        return (decoded['saran'] as num).toDouble();
      } else if (decoded['tarifFlat'] is num) {
        return (decoded['tarifFlat'] as num).toDouble();
      }
    } else if (decoded is num) {
      return decoded.toDouble();
    }
    return 0.0;
  }

  @override
  Future<QsSubmitActionResult> submitAction({
    required String pipelineId,
    required String qsId,
    required Map<String, dynamic> payload,
  }) async {
    final url =
        '/api/pipelines/$pipelineId/quotation-slips/submit-action?qsId=${Uri.encodeComponent(qsId)}';
    final response = await apiClient.post(url, body: payload);
    _throwIfError(response);

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return QsSubmitActionResult.fromJson(decoded);
    }
    throw const QsApiException(500, 'Format hasil submit action tidak valid');
  }

  @override
  Future<Map<String, dynamic>> submitEmail({
    required String pipelineId,
    required String qsId,
  }) async {
    final body = {
      'pipelineId': pipelineId,
      'qsId': qsId,
    };
    try {
      final response = await apiClient.post(
        '/api/qs/quotations-slip/submit-email?qsId=${Uri.encodeComponent(qsId)}&pipelineId=${Uri.encodeComponent(pipelineId)}',
        body: body,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {};
      }
    } catch (_) {}

    final url =
        '/api/pipelines/$pipelineId/quotation-slips/submit?qsId=${Uri.encodeComponent(qsId)}';
    final response = await apiClient.post(url, body: body);
    _throwIfError(response);

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {};
  }

  @override
  Future<Map<String, dynamic>> sentToUnderwriting({
    required String pipelineId,
    required String qsId,
    required String reason,
  }) async {
    final body = {
      'pipelineId': pipelineId,
      'qsId': qsId,
      'reason': reason,
      'alasan': reason,
      'uwReason': reason,
    };
    try {
      final response = await apiClient.post(
        '/api/qs/quotations-slip/sent-to-underwriting?qsId=${Uri.encodeComponent(qsId)}&pipelineId=${Uri.encodeComponent(pipelineId)}',
        body: body,
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) return decoded;
        return {};
      }
    } catch (_) {}

    final url =
        '/api/pipelines/$pipelineId/quotation-slips/sent-to-underwriting?qsId=${Uri.encodeComponent(qsId)}';
    final response = await apiClient.post(
      url,
      body: body,
    );
    _throwIfError(response);

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return {};
  }

  @override
  Future<Uint8List> getPreviewPdf({
    required String pipelineId,
    required String productKey,
    String? qsId,
  }) async {
    String url =
        '/api/pipelines/$pipelineId/quotation-slips/${Uri.encodeComponent(productKey)}/preview-qs';
    if (qsId != null && qsId.isNotEmpty) {
      url += '?qsId=${Uri.encodeComponent(qsId)}';
    }

    final response = await apiClient.get(url);
    _throwIfError(response);
    return response.bodyBytes;
  }

  @override
  Future<List<QsRiwayatItem>> getRiwayat({
    int page = 0,
    int size = 20,
    String? pipelineId,
    String? productCode,
  }) async {
    String url = '/api/qs?page=$page&size=$size';
    if (pipelineId != null && pipelineId.isNotEmpty) {
      url += '&pipelineId=${Uri.encodeComponent(pipelineId)}';
    }
    if (productCode != null && productCode.isNotEmpty) {
      url += '&productCode=${Uri.encodeComponent(productCode)}';
    }

    final response = await apiClient.get(url);
    _throwIfError(response);

    final dynamic decoded = jsonDecode(response.body);
    List items = [];
    if (decoded is Map<String, dynamic>) {
      if (decoded['content'] is List) {
        items = decoded['content'] as List;
      } else if (decoded['data'] is List) {
        items = decoded['data'] as List;
      }
    } else if (decoded is List) {
      items = decoded;
    }

    return items
        .map((e) => QsRiwayatItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<List<QsApprovalItemData>> getListPersetujuanUw({
    int page = 0,
    int size = 20,
  }) async {
    final url = '/api/qs/list-persetujuan-uw?page=$page&size=$size';
    final response = await apiClient.get(url);
    _throwIfError(response);

    final dynamic decoded = jsonDecode(response.body);
    List items = [];
    if (decoded is Map<String, dynamic>) {
      if (decoded['content'] is List) {
        items = decoded['content'] as List;
      } else if (decoded['data'] is List) {
        items = decoded['data'] as List;
      }
    } else if (decoded is List) {
      items = decoded;
    }

    return items
        .map((e) =>
            QsApprovalItemData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<void> postUwDecision({
    required String qsId,
    required String action,
    String? uwReason,
  }) async {
    final url = '/api/qs/$qsId/uw-decision';
    final payload = <String, dynamic>{'action': action};
    if (uwReason != null && uwReason.isNotEmpty) {
      payload['uwReason'] = uwReason;
    }

    final response = await apiClient.post(url, body: payload);
    _throwIfError(response);
  }

  @override
  Future<void> saveDraft({required String qsId}) async {
    final url = '/api/qs/$qsId/save-draft';
    final response = await apiClient.post(url, body: {});
    _throwIfError(response);
  }
}
