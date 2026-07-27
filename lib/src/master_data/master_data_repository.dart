import 'dart:convert';
import '../network/api_client.dart';

/// A master parameter row (dropdown/reference value), e.g. a Badan Hukum option or
/// a COB jenis with its rate in [numericValue].
class ParameterItem {
  final String id;
  final String category;
  final String paramKey;
  final String paramValue;
  final double? numericValue;
  final int sortOrder;
  final bool active;

  ParameterItem({
    required this.id,
    required this.category,
    required this.paramKey,
    required this.paramValue,
    this.numericValue,
    required this.sortOrder,
    required this.active,
  });

  factory ParameterItem.fromJson(Map<String, dynamic> j) => ParameterItem(
        id: j['id'] as String,
        category: j['category']?.toString() ?? '',
        paramKey: j['paramKey']?.toString() ?? '',
        paramValue: j['paramValue']?.toString() ?? '',
        numericValue: (j['numericValue'] as num?)?.toDouble(),
        sortOrder: (j['sortOrder'] ?? 0) as int,
        active: (j['active'] ?? true) as bool,
      );
}

/// One "Jenis Produk" card (title + detail).
class JenisItem {
  final String title;
  final String detail;
  JenisItem({required this.title, required this.detail});

  factory JenisItem.fromJson(Map<String, dynamic> j) =>
      JenisItem(title: j['title']?.toString() ?? '', detail: j['detail']?.toString() ?? '');

  Map<String, dynamic> toJson() => {'title': title, 'detail': detail};
}

/// A Product Knowledge category (reference data from /api/product-categories).
class ProductCategoryItem {
  final String id;
  final String name;
  final String? icon;
  final String? colorHex;
  final int sortOrder;

  ProductCategoryItem({
    required this.id,
    required this.name,
    this.icon,
    this.colorHex,
    required this.sortOrder,
  });

  factory ProductCategoryItem.fromJson(Map<String, dynamic> j) => ProductCategoryItem(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        icon: j['icon'] as String?,
        colorHex: j['colorHex'] as String?,
        sortOrder: (j['sortOrder'] ?? 0) as int,
      );
}

/// A Product Knowledge catalog entry.
class ProductItem {
  final String id;
  final String name;
  final String lini;
  final String? categoryId;
  final String? icon;
  final String? description;
  final List<String> manfaat;
  final List<JenisItem> jenis;
  // quickFacts
  final String? premi;
  final String? masaPertanggungan;
  final String? nilaiPertanggungan;
  // section prosa
  final String? skemaPembayaran;
  final String? skemaUrl;
  final String? simulasi;
  // section daftar
  final List<String> biaya;
  final List<String> pengecualian;
  final List<String> persyaratan;
  final List<String> tataCara;
  final List<String> persyaratanKlaim;
  final List<String> tataCaraKlaim;
  final List<String> risiko;
  final int sortOrder;
  final bool active;

  ProductItem({
    required this.id,
    required this.name,
    required this.lini,
    this.categoryId,
    this.icon,
    this.description,
    required this.manfaat,
    this.jenis = const [],
    this.premi,
    this.masaPertanggungan,
    this.nilaiPertanggungan,
    this.skemaPembayaran,
    this.skemaUrl,
    this.simulasi,
    this.biaya = const [],
    this.pengecualian = const [],
    this.persyaratan = const [],
    this.tataCara = const [],
    this.persyaratanKlaim = const [],
    this.tataCaraKlaim = const [],
    this.risiko = const [],
    required this.sortOrder,
    required this.active,
  });

  static List<String> _list(dynamic v) =>
      (v as List<dynamic>? ?? const []).map((e) => e.toString()).toList();

  ProductItem copyWith({bool? active}) => ProductItem(
        id: id,
        name: name,
        lini: lini,
        categoryId: categoryId,
        icon: icon,
        description: description,
        manfaat: manfaat,
        jenis: jenis,
        premi: premi,
        masaPertanggungan: masaPertanggungan,
        nilaiPertanggungan: nilaiPertanggungan,
        skemaPembayaran: skemaPembayaran,
        skemaUrl: skemaUrl,
        simulasi: simulasi,
        biaya: biaya,
        pengecualian: pengecualian,
        persyaratan: persyaratan,
        tataCara: tataCara,
        persyaratanKlaim: persyaratanKlaim,
        tataCaraKlaim: tataCaraKlaim,
        risiko: risiko,
        sortOrder: sortOrder,
        active: active ?? this.active,
      );

