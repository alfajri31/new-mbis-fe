import 'dart:convert';
import '../network/api_client.dart';

class PipelineListModel {
  final String id;
  final String? customerId;
  final String customerName;
  final String stage;
  final String? subStage;
  final String? product;
  final String? cobName;
  final String? lobName;
  final String? statusKerjaSama;
  final List<String> partyNames;
  final List<String> partyCustomerIds;
  final double tsiIdr;
  final double? ratePremi;
  final double? potensiPremi;
  final double? realisasiIdr;
  final String? closingEstimasi;
  final String? sourceType;
  final double? premi;
  final String? cancelReason;
  final bool isReferral;
  final String? referralStatus; // PENDING_SOURCE | PENDING_DEST | APPROVED | REJECTED

  PipelineListModel({
    required this.id,
    this.customerId,
    required this.customerName,
    required this.stage,
    this.subStage,
    this.product,
    this.cobName,
    this.lobName,
    this.statusKerjaSama,
    this.partyNames = const [],
    this.partyCustomerIds = const [],
    required this.tsiIdr,
    this.ratePremi,
    this.potensiPremi,
    this.realisasiIdr,
    this.closingEstimasi,
    this.sourceType,
    this.premi,
    this.cancelReason,
    this.isReferral = false,
    this.referralStatus,
  });

