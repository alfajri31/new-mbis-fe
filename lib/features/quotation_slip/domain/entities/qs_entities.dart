import 'dart:convert';

/// Item detail penyimpangan (deviasi) dari ketentuan underwriting.
class QsDeviationDetailItem {
  final String? kode;
  final String textDescription;
  final String? komponen;
  final num? nominalRm;
  final num? nominalStandar;

  const QsDeviationDetailItem({
    this.kode,
    required this.textDescription,
    this.komponen,
    this.nominalRm,
    this.nominalStandar,
  });

  factory QsDeviationDetailItem.fromJson(Map<String, dynamic> json) {
    return QsDeviationDetailItem(
      kode: json['kode']?.toString(),
      textDescription: json['text_description']?.toString() ??
          json['description']?.toString() ??
          json['pesan']?.toString() ??
          'Penyimpangan ketentuan standar underwriting',
      komponen: json['komponen']?.toString(),
      nominalRm: json['nominal_rm'] is num ? json['nominal_rm'] as num : null,
      nominalStandar: json['nominal_standar'] is num
          ? json['nominal_standar'] as num
          : null,
    );
  }

  /// Mengonversi nilai deviation/deviationDetail yang bisa berupa JSON string,
  /// List of Maps, atau dynamic ke `List<QsDeviationDetailItem>`.
  static List<QsDeviationDetailItem> parseList(dynamic raw) {
    if (raw == null) return [];
    dynamic parsed = raw;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return [];
      if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
        try {
          parsed = jsonDecode(trimmed);
        } catch (_) {
          return [QsDeviationDetailItem(textDescription: trimmed)];
        }
      } else {
        return [QsDeviationDetailItem(textDescription: trimmed)];
      }
    }

    if (parsed is List) {
      return parsed.map((item) {
        if (item is Map<String, dynamic>) {
          return QsDeviationDetailItem.fromJson(item);
        } else if (item is Map) {
          return QsDeviationDetailItem.fromJson(
              Map<String, dynamic>.from(item));
        } else {
          return QsDeviationDetailItem(textDescription: item.toString());
        }
      }).toList();
    } else if (parsed is Map<String, dynamic>) {
      return [QsDeviationDetailItem.fromJson(parsed)];
    } else if (parsed is Map) {
      return [
        QsDeviationDetailItem.fromJson(Map<String, dynamic>.from(parsed))
      ];
    }
    return [];
  }

  /// Mengonversi ke list string yang ramah dibaca pengguna.
  static List<String> toReadableStrings(dynamic raw) {
    final items = parseList(raw);
    if (items.isEmpty) return [];
    return items.map((e) => e.textDescription).toList();
  }
}

/// Hasil evaluasi aksi submit dari server (/submit-action).
class QsSubmitActionResult {
  final String action;
  final String actionCode;
  final bool requiresUwApproval;
  final List<QsDeviationDetailItem> deviationDetail;

  const QsSubmitActionResult({
    required this.action,
    required this.actionCode,
    required this.requiresUwApproval,
    this.deviationDetail = const [],
  });

  factory QsSubmitActionResult.fromJson(Map<String, dynamic> json) {
    return QsSubmitActionResult(
      action: json['action']?.toString() ?? 'OK',
      actionCode: json['actionCode']?.toString() ?? 'ok',
      requiresUwApproval: json['requiresUwApproval'] == true,
      deviationDetail:
          QsDeviationDetailItem.parseList(json['deviationDetail']),
    );
  }
}

/// Hasil kalkulasi total biaya asuransi dari server (/total-biaya-asuransi).
class QsTotalBiayaResult {
  final double premiJaminanPokok;
  final double premiJaminanTambahan;
  final double grossPremi;
  final double nilaiDiscount;
  final double nettPremi;
  final double adminCost;
  final double biayaAsuransi;
  final bool requiresUwApproval;

  const QsTotalBiayaResult({
    required this.premiJaminanPokok,
    required this.premiJaminanTambahan,
    required this.grossPremi,
    required this.nilaiDiscount,
    required this.nettPremi,
    required this.adminCost,
    required this.biayaAsuransi,
    required this.requiresUwApproval,
  });

  factory QsTotalBiayaResult.fromJson(Map<String, dynamic> json) {
    return QsTotalBiayaResult(
      premiJaminanPokok:
          (json['premiJaminanPokok'] as num?)?.toDouble() ?? 0.0,
      premiJaminanTambahan:
          (json['premiJaminanTambahan'] as num?)?.toDouble() ?? 0.0,
      grossPremi: (json['grossPremi'] as num?)?.toDouble() ?? 0.0,
      nilaiDiscount: (json['nilaiDiscount'] as num?)?.toDouble() ?? 0.0,
      nettPremi: (json['nettPremi'] as num?)?.toDouble() ?? 0.0,
      adminCost: (json['adminCost'] as num?)?.toDouble() ?? 0.0,
      biayaAsuransi: (json['biayaAsuransi'] as num?)?.toDouble() ?? 0.0,
      requiresUwApproval: json['requiresUwApproval'] == true,
    );
  }
}

/// Item riwayat Quotation Slip (GET /api/qs).
class QsRiwayatItem {
  final String id;
  final String? pipelineId;
  final String productCode;
  final String? nomorQs;
  final String status;
  final String statusValue;
  final String? customerName;
  final double? totalPremi;
  final bool deviation;
  final List<QsDeviationDetailItem> deviationDetails;
  final String? uwReason;
  final String? uwRevisionReason;
  final List<String> changes;
  final String? createdAt;
  final String? updatedAt;