  factory ProductItem.fromJson(Map<String, dynamic> j) => ProductItem(
        id: j['id'] as String,
        name: j['name']?.toString() ?? '',
        lini: j['lini']?.toString() ?? '',
        categoryId: j['categoryId'] as String?,
        icon: j['icon'] as String?,
        description: j['description'] as String?,
        manfaat: _list(j['manfaat']),
        jenis: (j['jenis'] as List<dynamic>? ?? const [])
            .map((e) => JenisItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        premi: j['premi'] as String?,
        masaPertanggungan: j['masaPertanggungan'] as String?,
        nilaiPertanggungan: j['nilaiPertanggungan'] as String?,
        skemaPembayaran: j['skemaPembayaran'] as String?,
        skemaUrl: j['skemaUrl'] as String?,
        simulasi: j['simulasi'] as String?,
        biaya: _list(j['biaya']),
        pengecualian: _list(j['pengecualian']),
        persyaratan: _list(j['persyaratan']),
        tataCara: _list(j['tataCara']),
        persyaratanKlaim: _list(j['persyaratanKlaim']),
        tataCaraKlaim: _list(j['tataCaraKlaim']),
        risiko: _list(j['risiko']),
        sortOrder: (j['sortOrder'] ?? 0) as int,
        active: (j['active'] ?? true) as bool,
      );
}

/// A master broker.
class BrokerItem {
  final String id;
  final String brokerCode;
  final String name;

  BrokerItem({required this.id, required this.brokerCode, required this.name});

  factory BrokerItem.fromJson(Map<String, dynamic> j) => BrokerItem(
        id: j['id'] as String,
        brokerCode: j['brokerCode']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
      );
}

/// A master product (ToC) with its agent commission rate. [commissionRate] is a
/// fraction (0.10 = 10%); null means "no per-product rate set" (backend uses its
/// default). The UI shows/edits it as a percentage.
class MasterProductRate {
  final String tocCode;
  final String tocName;
  final String? lobName;
  final String? cobName;
  final bool active;
  final double? commissionRate;

  MasterProductRate({
    required this.tocCode,
    required this.tocName,
    this.lobName,
    this.cobName,
    this.active = true,
    this.commissionRate,
  });

  factory MasterProductRate.fromJson(Map<String, dynamic> j) => MasterProductRate(
        tocCode: j['tocCode']?.toString() ?? '',
        tocName: j['tocName']?.toString() ?? '',
        lobName: j['lobName']?.toString(),
        cobName: j['cobName']?.toString(),
        active: j['active'] as bool? ?? true,
        commissionRate: j['commissionRate'] != null
            ? (j['commissionRate'] as num).toDouble()
            : null,
      );

  /// Commission as a percentage for display (e.g. 0.10 -> 10.0), null if unset.
  double? get percent => commissionRate == null ? null : commissionRate! * 100;
}

/// A bank (induk) for the admin editor. tipeBank 'HIMBARA' marks a bank BUMN.
class BankItem {
  final String id;
  final String name;
  final String? tipeBank;

  BankItem({required this.id, required this.name, this.tipeBank});

  factory BankItem.fromJson(Map<String, dynamic> j) => BankItem(
        id: j['id'] as String,
        name: j['name']?.toString() ?? '',
        tipeBank: j['tipeBank']?.toString(),
      );
}

/// A bank branch (cabang); its address auto-fills a banking customer's alamat.
class BankBranchItem {
  final String id;
  final String bankId;
  final String name;
  final String? cifNo;
  final String? address;
  final String? kodeUnitKerja;
  final String? tipeBank;

  BankBranchItem({
    required this.id,
    required this.bankId,
    required this.name,
    this.cifNo,
    this.address,
    this.kodeUnitKerja,
    this.tipeBank,
  });