  factory PipelineListModel.fromJson(Map<String, dynamic> json) {
    return PipelineListModel(
      id: json['id'],
      customerId: json['customerId'],
      customerName: json['customerName'] ?? '',
      stage: json['stage'] ?? '',
      subStage: json['subStage'],
      product: json['product'],
      cobName: json['cobName'],
      lobName: json['lobName'],
      statusKerjaSama: json['statusKerjaSama'],
      partyNames:
          (json['partyNames'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      partyCustomerIds:
          (json['partyCustomerIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      tsiIdr: (json['tsiIdr'] ?? 0).toDouble(),
      ratePremi: json['ratePremi'] != null ? (json['ratePremi'] as num).toDouble() : null,
      potensiPremi: json['potensiPremi'] != null ? (json['potensiPremi'] as num).toDouble() : null,
      realisasiIdr: json['realisasiIdr'] != null ? (json['realisasiIdr'] as num).toDouble() : null,
      closingEstimasi: json['closingEstimasi'],
      sourceType: json['sourceType'],
      premi: json['premi'] != null ? (json['premi'] as num).toDouble() : null,
      cancelReason: json['cancelReason'],
      isReferral: json['isReferral'] == true,
      referralStatus: json['referralStatus'],
    );
  }
}

class PipelineScheduleModel {
  final String id;
  final String title;
  final String? date;
  final String status;

  PipelineScheduleModel({
    required this.id,
    required this.title,
    this.date,
    required this.status,
  });

  factory PipelineScheduleModel.fromJson(Map<String, dynamic> json) {
    return PipelineScheduleModel(
      id: json['id'],
      title: json['title'] ?? '',
      date: json['date'],
      status: json['status'] ?? '',
    );
  }
}

class PipelinePartyModel {
  final String? legalEntity;
  final String? customerName;
  PipelinePartyModel({this.legalEntity, this.customerName});
  factory PipelinePartyModel.fromJson(Map<String, dynamic> j) =>
      PipelinePartyModel(legalEntity: j['legalEntity'], customerName: j['customerName']);
}

class PipelineTenderModel {
  final String? processType;
  final String? startDate;
  final String? endDate;
  final int seq;
  PipelineTenderModel({this.processType, this.startDate, this.endDate, this.seq = 0});
  factory PipelineTenderModel.fromJson(Map<String, dynamic> j) => PipelineTenderModel(
      processType: j['processType'],
      startDate: j['startDate'],
      endDate: j['endDate'],
      seq: (j['seq'] ?? 0) as int);
}

class PipelineShareModel {
  final String? partyType; // LEADER | MEMBER
  final String? name;
  final double? percentage;
  PipelineShareModel({this.partyType, this.name, this.percentage});
  factory PipelineShareModel.fromJson(Map<String, dynamic> j) => PipelineShareModel(
      partyType: j['partyType'],
      name: j['name'],
      percentage: j['percentage'] != null ? (j['percentage'] as num).toDouble() : null);
}

class PipelineHistoryModel {
  final String? stage;
  final String? subStage;
  final String? note;
  final String? eventType; // STAGE | EDIT
  final String? changedBy;
  final String? changedByName;
  final String? changedAt;
  PipelineHistoryModel({
    this.stage,
    this.subStage,
    this.note,
    this.eventType,
    this.changedBy,
    this.changedByName,
    this.changedAt,
  });

  /// Rows written before the event_type column existed are all stage changes.
  bool get isEdit => eventType == 'EDIT';

  factory PipelineHistoryModel.fromJson(Map<String, dynamic> j) => PipelineHistoryModel(
        stage: j['stage'],
        subStage: j['subStage'],
        note: j['note'],
        eventType: j['eventType'] ?? 'STAGE',
        changedBy: j['changedBy'],
        changedByName: j['changedByName'],
        changedAt: j['changedAt'],
      );
}

class PipelineDetailModel {
  final String id;
  final String? customerId;
  final String? customerName;
  final String stage;
  final String? subStage;
  final String? product;
  final String? projectName;
  /// Nama tender (wajib saat [isTender]) — dipakai layar edit untuk prefill.
  final String? tenderName;
  final String? statusKerjaSama;
  final bool isTender;
  final String? cobName;
  final String? lobName;
  final String? tocCode;
  final double tsiIdr;
  /// Valuta asal + kurs + TSI sebelum konversi (V64). Layar edit WAJIB memakainya:
  /// tanpa itu pipeline USD yang dibuka lalu disimpan lagi tertimpa jadi IDR, karena
  /// form mengirim currency/kurs apa pun yang sedang tampil. Null pada pipeline yang
  /// dibuat sebelum V64 — artinya "tidak diketahui", bukan "IDR".
  final String? currency;
  final double? kurs;
  final double? tsiOriginal;
  final double? ratePremi;
  final double? potensiPremi;
  final double? realisasiIdr;
  final String? closingEstimasi;
  final String? rmName;
  final String? sourceType;
  final String? refId;
  final double? premi;
  final String? cancelReason;
  final bool isReferral;
  final String? referralStatus;
  final String? referralFromRmId;
  final String? referralRejectReason;
  final int? tenderCurrentSeq;
  final String? tenderRole; // LEADER | MEMBER
  final String? policyNumber;
  /// Tanggal terbit polis (ISO yyyy-MM-dd) — penentu bulan pengakuan realisasi,
  /// berbeda dari awal masa berlaku polis. Null bila belum diisi.
  final String? policyIssuedDate;
  final double? shareAskrindo;
  /// Pemanggil boleh MENGUBAH pipeline ini — dijawab server memakai gerbang yang
  /// sama dengan yang menegakkannya, bukan ditebak ulang di sini.
  ///
  /// Perlu ada karena cakupan BACA bisa lebih luas daripada cakupan TULIS: RM yang
  /// berkantor di Kanwil melihat pipeline seluruh cabang tetapi hanya boleh mengubah
  /// miliknya sendiri (CR-18).
  ///
  /// Default `true` bila server belum mengirimnya, supaya klien lama/baru yang
  /// bertemu server versi berbeda tidak mendadak kehilangan seluruh tombolnya —
  /// server tetap menolak lewat 403 kalau memang tidak berhak.
  final bool canEdit;
  final List<PipelineScheduleModel> schedules;
  final List<PipelinePartyModel> parties;
  final List<PipelineTenderModel> tenderProcesses;
  final List<PipelineShareModel> wonShares;

  PipelineDetailModel({
    required this.id,
    this.customerId,
    this.customerName,
    required this.stage,
    this.subStage,
    this.product,
    this.projectName,
    this.tenderName,
    this.statusKerjaSama,
    this.isTender = false,
    this.cobName,
    this.lobName,
    this.tocCode,
    required this.tsiIdr,
    this.currency,
    this.kurs,
    this.tsiOriginal,
    this.ratePremi,
    this.potensiPremi,
    this.realisasiIdr,
    this.closingEstimasi,
    this.rmName,
    this.sourceType,
    this.refId,
    this.premi,
    this.cancelReason,
    this.isReferral = false,
    this.referralStatus,
    this.referralFromRmId,
    this.referralRejectReason,
    this.tenderCurrentSeq,
    this.tenderRole,
    this.policyNumber,
    this.policyIssuedDate,
    this.shareAskrindo,
    this.canEdit = true,
    required this.schedules,
    this.parties = const [],
    this.tenderProcesses = const [],
    this.wonShares = const [],
  });

  factory PipelineDetailModel.fromJson(Map<String, dynamic> json) {
    return PipelineDetailModel(
      id: json['id'],
      customerId: json['customerId'],
      customerName: json['customerName'],
      stage: json['stage'] ?? '',
      subStage: json['subStage'],
      product: json['product'],
      projectName: json['projectName'],
      tenderName: json['tenderName'],
      statusKerjaSama: json['statusKerjaSama'],
      canEdit: json['canEdit'] != false,
      isTender: json['isTender'] == true,
      cobName: json['cobName'],
      lobName: json['lobName'],
      tocCode: json['tocCode'],
      tsiIdr: (json['tsiIdr'] ?? 0).toDouble(),
      currency: json['currency'],
      kurs: json['kurs'] != null ? (json['kurs'] as num).toDouble() : null,
      tsiOriginal:
          json['tsiOriginal'] != null ? (json['tsiOriginal'] as num).toDouble() : null,
      ratePremi: json['ratePremi'] != null ? (json['ratePremi'] as num).toDouble() : null,
      potensiPremi: json['potensiPremi'] != null ? (json['potensiPremi'] as num).toDouble() : null,
      realisasiIdr: json['realisasiIdr'] != null ? (json['realisasiIdr'] as num).toDouble() : null,
      closingEstimasi: json['closingEstimasi'],
      rmName: json['rmName'],
      sourceType: json['sourceType'],
      refId: json['refId'],
      premi: json['premi'] != null ? (json['premi'] as num).toDouble() : null,
      cancelReason: json['cancelReason'],
      isReferral: json['isReferral'] == true,
      referralStatus: json['referralStatus'],
      referralFromRmId: json['referralFromRmId'],
      referralRejectReason: json['referralRejectReason'],
      tenderCurrentSeq: json['tenderCurrentSeq'],
      tenderRole: json['tenderRole'],
      policyNumber: json['policyNumber'],
      policyIssuedDate: json['policyIssuedDate'],
      shareAskrindo: json['shareAskrindo'] != null ? (json['shareAskrindo'] as num).toDouble() : null,
      schedules: (json['schedules'] as List<dynamic>?)
              ?.map((s) => PipelineScheduleModel.fromJson(s))
              .toList() ??
          [],
      parties: (json['parties'] as List<dynamic>?)
              ?.map((s) => PipelinePartyModel.fromJson(s))
              .toList() ??
          const [],
      tenderProcesses: (json['tenderProcesses'] as List<dynamic>?)
              ?.map((s) => PipelineTenderModel.fromJson(s))
              .toList() ??
          const [],
      wonShares: (json['wonShares'] as List<dynamic>?)
              ?.map((s) => PipelineShareModel.fromJson(s))
              .toList() ??
          const [],
    );
  }
}

/// A pipeline document (SPAU / Underlying).
class PipelineDocumentModel {
  final String id;
  final String docType; // SPAU | UNDERLYING
  final String fileName;
  final String fileUrl; // relative /api/files/**
  const PipelineDocumentModel(
      {required this.id, required this.docType, required this.fileName, required this.fileUrl});
  factory PipelineDocumentModel.fromJson(Map<String, dynamic> j) => PipelineDocumentModel(
        id: j['id'] ?? '',
        docType: j['docType'] ?? '',
        fileName: j['fileName'] ?? '',
        fileUrl: j['fileUrl'] ?? '',
      );
}

/// Marker: dipakai layar detail untuk membedakan gagal-karena-izin dari gagal lain.
class PipelineDeleteForbidden implements Exception {
  @override
  String toString() => 'Hanya admin yang boleh menghapus pipeline.';
}

class PipelineRepository {
  final ApiClient apiClient;

  PipelineRepository({required this.apiClient});

  /// [customerId] memfilter di SERVER ke pipeline milik satu customer (pemilik
  /// atau mitra kerja sama). Selalu isi saat menampilkan pipeline per customer —
  /// tanpa filter, supervisor scope besar mengunduh seluruh list kantornya.
  Future<List<PipelineListModel>> getPipelines({String? customerId}) async {
    final path = customerId == null || customerId.isEmpty
        ? '/api/pipelines'
        : '/api/pipelines?customerId=${Uri.encodeQueryComponent(customerId)}';
    final response = await apiClient.get(path);
    if (response.statusCode == 200) {
      final List<dynamic> jsonList = jsonDecode(response.body);
      return jsonList.map((j) => PipelineListModel.fromJson(j)).toList();
    } else {
      throw Exception('Failed to load pipelines');
    }
  }

  Future<PipelineDetailModel> getPipelineDetail(String id) async {
    final response = await apiClient.get('/api/pipelines/$id');
    if (response.statusCode == 200) {
      return PipelineDetailModel.fromJson(jsonDecode(response.body));
    } else if (response.statusCode == 403 || response.statusCode == 404) {
      // Lihat catatan yang sama pada CustomerRepository.getCustomerDetail:
      // penolakan hak akses harus terbaca sebagai penolakan, bukan kerusakan.
      throw Exception('Pipeline ini di luar cakupan Anda.');
    } else {
      throw Exception('Gagal memuat detail pipeline. Coba lagi beberapa saat.');
    }
  }

  // ── Pipeline documents (SPAU / Underlying) ──
  Future<List<PipelineDocumentModel>> getDocuments(String pipelineId) async {
    final response = await apiClient.get('/api/pipelines/$pipelineId/documents');
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((j) => PipelineDocumentModel.fromJson(j)).toList();
    }
    throw Exception('Failed to load pipeline documents');
  }

  Future<void> uploadDocument(
      String pipelineId, String docType, List<int> bytes, String fileName) async {
    final response = await apiClient.postMultipart(
      '/api/pipelines/$pipelineId/documents',
      fields: {'docType': docType},
      fileField: 'file',
      fileBytes: bytes,
      fileName: fileName,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to upload document ($docType)');
    }
  }

  Future<void> deleteDocument(String pipelineId, String docId) async {
    final response = await apiClient.delete('/api/pipelines/$pipelineId/documents/$docId');
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete document');
    }
  }

  /// Hapus pipeline permanen. Server hanya mengizinkan ADMIN.
  ///
  /// Ikut menghapus jadwal, kunjungan, dan dokumennya; bila stage-nya WON,
  /// realisasinya ikut hilang dari dashboard RM yang bersangkutan.
  Future<void> deletePipeline(String pipelineId) async {
    final response = await apiClient.delete('/api/pipelines/$pipelineId');
    if (response.statusCode == 403) {
      throw PipelineDeleteForbidden();
    }
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Gagal menghapus pipeline');
    }
  }

  /// Log Activity timeline (creation + each status change), oldest first.
  Future<List<PipelineHistoryModel>> getPipelineHistory(String id) async {
    final response = await apiClient.get('/api/pipelines/$id/history');
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((j) => PipelineHistoryModel.fromJson(j)).toList();
    }
    return [];
  }

