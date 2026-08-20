import 'dart:convert';
import '../network/api_client.dart';
import '../common/partner_kpi.dart';
import '../../utils/format.dart';

/// Minimal customer reference carried on a BUMN pipeline link (id + name).
class BumnCustomer {
  final String id;
  final String name;
  const BumnCustomer(this.id, this.name);
}

/// One pipeline owned by a BUMN customer, with its customer and premi.
class BumnLink {
  final String pipelineId;
  final String stage; // backend: P3 | P2 | P1 | WON | DECLINE
  final double? premi;
  final BumnCustomer customer;

  const BumnLink({
    required this.pipelineId,
    required this.stage,
    this.premi,
    required this.customer,
  });

  bool get isActive => stage != 'WON' && stage != 'DECLINE';
  String get premiShort => premi != null ? AppFormat.currencyShort(premi!) : '-';
}

/// A BUMN customer (the entity itself; mirrors BrokerModel).
class BumnModel {
  final String id;
  final String name;
  final String? bumnName;       // induk BUMN
  final String? strukturRelasi; // Induk | Anak | Cucu | Cicit
  final String? entityCategory;

  const BumnModel({
    required this.id,
    required this.name,
    this.bumnName,
    this.strukturRelasi,
    this.entityCategory,
  });

  /// Initials derived from the BUMN name.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final p = parts.first;
      return (p.length >= 2 ? p.substring(0, 2) : p).toUpperCase();
    }
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  /// Subtitle for the card: prefer the induk name, else the relation level.
  String get subtitle {
    if (bumnName != null && bumnName!.isNotEmpty) return 'Induk: $bumnName';
    if (strukturRelasi != null && strukturRelasi!.isNotEmpty) return strukturRelasi!;
    return 'BUMN';
  }
}

/// Aggregate view consumed by the BUMN screen (mirrors BrokerView).
class BumnView {
  final BumnModel bumn;
  final List<BumnLink> links;

  const BumnView({required this.bumn, required this.links});

  int get pipelineCount => links.length;
  int get activePipelineCount => links.where((l) => l.isActive).length;
  int get wonCount => links.where((l) => l.stage == 'WON').length;
  bool get hasConnections => links.isNotEmpty;

  num get totalPremiIdr => links.fold<num>(0, (sum, l) => sum + (l.premi ?? 0));
  String get totalPremiShort => AppFormat.currencyShort(totalPremiIdr);
}

/// One node of the BUMN ecosystem tree (master_bumn), with nested children.
class BumnTreeNode {
  final String id;
  final String name;
  final String? level;      // Induk | Anak | Cucu | Cicit
  final String? badanHukum; // PT | PT Tbk | CV | UD | Lainnya
  final bool hasPipeline;   // node ini punya customer dgn >=1 pipeline
  final List<BumnTreeNode> children;

  const BumnTreeNode({
    required this.id,
    required this.name,
    this.level,
    this.badanHukum,
    this.hasPipeline = false,
    this.children = const [],
  });

  bool get hasChildren => children.isNotEmpty;

  /// Total keturunan (anak + cucu + …) di bawah node ini.
  int get descendantCount =>
      children.fold<int>(0, (sum, c) => sum + 1 + c.descendantCount);

  /// True bila node ini ATAU salah satu turunannya punya pipeline.
  bool get subtreeHasPipeline =>
      hasPipeline || children.any((c) => c.subtreeHasPipeline);

