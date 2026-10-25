import '../visit_rm_models.dart';

/// Models for Visit Monitor API (`/api/visit-monitor/**`).
/// Generated according to the OpenAPI / Swagger specification.

class VisitMonitorFilter {
  final String? from; // YYYY-MM-DD
  final String? to; // YYYY-MM-DD
  final String? regionId;
  final String? branchId;
  final String? rmId;
  final String? stage;
  final String? category;
  final bool? bumn;
  final bool? hvc;
  final String? sourceType;
  final String? cob;
  final String? lob;
  final String? toc;
  final String? q;

  const VisitMonitorFilter({
    this.from,
    this.to,
    this.regionId,
    this.branchId,
    this.rmId,
    this.stage,
    this.category,
    this.bumn,
    this.hvc,
    this.sourceType,
    this.cob,
    this.lob,
    this.toc,
    this.q,
  });

  Map<String, String> toQueryParams() {
    return {
      if (from != null && from!.isNotEmpty) 'from': from!,
      if (to != null && to!.isNotEmpty) 'to': to!,
      if (regionId != null && regionId!.isNotEmpty) 'regionId': regionId!,
      if (branchId != null && branchId!.isNotEmpty) 'branchId': branchId!,
      if (rmId != null && rmId!.isNotEmpty) 'rmId': rmId!,
      if (stage != null && stage!.isNotEmpty) 'stage': stage!,
      if (category != null && category!.isNotEmpty) 'category': category!,
      if (bumn != null) 'bumn': bumn!.toString(),
      if (hvc != null) 'hvc': hvc!.toString(),
      if (sourceType != null && sourceType!.isNotEmpty) 'sourceType': sourceType!,
      if (cob != null && cob!.isNotEmpty) 'cob': cob!,
      if (lob != null && lob!.isNotEmpty) 'lob': lob!,
      if (toc != null && toc!.isNotEmpty) 'toc': toc!,
      if (q != null && q!.isNotEmpty) 'q': q!,
    };
  }

  VisitMonitorFilter copyWith({
    String? from,
    String? to,
    String? regionId,
    String? branchId,
    String? rmId,
    String? stage,
    String? category,
    bool? bumn,
    bool? hvc,
    String? sourceType,
    String? cob,
    String? lob,
    String? toc,
    String? q,
    bool clearRegion = false,
    bool clearBranch = false,
    bool clearRm = false,
  }) {
    return VisitMonitorFilter(
      from: from ?? this.from,
      to: to ?? this.to,
      regionId: clearRegion ? null : (regionId ?? this.regionId),
      branchId: clearBranch ? null : (branchId ?? this.branchId),
      rmId: clearRm ? null : (rmId ?? this.rmId),
      stage: stage ?? this.stage,
      category: category ?? this.category,
      bumn: bumn ?? this.bumn,
      hvc: hvc ?? this.hvc,
      sourceType: sourceType ?? this.sourceType,
      cob: cob ?? this.cob,
      lob: lob ?? this.lob,
      toc: toc ?? this.toc,
      q: q ?? this.q,
    );
  }
}

class VisitMonitorSummary {
  final int totalVisit;
  final int rmCount;
  final int rmActive;
  final int rmIdle;
  final double avgPerRm;
  final int reviewedCount;

  const VisitMonitorSummary({
    this.totalVisit = 0,
    this.rmCount = 0,
    this.rmActive = 0,
    this.rmIdle = 0,
    this.avgPerRm = 0.0,
    this.reviewedCount = 0,
  });