  factory BankBranchItem.fromJson(Map<String, dynamic> j) => BankBranchItem(
        id: j['id'] as String,
        bankId: j['bankId']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        cifNo: j['cifNo']?.toString(),
        address: j['address']?.toString(),
        kodeUnitKerja: j['kodeUnitKerja']?.toString(),
        tipeBank: j['tipeBank']?.toString(),
      );
}

/// One master_bumn node (pohon ekosistem BUMN) for the admin editor: DB columns
/// as-is plus [parentName] for display. [parentId] null = Induk teratas.
class BumnMasterItem {
  final String id;
  final String name;
  final String? level; // Induk | Anak | Cucu | Cicit
  final String? badanHukum; // PT | PT Tbk | CV | UD | Lainnya
  final String? parentId;
  final String? parentName;
  final bool active;

  BumnMasterItem({
    required this.id,
    required this.name,
    this.level,
    this.badanHukum,
    this.parentId,
    this.parentName,
    this.active = true,
  });

  factory BumnMasterItem.fromJson(Map<String, dynamic> j) => BumnMasterItem(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        level: j['level']?.toString(),
        badanHukum: j['badanHukum']?.toString(),
        parentId: j['parentId']?.toString(),
        parentName: j['parentName']?.toString(),
        active: j['isActive'] as bool? ?? true,
      );
}

/// One office row for the admin "Kelola Kantor" editor. [type] is REGIONAL|BRANCH|KUP.
/// [parentId] null = no parent (a kanwil, or a kantor cabang utama without kanwil).
class OfficeAdminItem {
  final String id;
  final String name;
  final String type;
  final String? parentId;
  final String? parentName;
  final bool active;

  OfficeAdminItem({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.parentName,
    this.active = true,
  });

  factory OfficeAdminItem.fromJson(Map<String, dynamic> j) => OfficeAdminItem(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        type: j['type']?.toString() ?? '',
        parentId: j['parentId']?.toString(),
        parentName: j['parentName']?.toString(),
        active: j['active'] as bool? ?? true,
      );
}

/// API access for admin-editable master data: parameters (dropdowns + rates),
/// products, brokers, banks, and the BUMN ecosystem tree. Reads are open to any
/// authenticated user (BUMN admin list is ADMIN-only); writes 403 for non-admins.
class MasterDataRepository {
  final ApiClient apiClient;

  MasterDataRepository({required this.apiClient});

  // ── Parameters ────────────────────────────────────────────────────────────

  /// Parameters, optionally by [category]. [activeOnly] false is for the admin editor.
  Future<List<ParameterItem>> getParameters({String? category, bool activeOnly = true}) async {
    final q = StringBuffer('/api/parameters?activeOnly=$activeOnly');
    if (category != null && category.isNotEmpty) {
      q.write('&category=${Uri.encodeQueryComponent(category)}');
    }
    final res = await apiClient.get(q.toString());
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => ParameterItem.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat parameter'));
  }

  Future<List<String>> getCategories() async {
    final res = await apiClient.get('/api/parameters/categories');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((e) => e.toString()).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat kategori'));
  }

