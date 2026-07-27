import 'dart:convert';
import '../network/api_client.dart';

class DashboardSummary {
  final String scopeLevel; // OWNER | KUP | BRANCH | REGIONAL | NATIONAL
  final int rmCount;

  final int totalCustomers;
  final int totalPipelines;
  final int pipelinesP3;
  final int pipelinesP2;
  final int pipelinesP1;
  final int pipelinesWon;
  final int pipelinesDecline;
  final double totalPotential;
  final double premiTarget;

  // Time-bound: YTD (kartu) + MTD (rincian saat kartu ditekan)
  final double totalRealization; // realisasi YTD
  final double realisasiMtd;
  final int visitCountYtd;
  final int visitCountMtd;
  final int newCustomersYtd;
  final int newCustomersMtd;
  final int wonYtd;
  final int wonMtd;
  final int newPipelinesYtd;
  final int newPipelinesMtd;

  /// Top-performer preview (capped server-side); full list via getRmPerformance.
  final List<RmStat> perRm;

  /// Total RMs with activity in scope — drives the "Lihat Semua" affordance.
  final int perRmTotal;

  /// Adaptive office-level breakdown for supervisors: REGION (DPJ) | BRANCH (RO) |
  /// RM (BM/KUP). Tapping a row opens the RM list filtered to that office.
  final String perOfficeLevel; // REGION | BRANCH | RM
  final List<OfficeStat> perOffice;
  final int perOfficeTotal;

  DashboardSummary({
    required this.scopeLevel,
    required this.rmCount,
    required this.totalCustomers,
    required this.totalPipelines,
    required this.pipelinesP3,
    required this.pipelinesP2,
    required this.pipelinesP1,
    required this.pipelinesWon,
    required this.pipelinesDecline,
    required this.totalPotential,
    required this.premiTarget,
    required this.totalRealization,
    required this.realisasiMtd,
    required this.visitCountYtd,
    required this.visitCountMtd,
    required this.newCustomersYtd,
    required this.newCustomersMtd,
    required this.wonYtd,
    required this.wonMtd,
    required this.newPipelinesYtd,
    required this.newPipelinesMtd,
    required this.perRm,
    this.perRmTotal = 0,
    this.perOfficeLevel = 'RM',
    this.perOffice = const [],
    this.perOfficeTotal = 0,
  });

  /// True for KUP/BM/RO/DPJ/ADMIN — i.e. anyone seeing more than their own data.
  bool get isSupervisor => scopeLevel != 'OWNER';

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      scopeLevel: json['scopeLevel'] ?? 'OWNER',
      rmCount: json['rmCount'] ?? 0,
      totalCustomers: json['totalCustomers'] ?? 0,
      totalPipelines: json['totalPipelines'] ?? 0,
      pipelinesP3: json['pipelinesP3'] ?? 0,
      pipelinesP2: json['pipelinesP2'] ?? 0,
      pipelinesP1: json['pipelinesP1'] ?? 0,
      pipelinesWon: json['pipelinesWon'] ?? 0,
      pipelinesDecline: json['pipelinesDecline'] ?? 0,
      totalPotential: (json['totalPotential'] ?? 0).toDouble(),
      premiTarget: (json['premiTarget'] ?? 0).toDouble(),
      totalRealization: (json['totalRealization'] ?? 0).toDouble(),
      realisasiMtd: (json['realisasiMtd'] ?? 0).toDouble(),
      visitCountYtd: json['visitCountYtd'] ?? 0,
      visitCountMtd: json['visitCountMtd'] ?? 0,
      newCustomersYtd: json['newCustomersYtd'] ?? 0,
      newCustomersMtd: json['newCustomersMtd'] ?? 0,
      wonYtd: json['wonYtd'] ?? 0,
      wonMtd: json['wonMtd'] ?? 0,
      newPipelinesYtd: json['newPipelinesYtd'] ?? 0,
      newPipelinesMtd: json['newPipelinesMtd'] ?? 0,
      perRm: (json['perRm'] as List<dynamic>?)
              ?.map((e) => RmStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      perRmTotal: json['perRmTotal'] ?? 0,
      perOfficeLevel: json['perOfficeLevel'] ?? 'RM',
      perOffice: (json['perOffice'] as List<dynamic>?)
              ?.map((e) => OfficeStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      perOfficeTotal: json['perOfficeTotal'] ?? 0,
    );
  }
}

