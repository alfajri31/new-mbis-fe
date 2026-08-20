import 'dart:convert';
import '../network/api_client.dart';
import '../common/partner_kpi.dart';
import '../../utils/format.dart';

/// Minimal customer reference carried on a broker link (id + name only).
class BrokerCustomer {
  final String id;
  final String name;
  const BrokerCustomer(this.id, this.name);
}

/// One pipeline a broker sourced, with its customer and premi.
class BrokerLink {
  final String pipelineId;
  final String stage; // backend: P3 | P2 | P1 | WON | DECLINE
  final double? premi;
  final BrokerCustomer customer;

  const BrokerLink({
    required this.pipelineId,
    required this.stage,
    this.premi,
    required this.customer,
  });

  bool get isActive => stage != 'WON' && stage != 'DECLINE';
  String get premiShort => premi != null ? AppFormat.currencyShort(premi!) : '-';
}

class BrokerModel {
  final String id;
  final String code;
  final String name;

  const BrokerModel({required this.id, required this.code, required this.name});

  /// Initials derived from the broker name (no separate field in the backend).
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

/// Aggregate view consumed by the broker screen (mirrors the old mock shape).
class BrokerView {
  final BrokerModel broker;
  final List<BrokerLink> links;

  const BrokerView({required this.broker, required this.links});

  int get pipelineCount => links.length;
  int get activePipelineCount => links.where((l) => l.isActive).length;
  int get wonCount => links.where((l) => l.stage == 'WON').length;
  bool get hasConnections => links.isNotEmpty;

  num get totalPremiIdr => links.fold<num>(0, (sum, l) => sum + (l.premi ?? 0));
  String get totalPremiShort => AppFormat.currencyShort(totalPremiIdr);

  /// Distinct connected customers in first-seen order (for the chips).
  List<BrokerCustomer> get connectedCustomers {
    final seen = <String>{};
    final out = <BrokerCustomer>[];
    for (final l in links) {
      if (l.customer.id.isNotEmpty && seen.add(l.customer.id)) out.add(l.customer);
    }
    return out;
  }
}

class BrokerRepository {
  final ApiClient apiClient;

  BrokerRepository({required this.apiClient});

  /// Brokers + their sourced pipelines, SCOPE-AWARE per caller (admin → nasional /
  /// seluruh broker, BM/RO → kantornya, RM → miliknya). Dipakai layar Broker.
  Future<List<BrokerView>> getBrokerViews() async {
    final response = await apiClient.get('/api/brokers');
    if (response.statusCode != 200) {
      throw Exception('Failed to load brokers');
    }
    final List<dynamic> list = jsonDecode(response.body);
    return list.map((j) => _toView(j as Map<String, dynamic>)).toList();
  }

  /// KPI broker. `total` tetap ukuran master list (150) — angka global — sedangkan
  /// with-pipeline, ever-won, realisasi premi, dan rincian tahap MENGIKUTI cakupan
  /// pemanggil sejak BUG-01; sebelumnya semuanya nasional untuk semua peran.
  Future<PartnerKpi> getBrokerKpi() async {
    final response = await apiClient.get('/api/brokers/kpi');
    if (response.statusCode != 200) {
      throw Exception('Failed to load broker KPI');
    }
    return PartnerKpi.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Full master-broker list for the Add/Edit Pipeline dropdown (all 150,
  /// unfiltered, no pipeline hydration). Uses /api/brokers/options.
  Future<List<BrokerModel>> getBrokerOptions() async {
    final response = await apiClient.get('/api/brokers/options');
    if (response.statusCode != 200) {
      throw Exception('Failed to load brokers');
    }
    final List<dynamic> list = jsonDecode(response.body);
    return list
        .map((j) => BrokerModel(
              id: j['id'] ?? '',
              code: j['brokerCode'] ?? '',
              name: j['name'] ?? '',
            ))
        .toList();
  }

  /// Only brokers the current RM has pipelines with (Broker screen).
  Future<List<BrokerView>> getMyBrokerViews() async {
    final response = await apiClient.get('/api/brokers/mine');
    if (response.statusCode != 200) {
      throw Exception('Failed to load brokers');
    }
    final List<dynamic> list = jsonDecode(response.body);
    return list.map((j) => _toView(j as Map<String, dynamic>)).toList();
  }

  BrokerView _toView(Map<String, dynamic> j) {
    final links = (j['links'] as List<dynamic>? ?? []).map((l) {
      final m = l as Map<String, dynamic>;
      return BrokerLink(
        pipelineId: m['pipelineId'] ?? '',
        stage: m['stage'] ?? '',
        premi: m['premi'] != null ? (m['premi'] as num).toDouble() : null,
        customer: BrokerCustomer(m['customerId'] ?? '', m['customerName'] ?? ''),
      );
    }).toList();
    return BrokerView(
      broker: BrokerModel(
        id: j['id'] ?? '',
        code: j['brokerCode'] ?? '',
        name: j['name'] ?? '',
      ),
      links: links,
    );
  }
}