  Future<PipelineListModel> addPipeline(Map<String, dynamic> data) async {
    final response = await apiClient.post('/api/pipelines', body: data);
    if (response.statusCode == 200 || response.statusCode == 201) {
      return PipelineListModel.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(_errorMessage(response.body) ?? 'Gagal menambah pipeline');
    }
  }

  /// Move the pipeline to a sub-stage. [realisasiIdr] is required when the
  /// resulting bucket is WON, [cancelReason] when it is DECLINE (backend
  /// enforces both too). [policyNumber] is the optional No. Polis captured on WON,
  /// and [policyIssuedDate] the optional tanggal terbit polis that decides which
  /// month the realisasi is recognised in (server falls back to the WON date).
  Future<void> updateStatus(String id,
      {required String subStage,
      double? realisasiIdr,
      String? cancelReason,
      String? policyNumber,
      String? policyStart,
      String? policyEnd,
      String? policyIssuedDate}) async {
    final body = <String, dynamic>{'subStage': subStage};
    if (realisasiIdr != null) body['realisasiIdr'] = realisasiIdr;
    if (cancelReason != null) body['cancelReason'] = cancelReason;
    if (policyNumber != null) body['policyNumber'] = policyNumber;
    // Periode polis menyertai nomornya: server memakai keduanya untuk menerbitkan
    // baris polis, dasar pencatatan premi dan pelepasan komisi agen.
    if (policyStart != null) body['policyStart'] = policyStart;
    if (policyEnd != null) body['policyEnd'] = policyEnd;
    // Tanggal terbit polis berdiri sendiri: menentukan bulan pengakuan realisasi,
    // dan boleh diisi walau nomor polisnya belum keluar.
    if (policyIssuedDate != null) body['policyIssuedDate'] = policyIssuedDate;
    final response = await apiClient.put('/api/pipelines/$id/status', body: body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body) ?? 'Gagal mengubah status');
    }
  }

  /// Advance a tender pipeline to its next process. [body] may carry `role`
  /// (entering Scoring) or the WON payload (entering Won).
  Future<void> advanceTender(String id, Map<String, dynamic> body) async {
    final response = await apiClient.put('/api/pipelines/$id/tender/advance', body: body);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body) ?? 'Gagal memajukan proses tender');
    }
  }

  /// Mark a tender pipeline as Lost (DECLINE) with a reason.
  Future<void> lostTender(String id, String reason) async {
    final response = await apiClient.put('/api/pipelines/$id/tender/lost', body: {'reason': reason});
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body) ?? 'Gagal menandai tender Lost');
    }
  }

  /// Schedule a future visit (date + time + agenda). Appears on the dashboard.
  Future<void> addSchedule(String pipelineId,
      {required String agenda, required DateTime scheduleDateTime}) async {
    final response = await apiClient.post('/api/pipelines/$pipelineId/schedules', body: {
      'title': agenda,
      'description': '',
      // Send the picked local time as a UTC instant; backend stores UTC.
      'scheduleDate': scheduleDateTime.toUtc().toIso8601String(),
    });
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_errorMessage(response.body) ?? 'Gagal membuat jadwal');
    }
  }

  /// Reschedule / edit an existing visit plan (new date+time and/or agenda).
  /// Only OPEN schedules can be edited (enforced on the backend too).
  Future<void> updateSchedule(String scheduleId,
      {required String agenda, required DateTime scheduleDateTime}) async {
    final response = await apiClient.put('/api/pipelines/schedules/$scheduleId', body: {
      'title': agenda,
      'description': '',
      // Send the picked local time as a UTC instant; backend stores UTC.
      'scheduleDate': scheduleDateTime.toUtc().toIso8601String(),
    });
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_errorMessage(response.body) ?? 'Gagal mengubah jadwal');
    }
  }

  /// Change a schedule's status (e.g. mark OPEN -> DONE).
  Future<void> setScheduleStatus(String scheduleId, String status) async {
    final response = await apiClient
        .put('/api/pipelines/schedules/$scheduleId/status', body: {'status': status});
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body) ?? 'Gagal mengubah status jadwal');
    }
  }

  /// Edit a pipeline's business fields (sumber bisnis, TSI, est. closing).
  Future<void> updatePipeline(String id, Map<String, dynamic> data) async {
    final response = await apiClient.put('/api/pipelines/$id', body: data);
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response.body) ?? 'Gagal menyimpan pipeline');
    }
  }

  String? _errorMessage(String body) {
    try {
      final m = jsonDecode(body);
      if (m is Map && m['message'] is String) return m['message'] as String;
    } catch (_) {}
    return null;
  }
}
