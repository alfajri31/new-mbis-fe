import 'dart:convert';
import '../network/api_client.dart';

class CustomerListModel {
  final String id;
  final String name;
  final String? entityCategory;
  final String? state;
  final bool isBlacklisted;
  final int pipelineCount;
  final double totalPotential;
  final double totalRealization;

  CustomerListModel({
    required this.id,
    required this.name,
    this.entityCategory,
    this.state,
    this.isBlacklisted = false,
    required this.pipelineCount,
    required this.totalPotential,
    required this.totalRealization,
  });

  factory CustomerListModel.fromJson(Map<String, dynamic> json) {
    return CustomerListModel(
      id: json['id'],
      name: json['name'],
      entityCategory: json['entityCategory'],
      state: json['state'],
      isBlacklisted: json['isBlacklisted'] == true,
      pipelineCount: json['pipelineCount'] ?? 0,
      totalPotential: (json['totalPotential'] ?? 0).toDouble(),
      totalRealization: (json['totalRealization'] ?? 0).toDouble(),
    );
  }
}

/// One page of the server-paginated customer list (infinite scroll).
class CustomerListPage {
  final List<CustomerListModel> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  CustomerListPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory CustomerListPage.fromJson(Map<String, dynamic> json) {
    return CustomerListPage(
      content: (json['content'] as List<dynamic>?)
              ?.map((e) => CustomerListModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      page: json['page'] ?? 0,
      size: json['size'] ?? 0,
      totalElements: json['totalElements'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      last: json['last'] ?? true,
    );
  }
}

/// Customer count per entity category (BUMN/Swasta/…), for the list header stats.
class CustomerStat {
  final String category;
  final int count;
  CustomerStat({required this.category, required this.count});
  factory CustomerStat.fromJson(Map<String, dynamic> json) => CustomerStat(
        category: json['category'] ?? json['entityCategory'] ?? '-',
        count: json['count'] ?? 0,
      );
}

/// Header KPIs for the Customer screen: total customers + their pipeline stage
/// breakdown. Tracks the same scope + search/entity filters as the list.
class CustomerKpi {
  final int totalCustomer;
  final int p3;
  final int p2;
  final int p1;
  final int won;
  final int decline;

  const CustomerKpi({
    this.totalCustomer = 0,
    this.p3 = 0,
    this.p2 = 0,
    this.p1 = 0,
    this.won = 0,
    this.decline = 0,
  });

  factory CustomerKpi.fromJson(Map<String, dynamic> json) => CustomerKpi(
        totalCustomer: json['totalCustomer'] ?? 0,
        p3: json['p3'] ?? 0,
        p2: json['p2'] ?? 0,
        p1: json['p1'] ?? 0,
        won: json['won'] ?? 0,
        decline: json['decline'] ?? 0,
      );
}

class CustomerDocumentModel {
  final String id;
  final String docType;
  final String fileName;
  final String fileUrl; // relative path served by /api/files/**

  CustomerDocumentModel({
    required this.id,
    required this.docType,
    required this.fileName,
    required this.fileUrl,
  });

  factory CustomerDocumentModel.fromJson(Map<String, dynamic> json) {
    return CustomerDocumentModel(
      id: json['id'] ?? '',
      docType: json['docType'] ?? '',
      fileName: json['fileName'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
    );
  }

  bool get isImage {
    final n = fileName.toLowerCase();
    return n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png') || n.endsWith('.gif') || n.endsWith('.webp');
  }
}

/// One step of a BUMN customer's hierarchy path (holding → … → this node).
class BumnPathNode {
  final String name;
  final String? level; // Induk | Anak | Cucu | Cicit
  const BumnPathNode({required this.name, this.level});
  factory BumnPathNode.fromJson(Map<String, dynamic> j) =>
      BumnPathNode(name: j['name'] ?? '', level: j['level']);
}

class CustomerDetailModel {
  final String id;
  final String name;
  final String? cifNumber;
  final String? legalEntity;
  final String? entityCategory;
  final String? category;
  final String? strukturRelasi;
  final bool isBumn;
  final bool isHvc;
  final String? bumnName;
  final List<BumnPathNode> bumnPath; // Holding → … → this node
  final bool isBlacklisted;
  final String? state;
  final String? npwp;
  final String? nib;
  final String? nik;
  final String? picTitle;
  final String? address;
  final String? companyEmail;
  final String? companyPhone;
  final String? latitude;
  final String? longitude;
  final String? picName;
  final String? picPhone;
  final String? picJabatan;
  /// Boleh mengubah customer ini? Ditentukan SERVER (pembuat / RM pemegang).
  /// Hak lihat lebih luas dari hak ubah, jadi flag ini tidak bisa disimpulkan
  /// dari peran saja.
  final bool canEdit;
  final String? assignedRmName; // RM penanggung jawab
  final String? sourceType;     // AGENT | RM
  final String? sourceName;     // nama agen / RM yang mendata
  final int p3Count;
  final int p2Count;
  final int p1Count;
  final double potential;
  final double realization;
  final List<CustomerDocumentModel> documents;

  CustomerDetailModel({
    required this.id,
    required this.name,
    this.cifNumber,
    this.legalEntity,
    this.entityCategory,
    this.category,
    this.strukturRelasi,
    this.isBumn = false,
    this.isHvc = false,
    this.bumnName,
    this.bumnPath = const [],
    this.isBlacklisted = false,
    this.state,
    this.npwp,
    this.nib,
    this.nik,
    this.picTitle,
    this.address,
    this.companyEmail,
    this.companyPhone,
    this.latitude,
    this.longitude,
    this.picName,
    this.picPhone,
    this.picJabatan,
    this.canEdit = false,
    this.assignedRmName,
    this.sourceType,
    this.sourceName,
    required this.p3Count,
    required this.p2Count,
    required this.p1Count,
    required this.potential,
    required this.realization,
    this.documents = const [],
  });

  factory CustomerDetailModel.fromJson(Map<String, dynamic> json) {
    final docsJson = json['documents'] as List<dynamic>? ?? [];
    return CustomerDetailModel(
      id: json['id'],
      canEdit: json['canEdit'] == true,
      name: json['name'],
      cifNumber: json['cifNumber'],
      legalEntity: json['legalEntity'],
      entityCategory: json['entityCategory'],
      category: json['category'],
      strukturRelasi: json['strukturRelasi'],
      isBumn: json['isBumn'] == true,
      isHvc: json['isHvc'] == true,
      bumnName: json['bumnName'],
      bumnPath: (json['bumnPath'] as List<dynamic>? ?? [])
          .map((e) => BumnPathNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      isBlacklisted: json['isBlacklisted'] == true,
      state: json['state'],
      npwp: json['npwp'],
      nib: json['nib'],
      nik: json['nik'],
      picTitle: json['picTitle'],
      address: json['address'],
      companyEmail: json['companyEmail'],
      companyPhone: json['companyPhone'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      picName: json['picName'],
      picPhone: json['picPhone'],
      picJabatan: json['picJabatan'],
      assignedRmName: json['assignedRmName'],
      sourceType: json['sourceType'],
      sourceName: json['sourceName'],
      p3Count: json['p3Count'] ?? 0,
      p2Count: json['p2Count'] ?? 0,
      p1Count: json['p1Count'] ?? 0,
      potential: (json['potential'] ?? 0).toDouble(),
      realization: (json['realization'] ?? 0).toDouble(),
      documents: docsJson
          .map((d) => CustomerDocumentModel.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BlacklistMatch {
  final String providerName;
  final String? npwp;
  final String? address;
  final String confidence; // HIGH | MEDIUM | LOW
  final List<String> matchedBy;
  final int score;
  final String? skNumber;
  final String? violation;
  final String? startDate;
  final String? expiredDate;

  BlacklistMatch({
    required this.providerName,
    this.npwp,
    this.address,
    required this.confidence,
    required this.matchedBy,
    required this.score,
    this.skNumber,
    this.violation,
    this.startDate,
    this.expiredDate,
  });

  factory BlacklistMatch.fromJson(Map<String, dynamic> json) {
    return BlacklistMatch(
      providerName: json['providerName'] ?? '-',
      npwp: json['npwp'],
      address: json['address'],
      confidence: json['confidence'] ?? 'LOW',
      matchedBy: (json['matchedBy'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      score: json['score'] ?? 0,
      skNumber: json['skNumber'],
      violation: json['violation'],
      startDate: json['startDate'],
      expiredDate: json['expiredDate'],
    );
  }
}

class BlacklistSource {
  final String source;
  final String status;
  BlacklistSource({required this.source, required this.status});
  factory BlacklistSource.fromJson(Map<String, dynamic> json) =>
      BlacklistSource(source: json['source'] ?? '', status: json['status'] ?? '');
}

/// A possible duplicate surfaced at customer creation (national, minimal fields).
class SimilarCustomer {
  final String customerId;
  final String name;
  final String? entityCategory;
  final String? officeName; // branch it already lives in
  final String? rmName; // owning RM
  final int score; // 0-100
  final String confidence; // HIGH | MEDIUM | LOW
  final List<String> matchedBy; // NPWP | NAME_EXACT | NAME_FUZZY

  SimilarCustomer({
    required this.customerId,
    required this.name,
    this.entityCategory,
    this.officeName,
    this.rmName,
    required this.score,
    required this.confidence,
    required this.matchedBy,
  });

  factory SimilarCustomer.fromJson(Map<String, dynamic> j) => SimilarCustomer(
        customerId: j['customerId']?.toString() ?? '',
        name: j['name']?.toString() ?? '-',
        entityCategory: j['entityCategory'] as String?,
        officeName: j['officeName'] as String?,
        rmName: j['rmName'] as String?,
        score: (j['score'] ?? 0) as int,
        confidence: j['confidence']?.toString() ?? 'LOW',
        matchedBy: (j['matchedBy'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  /// Human label for why this matched, in Indonesian.
  String get reason {
    if (matchedBy.contains('NPWP')) return 'NPWP sama';
    if (matchedBy.contains('NAME_EXACT')) return 'Nama sama persis';
    return 'Nama mirip';
  }
}

class BlacklistCheckResult {
  final String status; // CLEAN | WARNING | ERROR
  final String? checkedAt;
  final bool? npwpValid;
  final List<BlacklistSource> sources;
  final List<BlacklistMatch> matches;

  BlacklistCheckResult({
    required this.status,
    this.checkedAt,
    this.npwpValid,
    required this.sources,
    required this.matches,
  });

  factory BlacklistCheckResult.fromJson(Map<String, dynamic> json) {
    return BlacklistCheckResult(
      status: json['status'] ?? 'ERROR',
      checkedAt: json['checkedAt'],
      npwpValid: json['npwpValid'],
      sources: (json['sources'] as List?)
              ?.map((e) => BlacklistSource.fromJson(e))
              .toList() ??
          const [],
      matches: (json['matches'] as List?)
              ?.map((e) => BlacklistMatch.fromJson(e))
              .toList() ??
          const [],
    );
  }
}

/// Hasil pembuatan customer: data customer + hasil cek blacklist (status CLEAN/WARNING/ERROR).
class CustomerCreateResult {
  final CustomerListModel customer;
  final BlacklistCheckResult blacklist;
  CustomerCreateResult({required this.customer, required this.blacklist});
}

/// An RM an agent may refer a new customer to (within the agent's office subtree).
class AssignableRm {
  final String id;
  final String name;
  final String? officeName;

  AssignableRm({required this.id, required this.name, this.officeName});

  factory AssignableRm.fromJson(Map<String, dynamic> json) => AssignableRm(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        officeName: json['officeName'],
      );
}

class CustomerRepository {
  final ApiClient apiClient;

  CustomerRepository({required this.apiClient});

  Future<List<CustomerListModel>> getCustomers() async {
    final response = await apiClient.get('/api/customers');
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((j) => CustomerListModel.fromJson(j)).toList();
    } else {
      throw Exception('Failed to load customers');
    }
  }

  /// One page of the scope-aware customer list (server-side paged + filtered).
  /// [search] matches the customer name; [entity] filters by entity category.
  Future<CustomerListPage> getCustomersPaged({
    int page = 0,
    int size = 12,
    String? search,
    String? entity,
    String? regionId,
    String? branchId,
    String? rmId,
    bool hvc = false,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'size': '$size',
      if (search != null && search.isNotEmpty) 'search': search,
      if (entity != null && entity.isNotEmpty) 'entity': entity,
      if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (rmId != null && rmId.isNotEmpty) 'rmId': rmId,
      if (hvc) 'hvc': 'true',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final response = await apiClient.get('/api/customers/paged?$query');
    if (response.statusCode == 200) {
      return CustomerListPage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load customers');
    }
  }

  /// Customer count per entity category within the caller's scope (header stats).
  /// [search]/[entity] mirror the list filter so the header tracks what's shown.
  Future<List<CustomerStat>> getCustomerStats({
    String? search,
    String? entity,
    String? regionId,
    String? branchId,
    String? rmId,
  }) async {
    final params = <String, String>{
      if (search != null && search.isNotEmpty) 'search': search,
      if (entity != null && entity.isNotEmpty) 'entity': entity,
      if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (rmId != null && rmId.isNotEmpty) 'rmId': rmId,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final path = query.isEmpty ? '/api/customers/stats' : '/api/customers/stats?$query';
    final response = await apiClient.get(path);
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((j) => CustomerStat.fromJson(j)).toList();
    } else {
      throw Exception('Failed to load customer stats');
    }
  }

  /// Header KPIs: total customer + pipeline stage breakdown (P3/P2/P1/Won/Declined).
  /// [search]/[entity]/[regionId]/[branchId] mirror the list filter so the KPI tracks
  /// what's shown.
  Future<CustomerKpi> getCustomerKpi({
    String? search,
    String? entity,
    String? regionId,
    String? branchId,
    String? rmId,
    bool hvc = false,
  }) async {
    final params = <String, String>{
      if (search != null && search.isNotEmpty) 'search': search,
      if (entity != null && entity.isNotEmpty) 'entity': entity,
      if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (rmId != null && rmId.isNotEmpty) 'rmId': rmId,
      if (hvc) 'hvc': 'true',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final path = query.isEmpty ? '/api/customers/kpi' : '/api/customers/kpi?$query';
    final response = await apiClient.get(path);
    if (response.statusCode == 200) {
      return CustomerKpi.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load customer KPI');
    }
  }

  /// Customers across the logged-in agent's pipelines (agent portal).
  Future<List<CustomerListModel>> getAgentCustomers() async {
    final response = await apiClient.get('/api/agents/me/customers');
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((j) => CustomerListModel.fromJson(j)).toList();
    } else {
      throw Exception('Failed to load customers');
    }
  }

  Future<CustomerDetailModel> getCustomerDetail(String id) async {
    final response = await apiClient.get('/api/customers/$id');
    if (response.statusCode == 200) {
      return CustomerDetailModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load customer detail');
    }
  }

  /// Simpan customer + cek blacklist (atomik di backend, WARNING-ONLY).
  /// Customer selalu tersimpan; hasil cek (CLEAN/WARNING/ERROR) hanya jadi peringatan.
  Future<CustomerCreateResult> addCustomer(Map<String, dynamic> data) async {
    final response = await apiClient.post('/api/customers', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body);
      return CustomerCreateResult(
        customer: CustomerListModel.fromJson(json['customer']),
        blacklist: BlacklistCheckResult.fromJson(json['blacklist']),
      );
    } else {
      throw Exception('Gagal menyimpan customer');
    }
  }

  /// RMs the logged-in agent may refer a new customer to (agent's office subtree).
  Future<List<AssignableRm>> getAssignableRms() async {
    final response = await apiClient.get('/api/customers/assignable-rms');
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((j) => AssignableRm.fromJson(j)).toList();
    } else {
      throw Exception('Gagal memuat daftar RM');
    }
  }

  /// Preview cek blacklist atas data customer SEBELUM disimpan (tidak menyimpan apa pun).
  Future<BlacklistCheckResult> previewBlacklist(Map<String, dynamic> data) async {
    final response =
        await apiClient.post('/api/customers/blacklist-check', body: data);
    if (response.statusCode == 200) {
      return BlacklistCheckResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Gagal melakukan pengecekan blacklist');
    }
  }

  /// Customer lintas-cabang yang mungkin entitas sama dengan yang akan dibuat.
  /// Nasional, info minimal — dipakai untuk mencegah swasta multi-cabang pecah.
  Future<List<SimilarCustomer>> similarCustomers({required String name, String? npwp}) async {
    final q = <String>[
      'name=${Uri.encodeQueryComponent(name)}',
      if (npwp != null && npwp.isNotEmpty) 'npwp=${Uri.encodeQueryComponent(npwp)}',
    ].join('&');
    final response = await apiClient.get('/api/customers/similar?$q');
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((e) => SimilarCustomer.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Gagal mengecek customer serupa');
  }

  /// Edit an existing customer.
  Future<void> updateCustomer(String customerId, Map<String, dynamic> data) async {
    final response = await apiClient.put('/api/customers/$customerId', body: data);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Gagal menyimpan perubahan customer');
    }
  }

  /// Batalkan penyimpanan customer ("Tidak Jadi Simpan").
  Future<void> deleteCustomer(String customerId) async {
    final response = await apiClient.delete('/api/customers/$customerId');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Gagal membatalkan penyimpanan');
    }
  }

  /// Cek blacklist untuk customer yang sudah tersimpan (warning-only).
  Future<BlacklistCheckResult> checkBlacklist(String customerId) async {
    final response =
        await apiClient.post('/api/customers/$customerId/blacklist-check');
    if (response.statusCode == 200) {
      return BlacklistCheckResult.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Gagal melakukan pengecekan blacklist');
    }
  }

  Future<void> uploadDocument(
      String customerId, String docType, List<int> bytes, String fileName) async {
    final response = await apiClient.postMultipart(
      '/api/customers/$customerId/documents',
      fields: {'docType': docType},
      fileField: 'file',
      fileBytes: bytes,
      fileName: fileName,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to upload document ($docType)');
    }
  }

  Future<void> deleteDocument(String customerId, String docId) async {
    final response = await apiClient.delete('/api/customers/$customerId/documents/$docId');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete document');
    }
  }
}
