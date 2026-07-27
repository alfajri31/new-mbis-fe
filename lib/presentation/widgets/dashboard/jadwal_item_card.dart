import 'package:flutter/material.dart';

import '../../../src/dashboard/dashboard_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../utils/schedule_status.dart';

/// Satu kartu jadwal kunjungan (RM) di dashboard: badge status, nama customer,
/// judul, tanggal/jam, dan countdown. Aksi tap (navigasi ke pipeline) dikirim
/// lewat [onTap]; bila null kartu tidak tappable. Murni presentational —
/// diekstrak dari `dashboard_screen.dart` (behavior-preserving).
class JadwalItemCard extends StatelessWidget {
  const JadwalItemCard({super.key, required this.item, this.onTap});

  final DashboardSchedule item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Label/warna dari helper bersama — dipakai juga oleh kartu jadwal di detail
    // pipeline, supaya satu jadwal tak pernah tampil beda antara dua layar.
    final badge = scheduleBadgeOf(item.status);
    final statusColor = badge.color;
    final statusIcon = badge.icon;
    final statusLabel = badge.label;

    final isOverdue = (item.status ?? '').toLowerCase() == 'overdue';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: isOverdue
                ? AppColors.errorRed.withValues(alpha: 0.25)
                : AppColors.border,
            width: 1,
          ),
          boxShadow: const [AppShadows.level1],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.customerName ?? 'Customer',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Status badge — top-right of the card.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, color: statusColor, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.title ?? '-',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppFormat.dateOnly(item.scheduleDateTime),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppFormat.timeOnly(item.scheduleDateTime),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (item.countdownLabel != null)
                        Text(
                          item.countdownLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.grayStage,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
