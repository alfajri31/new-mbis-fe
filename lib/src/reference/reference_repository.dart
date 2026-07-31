import 'dart:convert';
import '../network/api_client.dart';

/// A master-parameter option (dropdown item).
class ParamRef {
  final String key;
  final String value;
  ParamRef(this.key, this.value);
  factory ParamRef.fromJson(Map<String, dynamic> j) =>
      ParamRef(j['paramKey'] ?? '', j['paramValue'] ?? '');
}

/// One product row (ToC with its parent LOB and COB).
class ProductRef {
  final String tocCode;
  final String tocName;
  final String? lobName;
  final String? cobName;
  ProductRef(this.tocCode, this.tocName, this.lobName, this.cobName);
  factory ProductRef.fromJson(Map<String, dynamic> j) => ProductRef(
        j['tocCode'] ?? '',
        j['tocName'] ?? '',
        j['lobName'],
        j['cobName'],
      );
}

class BankRef {
  final String id;
  final String name;
  final String? tipeBank;
  BankRef(this.id, this.name, this.tipeBank);
  factory BankRef.fromJson(Map<String, dynamic> j) =>
      BankRef(j['id'] ?? '', j['name'] ?? '', j['tipeBank']);
}

class BankBranchRef {
  final String id;
  final String name;
  final String? address;
  BankBranchRef(this.id, this.name, this.address);
  factory BankBranchRef.fromJson(Map<String, dynamic> j) =>
      BankBranchRef(j['id'] ?? '', j['name'] ?? '', j['address']);
}

/// An agent/TPM visible to the current RM (already region-scoped by the backend).
class AgentRef {
  final String id;
  final String name;
  final String type; // AGENT | TPM
  final String status;
  AgentRef(this.id, this.name, this.type, this.status);
  factory AgentRef.fromJson(Map<String, dynamic> j) =>
      AgentRef(j['id'] ?? '', j['name'] ?? '', j['type'] ?? '', j['status'] ?? '');
}

/// Read-only reference data for dropdowns (parameters, products, banks).
class ReferenceRepository {
  final ApiClient apiClient;
  ReferenceRepository({required this.apiClient});

  Future<List<ParamRef>> parameters(String category) async {
    final res = await apiClient.get('/api/parameters?category=$category');
    if (res.statusCode != 200) return [];
    final List<dynamic> list = jsonDecode(res.body);
    return list
        .map((j) => ParamRef.fromJson(j))
        .where((p) => p.key.isNotEmpty)
        .toList();
  }

  Future<List<ProductRef>> products() async {
    final res = await apiClient.get('/api/master-products');
    if (res.statusCode != 200) return [];
    final List<dynamic> list = jsonDecode(res.body);
    return list.map((j) => ProductRef.fromJson(j)).toList();
  }

  Future<List<BankRef>> banks({String? type}) async {
    final res = await apiClient.get('/api/banks${type != null ? '?type=$type' : ''}');
    if (res.statusCode != 200) return [];
    final List<dynamic> list = jsonDecode(res.body);
    return list.map((j) => BankRef.fromJson(j)).toList();
  }

  /// Agents/TPM the current RM may attach to a pipeline (region-scoped by backend).
  Future<List<AgentRef>> agents() async {
    // scope=office: RM melihat agen aktif di subtree kantornya (dropdown sumber
    // pipeline), bukan hanya agen yang ia ajukan sendiri.
    final res = await apiClient.get('/api/agents?scope=office');
    if (res.statusCode != 200) return [];
    final List<dynamic> list = jsonDecode(res.body);
    return list.map((j) => AgentRef.fromJson(j)).toList();
  }

  Future<List<BankBranchRef>> branches(String bankId, {String q = ''}) async {
    final res = await apiClient
        .get('/api/banks/$bankId/branches?q=${Uri.encodeQueryComponent(q)}&limit=50');
    if (res.statusCode != 200) return [];
    final List<dynamic> list = jsonDecode(res.body);
    return list.map((j) => BankBranchRef.fromJson(j)).toList();
  }
}

/// Helper to navigate the flat product list as a COB -> LOB -> ToC cascade.
/// Driven by the human-readable names (codes in the source data are unreliable).
class ProductCascade {
  final List<ProductRef> all;
  ProductCascade(this.all);

  List<String> get cobs {
    final s = <String>{};
    for (final p in all) {
      if (p.cobName != null && p.cobName!.isNotEmpty) s.add(p.cobName!);
    }
    final list = s.toList()..sort();
    return list;
  }

  List<String> lobs(String cob) {
    final s = <String>{};
    for (final p in all) {
      if (p.cobName == cob && p.lobName != null && p.lobName!.isNotEmpty) {
        s.add(p.lobName!);
      }
    }
    final list = s.toList()..sort();
    return list;
  }

  List<ProductRef> tocs(String cob, String lob) {
    final list =
        all.where((p) => p.cobName == cob && p.lobName == lob).toList();
    list.sort((a, b) => a.tocName.compareTo(b.tocName));
    return list;
  }
}
