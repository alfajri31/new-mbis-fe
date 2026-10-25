import 'dart:typed_data';

import '../entities/qs_entities.dart';

/// Kontrak interface untuk seluruh pemanggilan API Quotation Slip (QS).
/// Seluruh method melempar [QsApiException] jika server merespons non-2xx.
abstract class QsRepository {
  /// Mengambil data prefill dari pipeline atau QS yang sudah tersimpan.
  /// Endpoint: GET /api/pipelines/{pipelineId}/quotation-slips/prefill?qsId=...
  Future<Map<String, dynamic>> getPrefill({
    required String pipelineId,
    String? qsId,
    String? productCode,
  });

  /// Menyimpan/memperbarui draft QS pada step 1, 2, atau 3.
  /// Endpoint: POST /api/pipelines/{pipelineId}/quotation-slips
  /// atau POST /api/pipelines/{pipelineId}/quotation-slips/{productCode}
  Future<Map<String, dynamic>> upsertQuotationSlip({
    required String pipelineId,
    String? productCode,
    required Map<String, dynamic> payload,
  });

  /// Mengalkulasi rincian biaya asuransi secara real-time tanpa menyimpan ke database.
  /// Endpoint: POST /api/pipelines/{pipelineId}/quotation-slips/total-biaya-asuransi
  Future<QsTotalBiayaResult> calculateTotalBiaya({
    required String pipelineId,
    required Map<String, dynamic> payload,
  });

  /// Mengambil saran tarif flat per hari dari server.
  /// Endpoint: POST /api/pipelines/{pipelineId}/quotation-slips/saran-tarif-flat
  Future<double> getSaranTarifFlat({
    required String pipelineId,
    required Map<String, dynamic> payload,
  });

  /// Mengevaluasi aksi finalisasi (OK vs Ajukan ke UW beserta deviasi).
  /// Endpoint: POST /api/pipelines/{pipelineId}/quotation-slips/submit-action?qsId={qsId}
  Future<QsSubmitActionResult> submitAction({
    required String pipelineId,
    required String qsId,
    required Map<String, dynamic> payload,
  });

  /// Mengirimkan email PDF QS final ke customer.
  /// Endpoint: POST /api/pipelines/{pipelineId}/quotation-slips/submit?qsId={qsId}
  Future<Map<String, dynamic>> submitEmail({
    required String pipelineId,
    required String qsId,
  });

  /// Mengajukan QS ke Underwriting dengan alasan penyimpangan.
  /// Endpoint: POST /api/pipelines/{pipelineId}/quotation-slips/sent-to-underwriting?qsId={qsId}
  Future<Map<String, dynamic>> sentToUnderwriting({
    required String pipelineId,
    required String qsId,
    required String reason,
  });

  /// Mengambil byte dokumen PDF preview dari server.
  /// Endpoint: GET /api/pipelines/{pipelineId}/quotation-slips/{productKey}/preview-qs
  Future<Uint8List> getPreviewPdf({
    required String pipelineId,
    required String productKey,
    String? qsId,
  });

  /// Mengambil daftar riwayat Quotation Slip terpaginasi.
  /// Endpoint: GET /api/qs?page={page}&size={size}
  Future<List<QsRiwayatItem>> getRiwayat({
    int page = 0,
    int size = 20,
    String? pipelineId,
    String? productCode,
  });

  /// Mengambil daftar QS yang menunggu persetujuan Underwriting.
  /// Endpoint: GET /api/qs/list-persetujuan-uw?page={page}&size={size}
  Future<List<QsApprovalItemData>> getListPersetujuanUw({
    int page = 0,
    int size = 20,
  });

  /// Memberikan keputusan Underwriting (approve / reject).
  /// Endpoint: POST /api/qs/{qsId}/uw-decision
  Future<void> postUwDecision({
    required String qsId,
    required String action,
    String? uwReason,
  });

  /// Menyimpan status eksplisit sebagai DRAFT.
  /// Endpoint: POST /api/qs/{qsId}/save-draft
  Future<void> saveDraft({
    required String qsId,
  });
}
