import 'package:flutter/material.dart';

import '../../../src/pipeline/pipeline_repository.dart';
import '../../../theme/app_theme.dart';

/// Documents (SPAU / Underlying) — available for every pipeline; the original
/// referring RM may still upload here after handover.
/// Murni presentational — diekstrak dari `pipeline_detail_screen.dart`
/// (behavior-preserving). Aksi upload/hapus dilewatkan lewat callback.
class PipelineDocumentsCard extends StatelessWidget {
  const PipelineDocumentsCard({
    super.key,
    required this.pipeline,
    required this.docs,
    required this.currentUserId,
    required this.isAgent,
    required this.onUpload,
    required this.onDelete,
  });

  final PipelineDetailModel pipeline;
  final List<PipelineDocumentModel> docs;
  final String? currentUserId;
  final bool isAgent;
  final ValueChanged<String> onUpload;
  final ValueChanged<PipelineDocumentModel> onDelete;

  @override
  Widget build(BuildContext context) {
    // Pada pipeline referral yang sudah di-handover (APPROVED), dokumen SPAU/Underlying
    // hanya boleh dikelola RM ASAL. RM operan (penerima) diblur & diberi keterangan —
    // SPAU wajib ada (diunggah asal) sebelum operan bisa WON.
    final isReferralHandedOver =
        pipeline.isReferral && pipeline.referralStatus == 'APPROVED';
    final isOriginalReferrer =
        currentUserId != null && currentUserId == pipeline.referralFromRmId;
    final docLockedForOperan = isReferralHandedOver && !isOriginalReferrer;
    final canEditDocs = !isAgent && !docLockedForOperan;
    PipelineDocumentModel? docOf(String type) {
      for (final d in docs) {
        if (d.docType == type) return d;
      }
      return null;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dokumen',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                if (docLockedForOperan) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: const [
                      Icon(Icons.lock_outline, size: 13, color: AppColors.textSecondary),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text('Hanya RM asal yang boleh mengupload dokumen SPAU/Underlying.',
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _docSlot('SPAU', 'SPAU', docOf('SPAU'),
              canEdit: canEditDocs, lockedForOperan: docLockedForOperan),
          const Divider(height: 1, color: AppColors.border),
          _docSlot('Underlying', 'UNDERLYING', docOf('UNDERLYING'),
              canEdit: canEditDocs, lockedForOperan: docLockedForOperan),
        ],
      ),
    );
  }

  Widget _docSlot(String label, String docType, PipelineDocumentModel? doc,
      {required bool canEdit, bool lockedForOperan = false}) {
    // Slot yang dikunci untuk RM operan (referral) ditampilkan burem + label kunci.
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(doc != null ? Icons.description : Icons.upload_file,
              size: 20, color: doc != null ? AppColors.primaryNavy : AppColors.grayStage),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(doc != null ? doc.fileName : 'Belum diunggah',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (canEdit) ...[
            TextButton(
              onPressed: () => onUpload(docType),
              child: Text(doc == null ? 'Upload' : 'Ganti',
                  style: const TextStyle(fontSize: 12, color: AppColors.primaryNavy)),
            ),
            if (doc != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.errorRed),
                tooltip: 'Hapus',
                onPressed: () => onDelete(doc),
              ),
          ] else if (lockedForOperan)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline, size: 14, color: AppColors.grayStage),
                SizedBox(width: 4),
                Text('Hanya RM asal',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
        ],
      ),
    );
    return lockedForOperan ? Opacity(opacity: 0.55, child: content) : content;
  }
}