  const QsRiwayatItem({
    required this.id,
    this.pipelineId,
    required this.productCode,
    this.nomorQs,
    required this.status,
    required this.statusValue,
    this.customerName,
    this.totalPremi,
    this.deviation = false,
    this.deviationDetails = const [],
    this.uwReason,
    this.uwRevisionReason,
    this.changes = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory QsRiwayatItem.fromJson(Map<String, dynamic> json) {
    final devRaw = json['deviationDetail'] ?? json['deviations'];
    final devItems = QsDeviationDetailItem.parseList(devRaw);

    List<String> parsedChanges = [];
    if (json['changes'] is List) {
      parsedChanges =
          (json['changes'] as List).map((e) => e.toString()).toList();
    }

    double? parsedPremi;
    if (json['totalPremi'] is num) {
      parsedPremi = (json['totalPremi'] as num).toDouble();
    } else if (json['biayaAsuransi'] is num) {
      parsedPremi = (json['biayaAsuransi'] as num).toDouble();
    } else if (json['perhitunganBiaya'] is Map &&
        json['perhitunganBiaya']['biayaAsuransi'] is num) {
      parsedPremi =
          (json['perhitunganBiaya']['biayaAsuransi'] as num).toDouble();
    }

    final rawStatus = json['status']?.toString() ?? 'DRAFT';
    final statusVal = json['statusValue']?.toString() ??
        _fallbackStatusValue(rawStatus);

    String? custName;
    if (json['customerName'] != null) {
      custName = json['customerName'].toString();
    } else if (json['pemegangPolis'] is Map &&
        json['pemegangPolis']['tertanggung'] != null) {
      custName = json['pemegangPolis']['tertanggung'].toString();
    }

    return QsRiwayatItem(
      id: json['id']?.toString() ?? '',
      pipelineId: json['pipelineId']?.toString(),
      productCode: json['productCode']?.toString() ?? 'PSAKDI',
      nomorQs: json['nomorQs']?.toString() ?? json['noUrut']?.toString(),
      status: rawStatus,
      statusValue: statusVal,
      customerName: custName,
      totalPremi: parsedPremi,
      deviation: json['deviation'] == true,
      deviationDetails: devItems,
      uwReason: json['uwReason']?.toString(),
      uwRevisionReason: json['uwRevisionReason']?.toString(),
      changes: parsedChanges,
      createdAt: json['createdAt']?.toString(),
      updatedAt: json['updatedAt']?.toString(),
    );
  }

  static String _fallbackStatusValue(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return 'Draft';
      case 'UW_APPROVAL':
        return 'Menunggu Persetujuan UW';
      case 'APPROVED':
        return 'Disetujui UW';
      case 'APPROVED_WITH_MODIFICATION':
        return 'Disetujui dengan Perubahan';
      case 'REJECTED':
        return 'Ditolak UW';
      case 'FINAL':
      case 'TERBIT':
        return 'Final';
      default:
        return status;
    }
  }
}

/// Item persetujuan Underwriting (GET /api/qs/list-persetujuan-uw).
class QsApprovalItemData {
  final String id;
  final String? pipelineId;
  final String productCode;
  String status;
  String statusValue;
  String? nomorQs;
  final String sub;
  final List<String> devs;
  final String note;
  final String docs;
  List<String>? changes;
  String uwNote;
  String at;

  QsApprovalItemData({
    required this.id,
    this.pipelineId,
    required this.productCode,
    required this.status,
    required this.statusValue,
    this.nomorQs,
    required this.sub,
    required this.devs,
    required this.note,
    required this.docs,
    this.changes,
    this.uwNote = '',
    required this.at,
  });

  factory QsApprovalItemData.fromJson(Map<String, dynamic> json) {
    final devs = QsDeviationDetailItem.toReadableStrings(
        json['deviationDetail'] ?? json['deviations']);

    List<String>? chg;
    if (json['changes'] is List) {
      chg = (json['changes'] as List).map((e) => e.toString()).toList();
    }

    final rawStatus = json['status']?.toString() ?? 'UW_APPROVAL';
    final statusVal = json['statusValue']?.toString() ??
        (rawStatus == 'UW_APPROVAL' ? 'Menunggu keputusan' : rawStatus);

    return QsApprovalItemData(
      id: json['id']?.toString() ?? '',
      pipelineId: json['pipelineId']?.toString(),
      productCode: json['productCode']?.toString() ?? 'PSAKDI',
      status: rawStatus,
      statusValue: statusVal,
      nomorQs: json['nomorQs']?.toString() ?? json['noUrut']?.toString(),
      sub: json['sub']?.toString() ??
          '${json['productCode'] ?? 'QS'} · ${json['customerName'] ?? 'Customer'}',
      devs: devs.isNotEmpty
          ? devs
          : (json['devs'] is List
              ? (json['devs'] as List).map((e) => e.toString()).toList()
              : []),
      note: json['uwReason']?.toString() ??
          json['alasanRm']?.toString() ??
          json['note']?.toString() ??
          '',
      docs: json['docs']?.toString() ?? 'Tidak ada lampiran',
      changes: chg,
      uwNote: json['uwRevisionReason']?.toString() ??
          json['uwNote']?.toString() ??
          '',
      at: json['at']?.toString() ??
          json['updatedAt']?.toString() ??
          json['createdAt']?.toString() ??
          '',
    );
  }
}