  factory VisitMonitorSummary.fromJson(Map<String, dynamic> json) {
    return VisitMonitorSummary(
      totalVisit: (json['totalVisit'] as num?)?.toInt() ?? 0,
      rmCount: (json['rmCount'] as num?)?.toInt() ?? 0,
      rmActive: (json['rmActive'] as num?)?.toInt() ?? 0,
      rmIdle: (json['rmIdle'] as num?)?.toInt() ?? 0,
      avgPerRm: (json['avgPerRm'] as num?)?.toDouble() ?? 0.0,
      reviewedCount: (json['reviewedCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class VisitMonitorRow {
  final String id;
  final DateTime? activityDate;
  final String? type;
  final String? pipelineId;
  final String? customerName;
  final String? rmId;
  final String? rmName;
  final String? officeName;
  final String? stage;
  final double? tsi;
  final double? potensiPremi;
  final String? photoUrl;
  final bool reviewed;

  const VisitMonitorRow({
    required this.id,
    this.activityDate,
    this.type,
    this.pipelineId,
    this.customerName,
    this.rmId,
    this.rmName,
    this.officeName,
    this.stage,
    this.tsi,
    this.potensiPremi,
    this.photoUrl,
    this.reviewed = false,
  });

  factory VisitMonitorRow.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['activityDate'] != null) {
      parsedDate = DateTime.tryParse(json['activityDate'].toString());
    }

    return VisitMonitorRow(
      id: json['id']?.toString() ?? '',
      activityDate: parsedDate,
      type: json['type']?.toString(),
      pipelineId: json['pipelineId']?.toString(),
      customerName: json['customerName']?.toString(),
      rmId: json['rmId']?.toString(),
      rmName: json['rmName']?.toString(),
      officeName: json['officeName']?.toString(),
      stage: json['stage']?.toString(),
      tsi: (json['tsi'] as num?)?.toDouble(),
      potensiPremi: (json['potensiPremi'] as num?)?.toDouble(),
      photoUrl: json['photoUrl']?.toString(),
      reviewed: json['reviewed'] == true,
    );
  }

  VisitModel toVisitModel() {
    final d = activityDate;
    final tglStr = d != null
        ? '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
        : '';
    final jamStr = d != null
        ? '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
        : '';

    return VisitModel(
      id: id,
      rmId: rmId ?? '',
      perusahaan: customerName ?? '-',
      tanggal: tglStr,
      jam: jamStr,
      stage: stage ?? 'P3',
      nilai: potensiPremi ?? (tsi ?? 0.0),
      foto: photoUrl != null && photoUrl!.isNotEmpty,
      lokasi: officeName ?? '',
      tujuan: type ?? 'Kunjungan Nasabah',
      hasil: '-',
      tindakLanjut: '-',
      pipelineId: pipelineId,
    );
  }
}

class VisitMonitorRmRow {
  final String rmId;
  final String rmName;
  final String? nip;
  final String? jabatan;
  final String? officeName;
  final int visitCount;
  final int reviewedCount;
  final double totalTsi;
  final DateTime? lastVisitAt;
  final String? lastCustomerName;

  const VisitMonitorRmRow({
    required this.rmId,
    required this.rmName,
    this.nip,
    this.jabatan,
    this.officeName,
    this.visitCount = 0,
    this.reviewedCount = 0,
    this.totalTsi = 0.0,
    this.lastVisitAt,
    this.lastCustomerName,
  });

  factory VisitMonitorRmRow.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['lastVisitAt'] != null) {
      parsedDate = DateTime.tryParse(json['lastVisitAt'].toString());
    }

    return VisitMonitorRmRow(
      rmId: json['rmId']?.toString() ?? '',
      rmName: json['rmName']?.toString() ?? '',
      nip: json['nip']?.toString(),
      jabatan: json['jabatan']?.toString(),
      officeName: json['officeName']?.toString(),
      visitCount: (json['visitCount'] as num?)?.toInt() ?? 0,
      reviewedCount: (json['reviewedCount'] as num?)?.toInt() ?? 0,
      totalTsi: (json['totalTsi'] as num?)?.toDouble() ?? 0.0,
      lastVisitAt: parsedDate,
      lastCustomerName: json['lastCustomerName']?.toString(),
    );
  }

  RmModel toRmModel() {
    return RmModel(
      id: rmId,
      nama: rmName,
      jab: jabatan ?? 'RM Bisnis',
      cab: officeName ?? '-',
    );
  }
}


class VisitMonitorPage<T> {
  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  const VisitMonitorPage({
    this.content = const [],
    this.page = 0,
    this.size = 20,
    this.totalElements = 0,
    this.totalPages = 0,
    this.last = true,
  });

  bool get hasPrevious => page > 0;
  bool get hasNext => totalPages > 0 && page < totalPages - 1;

  factory VisitMonitorPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromItemJson,
  ) {
    final rawList = json['content'] as List<dynamic>? ?? const [];
    final items = rawList
        .whereType<Map<String, dynamic>>()
        .map(fromItemJson)
        .toList();

    return VisitMonitorPage(
      content: items,
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 20,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? items.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? (items.isNotEmpty ? 1 : 0),
      last: json['last'] == true,
    );
  }
}

class VisitMonitorReview {
  final String? reviewedById;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? note;

  const VisitMonitorReview({
    this.reviewedById,
    this.reviewedByName,
    this.reviewedAt,
    this.note,
  });

  factory VisitMonitorReview.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['reviewedAt'] != null) {
      parsedDate = DateTime.tryParse(json['reviewedAt'].toString());
    }

    return VisitMonitorReview(
      reviewedById: json['reviewedById']?.toString(),
      reviewedByName: json['reviewedByName']?.toString(),
      reviewedAt: parsedDate,
      note: json['note']?.toString(),
    );
  }
}

