import 'package:flutter/material.dart';

import '../../../src/pipeline/pipeline_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// Kartu satu pipeline pada detail customer: judul produk, badge stage, penanda
/// referral/kerja sama, COB/LOB, estimasi premi & closing, dan (untuk WON) nilai
/// realisasi. [currentCustomerId] dipakai untuk menandai pipeline kerja sama yang
/// bukan milik customer ini; aksi tap dikirim lewat [onTap]. Murni presentational
/// — diekstrak dari `customer_detail_screen.dart` (behavior-preserving).
class PipelineCard extends StatelessWidget {
  const PipelineCard({
    super.key,
    required this.pipeline,
    required this.currentCustomerId,
    required this.onTap,
  });

  final PipelineListModel pipeline;
  final String currentCustomerId;
  final VoidCallback onTap;

  /// Short kerja-sama label for the card (KSO/JO/JV/QQ as-is, CABANG -> Cabang).
  String _ksLabel(String key) {
    return key.toUpperCase() == 'CABANG' ? 'Cabang' : key.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final p = pipeline;
    Color badgeColor;
    Color textColor = Colors.white;
    switch (p.stage) {
      case 'P3':
        badgeColor = AppColors.grayStage;
        break;
      case 'P2':
        badgeColor = AppColors.secondaryOrange;
        break;
      case 'P1':
        badgeColor = AppColors.primaryNavy;
        break;
      case 'WON':
        badgeColor = AppColors.successGreen;
        break;
      case 'DECLINE':
      default:
        badgeColor = AppColors.errorRed;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusLg,
        child: InkWell(
          borderRadius: AppRadius.radiusLg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        (p.product != null && p.product!.isNotEmpty)
                            ? p.product!
                            : 'Pipeline - ${p.customerName}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p.stage,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                // Referral menunggu approval BM (asal/tujuan).
                if (p.isReferral &&
                    (p.referralStatus == 'PENDING_SOURCE' ||
                        p.referralStatus == 'PENDING_DEST')) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryOrange.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.hourglass_top,
                          size: 12,
                          color: AppColors.secondaryOrange,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Menunggu Approval Referral',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Pipeline kerja sama yang dilihat dari customer mitra (bukan pemilik):
                // ditandai & tidak ikut dihitung pada angka customer ini.
                if (p.customerId != currentCustomerId) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryOrange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.handshake_outlined,
                          size: 12,
                          color: AppColors.secondaryOrange,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Kerja Sama · milik ${p.customerName}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondaryOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // COB & LOB, masing-masing satu baris dengan labelnya.
                if (p.cobName != null && p.cobName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'COB: ${p.cobName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (p.lobName != null && p.lobName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'LOB: ${p.lobName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                // Keterangan kerja sama (selain Individu): mitra selain customer ini.
                if (p.statusKerjaSama != null &&
                    p.statusKerjaSama!.toUpperCase() != 'INDIVIDU' &&
                    p.partyNames.length > 1) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.handshake_outlined,
                        size: 13,
                        color: AppColors.primaryNavy,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Kerjasama ${_ksLabel(p.statusKerjaSama!)} dengan ${p.partyNames.skip(1).join(', ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryNavy,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.border, width: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimasi Premi',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormat.rupiah(p.potensiPremi ?? 0),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryNavy,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Est. Closing',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormat.dateOnly(p.closingEstimasi),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Won pipelines also show the recorded realisasi (card grows taller).
                if (p.stage == 'WON' && p.realisasiIdr != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.border, width: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nilai Premi',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          AppFormat.rupiah(p.realisasiIdr!),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
