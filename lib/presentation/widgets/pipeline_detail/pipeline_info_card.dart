import 'package:flutter/material.dart';

import '../../../src/pipeline/pipeline_repository.dart';
import '../../../src/pipeline/pipeline_stage.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// The "Informasi Pipeline" summary card (left column on desktop).
/// Murni presentational — diekstrak dari `pipeline_detail_screen.dart`
/// (behavior-preserving).
class PipelineInfoCard extends StatelessWidget {
  const PipelineInfoCard({super.key, required this.pipeline});

  final PipelineDetailModel pipeline;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Informasi Pipeline',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                _buildStageBadge(pipeline.stage),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildInfoRow('Sumber Bisnis', pipeline.sourceType ?? '-'),
          _buildInfoRow('Tahap', PipelineStages.labelOf(pipeline.subStage)),
          if (pipeline.projectName != null && pipeline.projectName!.isNotEmpty)
            _buildInfoRow('Nama Proyek', pipeline.projectName!),
          if (pipeline.statusKerjaSama != null && pipeline.statusKerjaSama!.isNotEmpty)
            _buildInfoRow('Status Kerja Sama', pipeline.statusKerjaSama!),
          if (pipeline.cobName != null && pipeline.cobName!.isNotEmpty)
            _buildInfoRow('COB', pipeline.cobName!),
          if (pipeline.product != null && pipeline.product!.isNotEmpty)
            _buildInfoRow('Produk (ToC)', pipeline.product!),
          if (pipeline.isTender) _buildInfoRow('Tender', 'Ya'),
          if (pipeline.isTender && pipeline.tenderRole != null)
            _buildInfoRow('Peran Tender', pipeline.tenderRole == 'LEADER' ? 'Leader' : 'Member'),
          if (pipeline.policyNumber != null && pipeline.policyNumber!.isNotEmpty)
            _buildInfoRow('No. Polis', pipeline.policyNumber!),
          // Tanggal terbit polis menentukan bulan realisasi diakui (CR-04), jadi
          // harus bisa diperiksa ulang RM setelah disimpan. Sebelumnya nilainya
          // tersimpan tetapi tidak pernah ditampilkan di layar mana pun.
          if (pipeline.policyIssuedDate != null &&
              pipeline.policyIssuedDate!.isNotEmpty)
            _buildInfoRow(
                'Tanggal Terbit Polis', AppFormat.dateOnly(pipeline.policyIssuedDate)),
          if (pipeline.shareAskrindo != null)
            _buildInfoRow('Share Askrindo', '${pipeline.shareAskrindo!.toStringAsFixed(2)}%'),
          _buildInfoRow('TSI/Plafond Nilai Jaminan', AppFormat.rupiah(pipeline.tsiIdr)),
          if (pipeline.ratePremi != null)
            _buildInfoRow('Rate Premi', _ratePercent(pipeline.ratePremi!)),
          if (pipeline.potensiPremi != null)
            _buildInfoRow('Potensi Premi', AppFormat.rupiah(pipeline.potensiPremi!)),
          if (pipeline.premi != null)
            _buildInfoRow('Total Premi', AppFormat.rupiah(pipeline.premi!)),
          if (pipeline.realisasiIdr != null)
            _buildInfoRow('Nilai Premi', AppFormat.rupiah(pipeline.realisasiIdr!)),
          _buildInfoRow('Est. Closing', AppFormat.dateOnly(pipeline.closingEstimasi), isLast: true),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  /// Formats a percent rate with Indonesian decimal comma, e.g. 2.5 -> "2,5%".
  String _ratePercent(double rate) {
    var s = rate.toStringAsFixed(2);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return '${s.replaceAll('.', ',')}%';
  }

  Widget _buildStageBadge(String stage) {
    Color badgeColor;
    switch (stage.toUpperCase()) {
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
      default:
        badgeColor = AppColors.errorRed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        stage,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
