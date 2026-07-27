import 'dart:convert';
import '../network/api_client.dart';

/// One co-insurer share on a won tender.
class TenderShare {
  final String? partyType; // LEADER | MEMBER
  final String? name;
  final double? percentage;
  const TenderShare({this.partyType, this.name, this.percentage});
  factory TenderShare.fromJson(Map<String, dynamic> j) => TenderShare(
        partyType: j['partyType'],
        name: j['name'],
        percentage: j['percentage'] != null ? (j['percentage'] as num).toDouble() : null,
      );
}

/// One tender in the report (won or lost), labelled by its Nama Tender.
class TenderItem {
  final String pipelineId;
  final String? tenderName;
  final String? customerName;
  final double? premi; // won
  final double? shareAskrindo; // won, %
  final String? lossReason; // loss
  final List<TenderShare> shares; // won

  const TenderItem({
    required this.pipelineId,
    this.tenderName,
    this.customerName,
    this.premi,
    this.shareAskrindo,
    this.lossReason,
    this.shares = const [],
  });

  String get title => (tenderName != null && tenderName!.isNotEmpty)
      ? tenderName!
      : (customerName ?? 'Tender tanpa nama');

  factory TenderItem.fromJson(Map<String, dynamic> j) => TenderItem(
        pipelineId: j['pipelineId'] ?? '',
        tenderName: j['tenderName'],
        customerName: j['customerName'],
        premi: j['premi'] != null ? (j['premi'] as num).toDouble() : null,
        shareAskrindo:
            j['shareAskrindo'] != null ? (j['shareAskrindo'] as num).toDouble() : null,
        lossReason: j['lossReason'],
        shares: (j['shares'] as List<dynamic>? ?? [])
            .map((s) => TenderShare.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class TenderReport {
  final int wonCount;
  final int lossCount;
  final int activeCount; // P3/P2/P1; counted in winRate, not listed
  final List<TenderItem> won;
  final List<TenderItem> loss;

  const TenderReport({
    this.wonCount = 0,
    this.lossCount = 0,
    this.activeCount = 0,
    this.won = const [],
    this.loss = const [],
  });

  /// Tenders the report actually lists — drives the filter chips and the bar.
  int get total => wonCount + lossCount;

  /// Every tender that exists, including ones still being bid.
  int get totalWithActive => total + activeCount;

  double get winRate => totalWithActive > 0 ? wonCount / totalWithActive : 0;

  factory TenderReport.fromJson(Map<String, dynamic> j) => TenderReport(
        wonCount: j['wonCount'] ?? 0,
        lossCount: j['lossCount'] ?? 0,
        activeCount: j['activeCount'] ?? 0,
        won: (j['won'] as List<dynamic>? ?? [])
            .map((e) => TenderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        loss: (j['loss'] as List<dynamic>? ?? [])
            .map((e) => TenderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TenderRepository {
  final ApiClient apiClient;
  TenderRepository({required this.apiClient});

  Future<TenderReport> getReport() async {
    final response = await apiClient.get('/api/tenders/report');
    if (response.statusCode != 200) {
      throw Exception('Failed to load tender report');
    }
    return TenderReport.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}
