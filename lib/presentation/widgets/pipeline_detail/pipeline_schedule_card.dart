import 'package:flutter/material.dart';

import '../../../src/pipeline/pipeline_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../../utils/schedule_status.dart';

/// One "Jadwal Mendatang" card (status badge + date/time + agenda), with an
/// optional edit/cancel/complete menu for OPEN schedules.
/// Murni presentational — diekstrak dari `pipeline_detail_screen.dart`
/// (behavior-preserving). Aksi ubah/batal dilewatkan lewat callback.
class PipelineScheduleCard extends StatelessWidget {
  const PipelineScheduleCard({
    super.key,
    required this.schedule,
    this.editable = false,
    required this.onEdit,
    required this.onCancel,
    required this.onComplete,
  });

  final PipelineScheduleModel schedule;
  final bool editable;
  final ValueChanged<PipelineScheduleModel> onEdit;
  final ValueChanged<PipelineScheduleModel> onCancel;
  final ValueChanged<PipelineScheduleModel> onComplete;

  @override
  Widget build(BuildContext context) {
    final s = schedule;
    // Badge dihitung lewat helper bersama: jadwal OPEN yang tanggalnya sudah
    // lewat harus terbaca "Terlambat" seperti di dashboard. Sebelumnya kartu ini
    // hanya membedakan DONE vs bukan, jadi jadwal telat tetap tertulis
    // "Mendatang" dan bertentangan dengan dashboard.
    final badge = pipelineScheduleBadge(status: s.status, isoDate: s.date);
    // Only OPEN schedules are reschedulable (backend rejects DONE/CANCELLED).
    final canEdit = editable && s.status.toUpperCase() == 'OPEN';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badge.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badge.icon, size: 12, color: badge.color),
                    const SizedBox(width: 4),
                    Text(
                      badge.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badge.color,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(AppFormat.dateOnly(s.date),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(AppFormat.timeOnly(s.date),
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    if (canEdit) ...[
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.primaryNavy),
                          tooltip: 'Aksi jadwal',
                          padding: EdgeInsets.zero,
                          onSelected: (v) {
                            if (v == 'edit') onEdit(s);
                            if (v == 'cancel') onCancel(s);
                            if (v == 'done') onComplete(s);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'done',
                              child: Row(children: [
                                Icon(Icons.check_circle_outline, size: 18, color: AppColors.successGreen),
                                SizedBox(width: 10),
                                Text('Tandai selesai'),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(children: [
                                Icon(Icons.edit_calendar_outlined, size: 18, color: AppColors.primaryNavy),
                                SizedBox(width: 10),
                                Text('Ubah jadwal'),
                              ]),
                            ),
                            PopupMenuItem(
                              value: 'cancel',
                              child: Row(children: [
                                Icon(Icons.event_busy_outlined, size: 18, color: AppColors.errorRed),
                                SizedBox(width: 10),
                                Text('Batalkan jadwal', style: TextStyle(color: AppColors.errorRed)),
                              ]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Activity Description
          Text(
            s.title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