/// One row of the adaptive office/RM performance breakdown on the dashboard.
class OfficeStat {
  final String id;   // office id, or rm id when type == RM
  final String? name;
  final String type; // REGIONAL | BRANCH | RM
  final int rmCount;
  final int totalCustomers;
  final int activePipelines;
  final int wonCount;
  final double realisasi;
  final int visitCountYtd;

  OfficeStat({
    required this.id,
    this.name,
    required this.type,
    required this.rmCount,
    required this.totalCustomers,
    required this.activePipelines,
    required this.wonCount,
    required this.realisasi,
    required this.visitCountYtd,
  });

  factory OfficeStat.fromJson(Map<String, dynamic> json) {
    return OfficeStat(
      id: json['id'] ?? '',
      name: json['name'],
      type: json['type'] ?? 'RM',
      rmCount: json['rmCount'] ?? 0,
      totalCustomers: json['totalCustomers'] ?? 0,
      activePipelines: json['activePipelines'] ?? 0,
      wonCount: json['wonCount'] ?? 0,
      realisasi: (json['realisasi'] ?? 0).toDouble(),
      visitCountYtd: json['visitCountYtd'] ?? 0,
    );
  }
}

/// Per-month breakdown of the scope's time-bound metrics for the current year
/// (months 1..current). Powers the expandable "Rincian per Bulan" sheet.
class MonthlyBreakdown {
  final int year;
  final double realisasiYtd;
  final int visitsYtd;
  final int newCustomersYtd;
  final int wonYtd;
  final int newPipelinesYtd;
  final List<MonthStat> months;

  MonthlyBreakdown({
    required this.year,
    required this.realisasiYtd,
    required this.visitsYtd,
    required this.newCustomersYtd,
    required this.wonYtd,
    required this.newPipelinesYtd,
    required this.months,
  });