class VisitMonitorDetail {
  final String id;
  final DateTime? activityDate;
  final String? type;
  final String? customerName;
  final String? customerType;
  final String? customerAddress;
  final String? pipelineId;
  final String? pipelineName;
  final String? stage;
  final String? sourceType;
  final String? sourceName;
  final String? cobName;
  final String? lobName;
  final String? tocName;
  final double? tsi;
  final double? potensiPremi;
  final String? rmId;
  final String? rmName;
  final String? rmNip;
  final String? rmJabatan;
  final String? regionName;
  final String? officeName;
  final String? gpsLatitude;
  final String? gpsLongitude;
  final String? notes;
  final String? actionPlan;
  final DateTime? nextFollowupDate;
  final List<String> photoUrls;
  final VisitMonitorReview? review;
  final bool canReview;

  const VisitMonitorDetail({
    required this.id,
    this.activityDate,
    this.type,
    this.customerName,
    this.customerType,
    this.customerAddress,
    this.pipelineId,
    this.pipelineName,
    this.stage,
    this.sourceType,
    this.sourceName,
    this.cobName,
    this.lobName,
    this.tocName,
    this.tsi,
    this.potensiPremi,
    this.rmId,
    this.rmName,
    this.rmNip,
    this.rmJabatan,
    this.regionName,
    this.officeName,
    this.gpsLatitude,
    this.gpsLongitude,
    this.notes,
    this.actionPlan,
    this.nextFollowupDate,
    this.photoUrls = const [],
    this.review,
    this.canReview = false,
  });

  bool get isReviewed => review != null;

  factory VisitMonitorDetail.fromJson(Map<String, dynamic> json) {
    DateTime? parsedActivity;
    if (json['activityDate'] != null) {
      parsedActivity = DateTime.tryParse(json['activityDate'].toString());
    }

    DateTime? parsedFollowup;
    if (json['nextFollowupDate'] != null) {
      parsedFollowup = DateTime.tryParse(json['nextFollowupDate'].toString());
    }

    VisitMonitorReview? parsedReview;
    if (json['review'] != null && json['review'] is Map<String, dynamic>) {
      parsedReview = VisitMonitorReview.fromJson(json['review'] as Map<String, dynamic>);
    }

    final rawPhotos = json['photoUrls'] as List<dynamic>? ?? const [];
    final photos = rawPhotos.map((e) => e.toString()).toList();

    return VisitMonitorDetail(
      id: json['id']?.toString() ?? '',
      activityDate: parsedActivity,
      type: json['type']?.toString(),
      customerName: json['customerName']?.toString(),
      customerType: json['customerType']?.toString(),
      customerAddress: json['customerAddress']?.toString(),
      pipelineId: json['pipelineId']?.toString(),
      pipelineName: json['pipelineName']?.toString(),
      stage: json['stage']?.toString(),
      sourceType: json['sourceType']?.toString(),
      sourceName: json['sourceName']?.toString(),
      cobName: json['cobName']?.toString(),
      lobName: json['lobName']?.toString(),
      tocName: json['tocName']?.toString(),
      tsi: (json['tsi'] as num?)?.toDouble(),
      potensiPremi: (json['potensiPremi'] as num?)?.toDouble(),
      rmId: json['rmId']?.toString(),
      rmName: json['rmName']?.toString(),
      rmNip: json['rmNip']?.toString(),
      rmJabatan: json['rmJabatan']?.toString(),
      regionName: json['regionName']?.toString(),
      officeName: json['officeName']?.toString(),
      gpsLatitude: json['gpsLatitude']?.toString(),
      gpsLongitude: json['gpsLongitude']?.toString(),
      notes: json['notes']?.toString(),
      actionPlan: json['actionPlan']?.toString(),
      nextFollowupDate: parsedFollowup,
      photoUrls: photos,
      review: parsedReview,
      canReview: json['canReview'] == true,
    );
  }

  VisitModel toVisitModel() {
    final d = activityDate;
    final tglStr = d != null
        ? '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
        : '';
    final jamStr = d != null
        ? '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}'
        : '';

    return VisitModel(
      id: id,
      rmId: rmId ?? '',
      perusahaan: customerName ?? '-',
      tanggal: tglStr,
      jam: jamStr,
      stage: stage ?? 'P3',
      nilai: potensiPremi ?? (tsi ?? 0.0),
      foto: photoUrls.isNotEmpty,
      lokasi: customerAddress ?? (officeName ?? ''),
      tujuan: type ?? (notes ?? 'Kunjungan Nasabah'),
      hasil: notes ?? '-',
      tindakLanjut: actionPlan ?? '-',
      pipelineId: pipelineId,
    );
  }
}

class VisitExportOutcome {
  final bool ok;
  final String? fileName;
  final bool unsupported;
  final String? error;

  const VisitExportOutcome.saved(this.fileName)
      : ok = true,
        unsupported = false,
        error = null;

  const VisitExportOutcome.unsupported()
      : ok = false,
        fileName = null,
        unsupported = true,
        error = null;

  const VisitExportOutcome.failed(this.error)
      : ok = false,
        fileName = null,
        unsupported = false;
}


