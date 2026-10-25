import 'dart:convert';
import 'package:mbis/src/network/api_client.dart';
import 'product_classification_model.dart';

const String kPsakdiTocCode = 'PSAKDIPOLISSTANDARDASURANSIKECELAKAANDIRIINDONESIA';

abstract class QsProductClassificationRepository {
  Future<List<QsProductClassification>> getProductClassifications(String tocCode);
}

class ApiQsProductClassificationRepository implements QsProductClassificationRepository {
  final ApiClient apiClient;

  ApiQsProductClassificationRepository({required this.apiClient});

  @override
  Future<List<QsProductClassification>> getProductClassifications(String tocCode) async {
    final encodedTocCode = Uri.encodeComponent(tocCode);
    final url = '/api/qs/product-classifications/$encodedTocCode';
    final response = await apiClient.get(url);
    if (response.statusCode == 200) {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => QsProductClassification.fromJson(e))
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      }
      return const [];
    }
    throw Exception('Gagal memuat klasifikasi peserta (${response.statusCode})');
  }
}

class MockQsProductClassificationRepository implements QsProductClassificationRepository {
  final List<QsProductClassification>? mockList;
  final bool shouldThrow;

  const MockQsProductClassificationRepository({
    this.mockList,
    this.shouldThrow = false,
  });

  @override
  Future<List<QsProductClassification>> getProductClassifications(String tocCode) async {
    if (shouldThrow) {
      throw Exception('Mock network error');
    }
    return mockList ?? const [];
  }
}
