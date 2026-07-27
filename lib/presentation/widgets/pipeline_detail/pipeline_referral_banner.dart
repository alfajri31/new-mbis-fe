import 'package:flutter/material.dart';

import '../../../src/pipeline/pipeline_repository.dart';
import '../../../theme/app_theme.dart';

/// Referral status banner (only for referral pipelines).
/// Murni presentational — diekstrak dari `pipeline_detail_screen.dart`
/// (behavior-preserving). Gunakan [maybe] agar spasi di sekitar banner tetap
/// sama persis: mengembalikan `null` bila banner tidak perlu ditampilkan.
class PipelineReferralBanner extends StatelessWidget {
  const PipelineReferralBanner({
    super.key,
    required this.pipeline,
    required this.currentUserId,
  });

  final PipelineDetailModel pipeline;
  final String? currentUserId;

  /// Returns the banner widget, or `null` when there is nothing to show —
  /// preserving the original `_buildReferralBanner(...)` return contract.
  static Widget? maybe(PipelineDetailModel p, {required String? currentUserId}) {
    if (!p.isReferral) return null;
    final status = p.referralStatus;
    final isKnown = status == 'APPROVED' ||
        status == 'PENDING_SOURCE' ||
        status == 'PENDING_DEST' ||
        status == 'REJECTED';
    if (!isKnown) return null;
    return PipelineReferralBanner(pipeline: p, currentUserId: currentUserId);
  }

  @override
  Widget build(BuildContext context) {
    final p = pipeline;
    final status = p.referralStatus;
    final isOriginalReferrer =
        currentUserId != null && currentUserId == p.referralFromRmId;
    late final Color color;
    late final IconData icon;
    late final String title;
    late final String subtitle;
    if (status == 'APPROVED') {
      if (isOriginalReferrer) {
        color = AppColors.secondaryOrange;
        icon = Icons.forward_to_inbox;
        title = 'Sudah diserahkan ke RM cabang tujuan';
        subtitle = 'Anda hanya dapat menambahkan dokumen; tahap/visit/jadwal '
            'dikelola RM tujuan.';
      } else {
        color = AppColors.successGreen;
        icon = Icons.assignment_ind_outlined;
        title = 'Pipeline referral (diterima)';
        subtitle = 'Pipeline ini diserahkan ke Anda melalui referral cabang. '
            'Dokumen SPAU/Underlying diunggah oleh RM asal — SPAU wajib ada sebelum bisa WON.';
      }
    } else if (status == 'PENDING_SOURCE' || status == 'PENDING_DEST') {
      color = AppColors.secondaryOrange;
      icon = Icons.hourglass_top;
      title = 'Menunggu Approval Referral';
      subtitle = status == 'PENDING_SOURCE'
          ? 'Menunggu persetujuan BM cabang asal.'
          : 'Menunggu persetujuan BM cabang tujuan.';
    } else if (status == 'REJECTED') {
      color = AppColors.errorRed;
      icon = Icons.cancel_outlined;
      title = 'Referral ditolak';
      subtitle = (p.referralRejectReason != null && p.referralRejectReason!.isNotEmpty)
          ? 'Alasan: ${p.referralRejectReason}'
          : 'Referral dibatalkan; pipeline tetap milik RM pembuat.';
    } else {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textPrimary, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