  Future<void> saveParameter({
    String? id,
    required String category,
    String? paramKey,
    required String paramValue,
    double? numericValue,
    int? sortOrder,
    bool active = true,
  }) async {
    final body = {
      'category': category,
      'paramKey': paramKey,
      'paramValue': paramValue,
      'numericValue': numericValue,
      'sortOrder': sortOrder,
      'active': active,
    };
    final res = id == null
        ? await apiClient.post('/api/parameters', body: body)
        : await apiClient.put('/api/parameters/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menyimpan parameter'));
    }
  }

  Future<void> deleteParameter(String id) async {
    final res = await apiClient.delete('/api/parameters/$id');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menghapus parameter'));
    }
  }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<List<ProductItem>> getProducts({bool activeOnly = true}) async {
    final res = await apiClient.get('/api/products?activeOnly=$activeOnly');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => ProductItem.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat produk'));
  }

  Future<List<ProductCategoryItem>> getProductCategories() async {
    final res = await apiClient.get('/api/product-categories');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => ProductCategoryItem.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat kategori produk'));
  }

  Future<ProductCategoryItem> saveProductCategory({
    String? id,
    required String name,
    String? icon,
    String? colorHex,
    int? sortOrder,
  }) async {
    final body = {
      'name': name,
      'icon': icon,
      'colorHex': colorHex,
      'sortOrder': sortOrder,
    };
    final res = id == null
        ? await apiClient.post('/api/product-categories', body: body)
        : await apiClient.put('/api/product-categories/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menyimpan kategori'));
    }
    return ProductCategoryItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteProductCategory(String id) async {
    final res = await apiClient.delete('/api/product-categories/$id');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menghapus kategori'));
    }
  }

  Future<ProductItem> saveProduct({
    String? id,
    required String name,
    required String lini,
    String? categoryId,
    List<JenisItem> jenis = const [],
    String? icon,
    String? description,
    List<String> manfaat = const [],
    String? premi,
    String? masaPertanggungan,
    String? nilaiPertanggungan,
    String? skemaPembayaran,
    String? skemaUrl,
    String? simulasi,
    List<String> biaya = const [],
    List<String> pengecualian = const [],
    List<String> persyaratan = const [],
    List<String> tataCara = const [],
    List<String> persyaratanKlaim = const [],
    List<String> tataCaraKlaim = const [],
    List<String> risiko = const [],
    int? sortOrder,
    bool active = true,
  }) async {
    final body = {
      'name': name,
      'lini': lini,
      'categoryId': categoryId,
      'jenis': jenis.map((j) => j.toJson()).toList(),
      'icon': icon,
      'description': description,
      'manfaat': manfaat,
      'premi': premi,
      'masaPertanggungan': masaPertanggungan,
      'nilaiPertanggungan': nilaiPertanggungan,
      'skemaPembayaran': skemaPembayaran,
      'skemaUrl': skemaUrl,
      'simulasi': simulasi,
      'biaya': biaya,
      'pengecualian': pengecualian,
      'persyaratan': persyaratan,
      'tataCara': tataCara,
      'persyaratanKlaim': persyaratanKlaim,
      'tataCaraKlaim': tataCaraKlaim,
      'risiko': risiko,
      'sortOrder': sortOrder,
      'active': active,
    };
    final res = id == null
        ? await apiClient.post('/api/products', body: body)
        : await apiClient.put('/api/products/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menyimpan produk'));
    }
    return ProductItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Nyalakan/matikan produk tanpa menyentuh field lain (PATCH `active` saja).
  Future<void> setProductActive({required String id, required bool active}) async {
    final res = await apiClient.put('/api/products/$id', body: {'active': active});
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal mengubah status produk'));
    }
  }

  Future<void> deleteProduct(String id) async {
    final res = await apiClient.delete('/api/products/$id');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menghapus produk'));
    }
  }

  // ── Brokers ───────────────────────────────────────────────────────────────

  Future<List<BrokerItem>> getBrokers() async {
    final res = await apiClient.get('/api/brokers/options');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => BrokerItem.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat broker'));
  }

  Future<void> saveBroker({String? id, required String brokerCode, required String name}) async {
    final body = {'brokerCode': brokerCode, 'name': name};
    final res = id == null
        ? await apiClient.post('/api/brokers', body: body)
        : await apiClient.put('/api/brokers/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menyimpan broker'));
    }
  }

  Future<void> deleteBroker(String id) async {
    final res = await apiClient.delete('/api/brokers/$id');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menghapus broker'));
    }
  }

  // ── Commission rate per product (ToC) ──────────────────────────────────────

  Future<List<MasterProductRate>> getMasterProductRates() async {
    final res = await apiClient.get('/api/admin/master-products');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list
          .map((j) => MasterProductRate.fromJson(j as Map<String, dynamic>))
          .toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat rate komisi produk'));
  }

  /// [commissionRate] is a fraction (0.10 = 10%).
  Future<void> updateCommissionRate(String tocCode, double commissionRate) async {
    final res = await apiClient.put(
      '/api/admin/master-products/${Uri.encodeComponent(tocCode)}/commission-rate',
      body: {'commissionRate': commissionRate},
    );
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menyimpan rate komisi'));
    }
  }

  // ── Banks + branches (admin) ────────────────────────────────────────────────

  Future<List<BankItem>> getBanks() async {
    final res = await apiClient.get('/api/admin/banks');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => BankItem.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat bank'));
  }

  Future<void> saveBank({String? id, required String name, String? tipeBank}) async {
    final body = {'name': name, 'tipeBank': tipeBank};
    final res = id == null
        ? await apiClient.post('/api/admin/banks', body: body)
        : await apiClient.put('/api/admin/banks/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menyimpan bank'));
    }
  }

  Future<void> deleteBank(String id) async {
    final res = await apiClient.delete('/api/admin/banks/$id');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menghapus bank'));
    }
  }

  Future<List<BankBranchItem>> getBankBranches(String bankId) async {
    final res = await apiClient.get('/api/admin/banks/$bankId/branches');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => BankBranchItem.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat cabang'));
  }

  Future<void> saveBankBranch(
    String bankId, {
    String? id,
    required String name,
    String? cifNo,
    String? address,
    String? kodeUnitKerja,
    String? tipeBank,
  }) async {
    final body = {
      'name': name,
      'cifNo': cifNo,
      'address': address,
      'kodeUnitKerja': kodeUnitKerja,
      'tipeBank': tipeBank,
    };
    final res = id == null
        ? await apiClient.post('/api/admin/banks/$bankId/branches', body: body)
        : await apiClient.put('/api/admin/banks/$bankId/branches/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menyimpan cabang'));
    }
  }

  Future<void> deleteBankBranch(String bankId, String id) async {
    final res = await apiClient.delete('/api/admin/banks/$bankId/branches/$id');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menghapus cabang'));
    }
  }

  // ── BUMN ecosystem tree (admin) ─────────────────────────────────────────────

  /// Flat list of all master_bumn nodes (active + inactive), for the admin editor
  /// and the parent picker. ADMIN-only server-side.
  Future<List<BumnMasterItem>> getBumns() async {
    final res = await apiClient.get('/api/admin/bumns');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => BumnMasterItem.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat BUMN'));
  }

  Future<void> saveBumn({
    String? id,
    required String name,
    String? level,
    String? badanHukum,
    String? parentId,
    bool active = true,
  }) async {
    final body = {
      'name': name,
      'level': level,
      'badanHukum': badanHukum,
      'parentId': parentId,
      'isActive': active,
    };
    final res = id == null
        ? await apiClient.post('/api/admin/bumns', body: body)
        : await apiClient.put('/api/admin/bumns/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menyimpan BUMN'));
    }
  }

  Future<void> deleteBumn(String id) async {
    final res = await apiClient.delete('/api/admin/bumns/$id');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menghapus BUMN'));
    }
  }

  // ── Offices (admin "Kelola Kantor") ─────────────────────────────────────────

  /// All offices incl. inactive (for the admin tree). Pickers elsewhere use the
  /// default active-only `/api/offices`.
  Future<List<OfficeAdminItem>> getOfficesAdmin() async {
    final res = await apiClient.get('/api/offices?includeInactive=true');
    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((j) => OfficeAdminItem.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception(_message(res.body, 'Gagal memuat kantor'));
  }

  /// Create ([id] null → uses [newId] as the office code) or update an office.
  /// [parentId] null/empty detaches (no kanwil); REGIONAL must have none, KUP must
  /// have a BRANCH parent — the server validates the hierarchy.
  Future<void> saveOffice({
    String? id,
    String? newId,
    required String name,
    required String type,
    String? parentId,
    bool? active,
  }) async {
    final body = {
      if (id == null) 'id': newId,
      'name': name,
      'type': type,
      'parentOfficeId': parentId ?? '',
      'active': active,
    };
    final res = id == null
        ? await apiClient.post('/api/offices', body: body)
        : await apiClient.put('/api/offices/$id', body: body);
    if (res.statusCode != 200) {
      throw Exception(_message(res.body, 'Gagal menyimpan kantor'));
    }
  }

  /// Soft delete (deactivate). Reactivate via [saveOffice] with active=true.
  Future<void> deleteOffice(String id) async {
    final res = await apiClient.delete('/api/offices/$id');
    if (res.statusCode != 200 && res.statusCode != 204) {
      throw Exception(_message(res.body, 'Gagal menonaktifkan kantor'));
    }
  }

  String _message(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return fallback;
  }
}
