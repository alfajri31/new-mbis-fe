import 'dart:typed_data';

import '../../domain/entities/qs_api_exception.dart';
import '../../domain/entities/qs_entities.dart';
import '../../domain/repositories/qs_repository.dart';

/// Implementasi mock / fake [QsRepository] untuk widget test dan pengujian alur.
class MockQsRepository implements QsRepository {
  /// Rekaman panggilan untuk verifikasi pengujian
  final List<Map<String, dynamic>> upsertCalls = [];
  final List<String> submitActionUrls = [];
  final List<String> sentToUnderwritingUrls = [];
  final List<String> submitEmailUrls = [];
  final List<Map<String, dynamic>> uwDecisionCalls = [];
  final List<String> prefillCalls = [];

  /// Konfigurasi respons yang bisa disetel oleh test
  QsApiException? errorToThrow;
  Map<String, dynamic>? prefillData;
  Map<String, dynamic>? upsertResponse;
  QsSubmitActionResult? submitActionResult;
  bool submitEmailShouldFail = false;
  String submitEmailErrorMessage = 'Gagal mengirim email';

  @override
  Future<Map<String, dynamic>> getPrefill({
    required String pipelineId,
    String? qsId,
    String? productCode,
  }) async {
    prefillCalls.add('pipelineId: $pipelineId, qsId: $qsId, product: $productCode');
    if (errorToThrow != null) throw errorToThrow!;
    if (prefillData != null) return prefillData!;
    return {
      'id': qsId ?? 'mock-qs-id-001',
      'nomorQs': '004/QS-PA/ASK-001/X/2026',
      'productCode': productCode ?? 'PSAKDIPOLISSTANDARDASURANSIKECELAKAANDIRIINDONESIA',
      'pemegangPolis': {
        'tertanggung': 'PT Semen Padang',
        'alamat': 'Jl. Raya Padang',
        'bidang': 'MANUFAKTUR',
        'email': 'semen@padang.co.id',
        'pic': 'Budi',
        'hpPic': '08123456789',
      },
      'tipePertanggungan': {
        'qType': 'Single',
        'jmlOrang': 1,
      },
      'perhitunganPremi': {
        'calcType': 'Normal',
      },
      'jangkaWaktu': {
        'start': '2026-10-01',
        'end': '2027-10-01',
      },
      'orangDipertanggungkan': {
        'samaDenganPP': true,
        'nama': 'PT Semen Padang',
      },
      'perhitunganBiaya': {
        'premiJaminanPokok': 100000.0,
        'premiJaminanTambahan': 50000.0,
        'grossPremi': 150000.0,
        'nilaiDiscount': 0.0,
        'nettPremi': 150000.0,
        'adminCost': 30000.0,
        'biayaAsuransi': 180000.0,
        'requiresUwApproval': false,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> upsertQuotationSlip({
    required String pipelineId,
    String? productCode,
    required Map<String, dynamic> payload,
  }) async {
    upsertCalls.add({
      'pipelineId': pipelineId,
      'productCode': productCode,
      'payload': payload,
    });
    if (errorToThrow != null) throw errorToThrow!;
    if (upsertResponse != null) return upsertResponse!;
    return {
      'id': payload['qsId'] ?? 'mock-qs-id-001',
      'nomorQs': '004/QS-PA/ASK-001/X/2026',
      'status': 'DRAFT',
      'statusValue': 'Draft',
      'payload': payload,
    };
  }

  @override
  Future<QsTotalBiayaResult> calculateTotalBiaya({
    required String pipelineId,
    required Map<String, dynamic> payload,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return const QsTotalBiayaResult(
      premiJaminanPokok: 100000.0,
      premiJaminanTambahan: 50000.0,
      grossPremi: 150000.0,
      nilaiDiscount: 0.0,
      nettPremi: 150000.0,
      adminCost: 30000.0,
      biayaAsuransi: 180000.0,
      requiresUwApproval: false,
    );
  }

  @override
  Future<double> getSaranTarifFlat({
    required String pipelineId,
    required Map<String, dynamic> payload,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return 1500.0;
  }

  @override
  Future<QsSubmitActionResult> submitAction({
    required String pipelineId,
    required String qsId,
    required Map<String, dynamic> payload,
  }) async {
    submitActionUrls.add(
        '/api/pipelines/$pipelineId/quotation-slips/submit-action?qsId=$qsId');
    if (errorToThrow != null) throw errorToThrow!;
    if (submitActionResult != null) return submitActionResult!;
    return const QsSubmitActionResult(
      action: 'OK',
      actionCode: 'ok',
      requiresUwApproval: false,
      deviationDetail: [],
    );
  }

  @override
  Future<Map<String, dynamic>> submitEmail({
    required String pipelineId,
    required String qsId,
  }) async {
    submitEmailUrls.add(
        '/api/pipelines/$pipelineId/quotation-slips/submit?qsId=$qsId');
    if (submitEmailShouldFail) {
      throw QsApiException(500, submitEmailErrorMessage);
    }
    if (errorToThrow != null) throw errorToThrow!;
    return {'status': 'SUCCESS', 'message': 'Email QS berhasil dikirim'};
  }

  @override
  Future<Map<String, dynamic>> sentToUnderwriting({
    required String pipelineId,
    required String qsId,
    required String reason,
  }) async {
    sentToUnderwritingUrls.add(
        '/api/pipelines/$pipelineId/quotation-slips/sent-to-underwriting?qsId=$qsId');
    if (errorToThrow != null) throw errorToThrow!;
    return {
      'status': 'UW_APPROVAL',
      'message': 'QS berhasil diajukan ke Underwriting',
    };
  }

  @override
  Future<Uint8List> getPreviewPdf({
    required String pipelineId,
    required String productKey,
    String? qsId,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]); // %PDF
  }

  @override
  Future<List<QsRiwayatItem>> getRiwayat({
    int page = 0,
    int size = 20,
    String? pipelineId,
    String? productCode,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return [
      const QsRiwayatItem(
        id: 'mock-qs-1',
        pipelineId: 'p-1',
        productCode: 'PSAKDI',
        nomorQs: '001/QS-PA/ASK-001/X/2026',
        status: 'DRAFT',
        statusValue: 'Draft',
        customerName: 'PT Semen Padang',
        totalPremi: 60030000.0,
      ),
      const QsRiwayatItem(
        id: 'mock-qs-2',
        pipelineId: 'p-1',
        productCode: 'PAXTRA',
        nomorQs: '002/QS-PAX/ASK-001/X/2026',
        status: 'UW_APPROVAL',
        statusValue: 'Menunggu Persetujuan UW',
        customerName: 'PT Prima Kaplas',
        totalPremi: 66400.0,
        deviation: true,
        deviationDetails: [
          QsDeviationDetailItem(
            textDescription: 'Tarif flat Rp 1.200/hari di bawah saran sistem Rp 1.500/hari',
          ),
        ],
        uwReason: 'Paket event 47 hari perlu dianalisis',
      ),
    ];
  }

  @override
  Future<List<QsApprovalItemData>> getListPersetujuanUw({
    int page = 0,
    int size = 20,
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    return [
      QsApprovalItemData(
        id: 'q1',
        pipelineId: 'p-1',
        productCode: 'PSAKDI',
        status: 'UW_APPROVAL',
        statusValue: 'Menunggu keputusan',
        nomorQs: '001/QS-PA/ASK-001/X/2026',
        sub: 'PSAKDI · PT Semen Padang · Rp 60.030.000',
        devs: ['Rate A/B 0,10% di bawah standar 0,13%'],
        note: 'Kompetitor menawarkan 0,10%',
        docs: 'KTP ✓',
        at: '23 Okt 2026 · 10:42',
      ),
      QsApprovalItemData(
        id: 'q2',
        pipelineId: 'p-2',
        productCode: 'PAXTRA',
        status: 'UW_APPROVAL',
        statusValue: 'Menunggu keputusan',
        nomorQs: '002/QS-PAX/ASK-001/X/2026',
        sub: 'PA Xtra · PT Prima Kaplas · Rp 66.400',
        devs: ['Tarif flat Rp 1.200 di bawah saran'],
        note: 'Deductible diminta nasabah',
        docs: 'Tidak ada lampiran',
        at: '23 Okt 2026 · 09:15',
      ),
    ];
  }

  @override
  Future<void> postUwDecision({
    required String qsId,
    required String action,
    String? uwReason,
  }) async {
    uwDecisionCalls.add({
      'qsId': qsId,
      'action': action,
      'uwReason': uwReason,
    });
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<void> saveDraft({required String qsId}) async {
    if (errorToThrow != null) throw errorToThrow!;
  }
}