  factory BumnTreeNode.fromJson(Map<String, dynamic> j) => BumnTreeNode(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        level: j['level'],
        badanHukum: j['badanHukum'],
        hasPipeline: j['hasPipeline'] == true,
        children: (j['children'] as List<dynamic>? ?? [])
            .map((c) => BumnTreeNode.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

/// One master_bumn node for the customer BUMN picker (flat). Carries [level]
/// (= struktur relasi) and [parentName] (induk) so the customer form derives them
/// automatically instead of asking the user.
class BumnOption {
  final String id;
  final String name;
  final String? level; // Induk | Anak | Cucu | Cicit
  final String? badanHukum;
  final String? parentName; // induk

  BumnOption({
    required this.id,
    required this.name,
    this.level,
    this.badanHukum,
    this.parentName,
  });

  factory BumnOption.fromJson(Map<String, dynamic> j) => BumnOption(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        level: j['level']?.toString(),
        badanHukum: j['badanHukum']?.toString(),
        parentName: j['parentName']?.toString(),
      );
}

/// One node of the BUMN screen's pruned tree: the ecosystem trimmed to branches
/// that contain a customer. Ancestor nodes are kept as the drill-down path even
/// without a customer/pipeline of their own. Customer nodes carry their pipelines.
class BumnTreeCustomer {
  final String id;
  final String name;
  final String? level;      // Induk | Anak | Cucu | Cicit
  final String? badanHukum;
  final bool hasCustomer;
  final int pipelineCount;
  final int wonCount;
  final List<BumnLink> links;
  final PartnerKpi own; // stats for this node alone (its own pipelines)
  final PartnerKpi subtree; // aggregated stats for this node + all descendants
  final List<BumnTreeCustomer> children;

  const BumnTreeCustomer({
    required this.id,
    required this.name,
    this.level,
    this.badanHukum,
    this.hasCustomer = false,
    this.pipelineCount = 0,
    this.wonCount = 0,
    this.links = const [],
    this.own = const PartnerKpi(),
    this.subtree = const PartnerKpi(),
    this.children = const [],
  });

  bool get hasChildren => children.isNotEmpty;

  factory BumnTreeCustomer.fromJson(Map<String, dynamic> j) => BumnTreeCustomer(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        level: j['level'],
        badanHukum: j['badanHukum'],
        hasCustomer: j['hasCustomer'] == true,
        pipelineCount: j['pipelineCount'] ?? 0,
        wonCount: j['wonCount'] ?? 0,
        own: j['own'] != null
            ? PartnerKpi.fromJson(j['own'] as Map<String, dynamic>)
            : const PartnerKpi(),
        subtree: j['subtree'] != null
            ? PartnerKpi.fromJson(j['subtree'] as Map<String, dynamic>)
            : const PartnerKpi(),
        links: (j['links'] as List<dynamic>? ?? []).map((l) {
          final m = l as Map<String, dynamic>;
          return BumnLink(
            pipelineId: m['pipelineId'] ?? '',
            stage: m['stage'] ?? '',
            premi: m['premi'] != null ? (m['premi'] as num).toDouble() : null,
            customer: BumnCustomer(m['customerId'] ?? '', m['customerName'] ?? ''),
          );
        }).toList(),
        children: (j['children'] as List<dynamic>? ?? [])
            .map((c) => BumnTreeCustomer.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class BumnRepository {
  final ApiClient apiClient;

  BumnRepository({required this.apiClient});

  /// Flat list of active BUMN nodes for the customer BUMN picker.
  Future<List<BumnOption>> getBumnOptions() async {
    final response = await apiClient.get('/api/bumns/options');
    if (response.statusCode != 200) {
      throw Exception('Failed to load BUMN options');
    }
    final List<dynamic> list = jsonDecode(response.body);
    return list.map((j) => BumnOption.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Pruned BUMN tree for the screen: branches that contain a customer, with
  /// ancestors kept as the drill-down path (GET /api/bumns/customer-tree).
  ///
  /// Ter-scope di server: hanya cabang yang customer-nya masuk cakupan pemanggil
  /// (RM miliknya sendiri, atasan cabang sesuai hirarki kantornya, peran kantor
  /// pusat nasional). Klien tidak menyaring apa pun — jangan menambahkan filter
  /// cakupan di sini, karena yang mengikat hanya penyaringan di server.
  Future<List<BumnTreeCustomer>> getBumnCustomerTree() async {
    final response = await apiClient.get('/api/bumns/customer-tree');
    if (response.statusCode != 200) {
      throw Exception('Failed to load BUMN tree');
    }
    final List<dynamic> list = jsonDecode(response.body);
    return list
        .map((j) => BumnTreeCustomer.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Simpul BUMN (dari ekosistem master ±515 node) yang punya pipeline DALAM
  /// CAKUPAN pemanggil. Dulu endpoint ini nasional untuk siapa pun; sejak
  /// cakupannya dipaksa di server, RM hanya menerima miliknya sendiri.
  Future<List<BumnView>> getBumnViews() async {
    final response = await apiClient.get('/api/bumns');
    if (response.statusCode != 200) {
      throw Exception('Failed to load BUMN');
    }
    final List<dynamic> list = jsonDecode(response.body);
    return list.map((j) => _toView(j as Map<String, dynamic>)).toList();
  }

  /// KPI layar BUMN. `total` = ukuran ekosistem master (±515) dan tetap angka
  /// global — ia penyebut untuk "BUMN ber-Pipeline". Sisanya (with-pipeline,
  /// ever-won, realisasi premi, rincian tahap) mengikuti cakupan pemanggil.
  Future<PartnerKpi> getBumnKpi() async {
    final response = await apiClient.get('/api/bumns/kpi');
    if (response.statusCode != 200) {
      throw Exception('Failed to load BUMN KPI');
    }
    return PartnerKpi.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// BUMN customers connected to the current RM (+ their pipelines). Legacy scoped view.
  Future<List<BumnView>> getMyBumnViews() async {
    final response = await apiClient.get('/api/bumns/mine');
    if (response.statusCode != 200) {
      throw Exception('Failed to load BUMN');
    }
    final List<dynamic> list = jsonDecode(response.body);
    return list.map((j) => _toView(j as Map<String, dynamic>)).toList();
  }

  /// Pohon ekosistem BUMN (master_bumn): daftar Induk dgn anak-cucu bersarang.
  Future<List<BumnTreeNode>> getBumnTree() async {
    final response = await apiClient.get('/api/bumns/tree');
    if (response.statusCode != 200) {
      throw Exception('Failed to load BUMN tree');
    }
    final List<dynamic> list = jsonDecode(response.body);
    return list.map((j) => BumnTreeNode.fromJson(j as Map<String, dynamic>)).toList();
  }

  BumnView _toView(Map<String, dynamic> j) {
    final links = (j['links'] as List<dynamic>? ?? []).map((l) {
      final m = l as Map<String, dynamic>;
      return BumnLink(
        pipelineId: m['pipelineId'] ?? '',
        stage: m['stage'] ?? '',
        premi: m['premi'] != null ? (m['premi'] as num).toDouble() : null,
        customer: BumnCustomer(m['customerId'] ?? '', m['customerName'] ?? ''),
      );
    }).toList();
    return BumnView(
      bumn: BumnModel(
        id: j['id'] ?? '',
        name: j['name'] ?? '',
        bumnName: j['bumnName'],
        strukturRelasi: j['strukturRelasi'],
        entityCategory: j['entityCategory'],
      ),
      links: links,
    );
  }
}