  factory MonthlyBreakdown.fromJson(Map<String, dynamic> json) {
    return MonthlyBreakdown(
      year: json['year'] ?? 0,
      realisasiYtd: (json['realisasiYtd'] ?? 0).toDouble(),
      visitsYtd: json['visitsYtd'] ?? 0,
      newCustomersYtd: json['newCustomersYtd'] ?? 0,
      wonYtd: json['wonYtd'] ?? 0,
      newPipelinesYtd: json['newPipelinesYtd'] ?? 0,
      months: (json['months'] as List<dynamic>?)
              ?.map((e) => MonthStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}

/// One month's tally within a [MonthlyBreakdown].
class MonthStat {
  final int month; // 1..12
  final double realisasi;
  final int visits;
  final int newCustomers;
  final int won;
  final int newPipelines;

  MonthStat({
    required this.month,
    required this.realisasi,
    required this.visits,
    required this.newCustomers,
    required this.won,
    required this.newPipelines,
  });

  factory MonthStat.fromJson(Map<String, dynamic> json) {
    return MonthStat(
      month: json['month'] ?? 0,
      realisasi: (json['realisasi'] ?? 0).toDouble(),
      visits: json['visits'] ?? 0,
      newCustomers: json['newCustomers'] ?? 0,
      won: json['won'] ?? 0,
      newPipelines: json['newPipelines'] ?? 0,
    );
  }
}

/// One page of the paginated RM-performance list ("Lihat Semua RM").
class RmPerformancePage {
  final List<RmStat> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  /// Filter-aware header totals across ALL matching RMs (every page).
  final int totalActivePipelines;
  final double totalRealisasi;

  /// RMs within the scope + filter that have no pipeline at all.
  final int rmsWithoutPipeline;

  /// Pipeline stage breakdown across ALL matching RMs (current stage).
  final int p3;
  final int p2;
  final int p1;
  final int won;
  final int decline;

  RmPerformancePage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
    this.totalActivePipelines = 0,
    this.totalRealisasi = 0,
    this.rmsWithoutPipeline = 0,
    this.p3 = 0,
    this.p2 = 0,
    this.p1 = 0,
    this.won = 0,
    this.decline = 0,
  });

  factory RmPerformancePage.fromJson(Map<String, dynamic> json) {
    return RmPerformancePage(
      content: (json['content'] as List<dynamic>?)
              ?.map((e) => RmStat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      page: json['page'] ?? 0,
      size: json['size'] ?? 0,
      totalElements: json['totalElements'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      last: json['last'] ?? true,
      totalActivePipelines: json['totalActivePipelines'] ?? 0,
      totalRealisasi: (json['totalRealisasi'] ?? 0).toDouble(),
      rmsWithoutPipeline: json['rmsWithoutPipeline'] ?? 0,
      p3: json['p3'] ?? 0,
      p2: json['p2'] ?? 0,
      p1: json['p1'] ?? 0,
      won: json['won'] ?? 0,
      decline: json['decline'] ?? 0,
    );
  }
}

/// One row of the supervisory per-RM breakdown.
class RmStat {
  final String rmId;
  final String? rmName;
  final String? officeId;
  final String? officeName;
  final String? regionName; // Kanwil
  final String? branchName; // Cabang
  final int totalCustomers;
  final int activePipelines;
  final int wonCount;
  final double realisasi;
  final double target; // full-year premi target
  final int visitCountYtd;
  final bool isConnect;

  RmStat({
    required this.rmId,
    this.rmName,
    this.officeId,
    this.officeName,
    this.regionName,
    this.branchName,
    required this.totalCustomers,
    required this.activePipelines,
    required this.wonCount,
    required this.realisasi,
    this.target = 0,
    required this.visitCountYtd,
    this.isConnect = false,
  });

  /// Progress of realisasi (YTD) toward the full-year target, clamped 0..1.
  double get targetProgress =>
      target > 0 ? (realisasi / target).clamp(0.0, 1.0) : 0.0;

  /// Office label as "Kanwil · Cabang" (falls back to whatever is available).
  String? get officeLabel {
    if (regionName != null && branchName != null) return '$regionName · $branchName';
    return branchName ?? regionName ?? officeName;
  }

  factory RmStat.fromJson(Map<String, dynamic> json) {
    return RmStat(
      rmId: json['rmId'] ?? '',
      rmName: json['rmName'],
      officeId: json['officeId'],
      officeName: json['officeName'],
      regionName: json['regionName'],
      branchName: json['branchName'],
      totalCustomers: json['totalCustomers'] ?? 0,
      activePipelines: json['activePipelines'] ?? 0,
      wonCount: json['wonCount'] ?? 0,
      realisasi: (json['realisasi'] ?? 0).toDouble(),
      target: (json['target'] ?? 0).toDouble(),
      visitCountYtd: json['visitCountYtd'] ?? 0,
      isConnect: json['isConnect'] == true,
    );
  }
}

class DashboardSchedule {
  final String id;
  final String? pipelineId;
  final String? customerName;
  final String? title;
  final String? scheduleDate;
  final String? scheduleDateTime;
  final String? countdownLabel;
  final String? status;

  DashboardSchedule({
    required this.id,
    this.pipelineId,
    this.customerName,
    this.title,
    this.scheduleDate,
    this.scheduleDateTime,
    this.countdownLabel,
    this.status,
  });

  factory DashboardSchedule.fromJson(Map<String, dynamic> json) {
    return DashboardSchedule(
      id: json['id'],
      pipelineId: json['pipelineId'],
      customerName: json['customerName'],
      title: json['title'],
      scheduleDate: json['scheduleDate'],
      scheduleDateTime: json['scheduleDateTime'],
      countdownLabel: json['countdownLabel'],
      status: json['status'],
    );
  }
}

/// A visited customer location for the supervisory map/list.
class VisitLocation {
  final String visitId;
  final String? rmName;
  final String? officeName;
  final String? customerName;
  final String? customerAddress;
  final double latitude;
  final double longitude;
  final String? activityDate;
  final String? visitType;

  VisitLocation({
    required this.visitId,
    this.rmName,
    this.officeName,
    this.customerName,
    this.customerAddress,
    required this.latitude,
    required this.longitude,
    this.activityDate,
    this.visitType,
  });

  factory VisitLocation.fromJson(Map<String, dynamic> json) {
    return VisitLocation(
      visitId: json['visitId'] ?? '',
      rmName: json['rmName'],
      officeName: json['officeName'],
      customerName: json['customerName'],
      customerAddress: json['customerAddress'],
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      activityDate: json['activityDate'],
      visitType: json['visitType'],
    );
  }
}

/// A region/branch the caller may filter their scoped views by.
class ScopeOffice {
  final String id;
  final String name;
  final String type; // REGIONAL | BRANCH | KUP
  final String? parentId;

  ScopeOffice({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
  });

  factory ScopeOffice.fromJson(Map<String, dynamic> json) {
    return ScopeOffice(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      parentId: json['parentId'],
    );
  }
}

class DashboardMonthRow {
  final String label;
  final double target;
  final double realisasi;
  final int visits;
  final int visitsKur;
  final double pipelineValue;
  DashboardMonthRow(
      this.label, this.target, this.realisasi, this.visits, this.visitsKur, this.pipelineValue);
  factory DashboardMonthRow.fromJson(Map<String, dynamic> j) => DashboardMonthRow(
        j['label'] ?? '',
        (j['target'] ?? 0).toDouble(),
        (j['realisasi'] ?? 0).toDouble(),
        (j['visits'] ?? 0) as int,
        (j['visitsKur'] ?? 0) as int,
        (j['pipelineValue'] ?? 0).toDouble(),
      );
}

class DashboardCobRow {
  final String cob;
  final int count;
  DashboardCobRow(this.cob, this.count);
  factory DashboardCobRow.fromJson(Map<String, dynamic> j) =>
      DashboardCobRow(j['cob'] ?? '-', (j['count'] ?? 0) as int);
}

class DashboardSuccessItem {
  final String id;
  final String customerName;
  final String stage;
  DashboardSuccessItem(this.id, this.customerName, this.stage);
  factory DashboardSuccessItem.fromJson(Map<String, dynamic> j) =>
      DashboardSuccessItem(j['id'] ?? '', j['customerName'] ?? '-', j['stage'] ?? '');
}

class DashboardDrilldown {
  final List<DashboardMonthRow> monthly;
  final List<DashboardCobRow> byCob;
  final int won;
  final int decline;
  final int total;
  final List<DashboardSuccessItem> successItems;
  DashboardDrilldown(this.monthly, this.byCob, this.won, this.decline, this.total, this.successItems);
  factory DashboardDrilldown.fromJson(Map<String, dynamic> j) {
    final sr = j['successRate'] as Map<String, dynamic>? ?? {};
    return DashboardDrilldown(
      (j['monthly'] as List<dynamic>? ?? []).map((e) => DashboardMonthRow.fromJson(e)).toList(),
      (j['byCob'] as List<dynamic>? ?? []).map((e) => DashboardCobRow.fromJson(e)).toList(),
      (sr['won'] ?? 0) as int,
      (sr['decline'] ?? 0) as int,
      (sr['total'] ?? 0) as int,
      (sr['items'] as List<dynamic>? ?? []).map((e) => DashboardSuccessItem.fromJson(e)).toList(),
    );
  }
}

/// Filter 11 target di dashboard (endpoint /api/dashboard/categories). Satu payload
/// memuat target + realisasi YTD + rincian per bulan tiap kategori (ref: image-1.png).
class DashboardCategories {
  final int year;
  final int currentMonth;
  final String defaultCategory; // NON_PROGRAM_NON_ASKRED
  final List<DashboardCategoryStat> categories;

  DashboardCategories({
    required this.year,
    required this.currentMonth,
    required this.defaultCategory,
    required this.categories,
  });

  DashboardCategoryStat? byName(String name) {
    for (final c in categories) {
      if (c.category == name) return c;
    }
    return categories.isNotEmpty ? categories.first : null;
  }

  factory DashboardCategories.fromJson(Map<String, dynamic> json) => DashboardCategories(
        year: json['year'] ?? 0,
        currentMonth: json['currentMonth'] ?? 0,
        defaultCategory: json['defaultCategory'] ?? 'NON_PROGRAM_NON_ASKRED',
        categories: (json['categories'] as List<dynamic>?)
                ?.map((e) => DashboardCategoryStat.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class DashboardCategoryStat {
  final String category; // enum name
  final String label;
  final String description;
  final double targetYtd;
  final double realisasiYtd;
  final double targetFullYear;
  final List<DashboardCategoryMonth> months;

  DashboardCategoryStat({
    required this.category,
    required this.label,
    required this.description,
    required this.targetYtd,
    required this.realisasiYtd,
    required this.targetFullYear,
    required this.months,
  });

  /// Rasio pencapaian. Target 0 tapi ada realisasi → dianggap 100% (sesuai aturan bisnis);
  /// keduanya 0 → 0. Bisa >1 (boleh lewat target).
  double get progress {
    if (targetYtd > 0) return realisasiYtd / targetYtd;
    return realisasiYtd > 0 ? 1.0 : 0.0;
  }

  factory DashboardCategoryStat.fromJson(Map<String, dynamic> json) => DashboardCategoryStat(
        category: json['category'] ?? '',
        label: json['label'] ?? '',
        description: json['description'] ?? '',
        targetYtd: (json['targetYtd'] ?? 0).toDouble(),
        realisasiYtd: (json['realisasiYtd'] ?? 0).toDouble(),
        targetFullYear: (json['targetFullYear'] ?? 0).toDouble(),
        months: (json['months'] as List<dynamic>?)
                ?.map((e) => DashboardCategoryMonth.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

class DashboardCategoryMonth {
  final int month;
  final String label;
  final double target;
  final double realisasi;

  DashboardCategoryMonth({
    required this.month,
    required this.label,
    required this.target,
    required this.realisasi,
  });

  factory DashboardCategoryMonth.fromJson(Map<String, dynamic> json) => DashboardCategoryMonth(
        month: json['month'] ?? 0,
        label: json['label'] ?? '',
        target: (json['target'] ?? 0).toDouble(),
        realisasi: (json['realisasi'] ?? 0).toDouble(),
      );
}

class DashboardRepository {
  final ApiClient apiClient;

  DashboardRepository({required this.apiClient});

  /// Daftar RM untuk picker (filter/ekspor scoped), di-scope server ke wilayah/
  /// cabang terpilih. Mirror `/api/dashboard/rm-options`.
  Future<List<RmOption>> getRmOptions({
    String? regionId,
    String? branchId,
    String? search,
  }) async {
    final params = <String, String>{
      if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final path = query.isEmpty
        ? '/api/dashboard/rm-options'
        : '/api/dashboard/rm-options?$query';
    final response = await apiClient.get(path);
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((j) => RmOption.fromJson(j)).toList();
    } else {
      throw Exception('Failed to load RM options');
    }
  }

  /// 11 target (target + realisasi YTD + rincian bulan) untuk scope pemanggil.
  Future<DashboardCategories> getCategories() async {
    final response = await apiClient.get('/api/dashboard/categories');
    if (response.statusCode == 200) {
      return DashboardCategories.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load dashboard categories');
  }

  /// 11 target untuk satu RM (supervisor drilldown di manajemen RM).
  Future<DashboardCategories> getRmCategories(String rmId) async {
    final response = await apiClient.get('/api/dashboard/rm/$rmId/categories');
    if (response.statusCode == 200) {
      return DashboardCategories.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load RM categories');
  }

  Future<DashboardDrilldown> getDrilldown() async {
    final response = await apiClient.get('/api/dashboard/drilldown');
    if (response.statusCode == 200) {
      return DashboardDrilldown.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to load dashboard drilldown');
  }

  Future<DashboardSummary> getSummary() async {
    final response = await apiClient.get('/api/dashboard/summary');
    if (response.statusCode == 200) {
      return DashboardSummary.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load dashboard summary');
    }
  }

  /// Per-month breakdown of the scope's metrics for the current year.
  Future<MonthlyBreakdown> getMonthlyBreakdown() async {
    final response = await apiClient.get('/api/dashboard/monthly');
    if (response.statusCode == 200) {
      return MonthlyBreakdown.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load monthly breakdown');
    }
  }

  Future<List<DashboardSchedule>> getSchedules() async {
    final response = await apiClient.get('/api/dashboard/schedules');
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((j) => DashboardSchedule.fromJson(j)).toList();
    } else {
      throw Exception('Failed to load schedules');
    }
  }

  /// Visited customer locations within scope; [officeId] narrows to one subtree.
  Future<List<VisitLocation>> getVisitLocations({String? officeId}) async {
    final path = officeId != null && officeId.isNotEmpty
        ? '/api/dashboard/visit-locations?officeId=$officeId'
        : '/api/dashboard/visit-locations';
    final response = await apiClient.get(path);
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((j) => VisitLocation.fromJson(j)).toList();
    } else {
      throw Exception('Failed to load visit locations');
    }
  }

  /// One page of the scope-aware RM-performance list. [search] matches name/NIP;
  /// [regionId]/[branchId] narrow to one office subtree.
  Future<RmPerformancePage> getRmPerformance({
    int page = 0,
    int size = 20,
    String? search,
    String? regionId,
    String? branchId,
    bool connectOnly = false,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'size': '$size',
      if (search != null && search.isNotEmpty) 'search': search,
      if (regionId != null && regionId.isNotEmpty) 'regionId': regionId,
      if (branchId != null && branchId.isNotEmpty) 'branchId': branchId,
      if (connectOnly) 'connectOnly': 'true',
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    final response = await apiClient.get('/api/dashboard/rm-performance?$query');
    if (response.statusCode == 200) {
      return RmPerformancePage.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load RM performance');
    }
  }

  /// Monthly target vs realisasi for a single RM (supervisor tap on an RM card).
  Future<List<DashboardMonthRow>> getRmMonthly(String rmId) async {
    final response = await apiClient.get('/api/dashboard/rm/$rmId/monthly');
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((j) => DashboardMonthRow.fromJson(j)).toList();
    } else {
      throw Exception('Failed to load RM monthly');
    }
  }

  /// Region/branch offices the caller may filter by (empty for RM/agent).
  Future<List<ScopeOffice>> getScopeOffices() async {
    final response = await apiClient.get('/api/dashboard/scope-offices');
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((j) => ScopeOffice.fromJson(j)).toList();
    } else {
      throw Exception('Failed to load scope offices');
    }
  }
}

/// Opsi RM untuk picker (id + nama + kantor). Mirror item `/api/dashboard/rm-options`.
class RmOption {
  final String id;
  final String name;
  final String? officeName;

  RmOption({required this.id, required this.name, this.officeName});

  factory RmOption.fromJson(Map<String, dynamic> json) => RmOption(
        id: json['id'] ?? '',
        name: json['name'] ?? '',
        officeName: json['officeName'],
      );
}
