import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Baris 4 kartu ringkasan metrik kunjungan RM (Total, Aktif, Idle, Rata-rata)
class VisitRmMetricsRow extends StatelessWidget {
  final int total;
  final int activeRm;
  final int idleRm;
  final String avg;
  final VoidCallback onToggleIdle;

  const VisitRmMetricsRow({
    super.key,
    required this.total,
    required this.activeRm,
    required this.idleRm,
    required this.avg,
    required this.onToggleIdle,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildMetricItem(
              number: '$total',
              label: 'Total Visit',
              numColor: AppColors.navyMbis,
              bgColor: AppColors.surfaceWhite,
              borderColor: AppColors.borderDivider,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricItem(
              number: '$activeRm',
              label: 'RM Aktif',
              numColor: AppColors.navyMbis,
              bgColor: AppColors.surfaceWhite,
              borderColor: AppColors.borderDivider,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricItem(
              number: '$idleRm',
              label: 'RM Belum Visit ›',
              numColor: AppColors.orangeDark,
              bgColor: AppColors.alertBg,
              borderColor: AppColors.alertBorder,
              onTap: onToggleIdle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildMetricItem(
              number: avg,
              label: 'Rata-rata / RM',
              numColor: AppColors.navyMbis,
              bgColor: AppColors.surfaceWhite,
              borderColor: AppColors.borderDivider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String number,
    required String label,
    required Color numColor,
    required Color bgColor,
    required Color borderColor,
    VoidCallback? onTap,
  }) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                number,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: numColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: onTap != null ? AppColors.alertTitle : AppColors.textMuted,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
