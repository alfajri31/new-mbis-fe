import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Web replacement for the "Tambah Aktivitas/Visit" button: recording a visit
/// needs a live camera photo + GPS, which only the mobile app provides. Shown
/// on web (laptop/desktop) so the supervisor view stays read-only for visits.
/// Murni presentational — diekstrak dari `pipeline_detail_screen.dart`
/// (behavior-preserving).
class PipelineVisitWebNotice extends StatelessWidget {
  const PipelineVisitWebNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.phone_iphone, size: 22, color: AppColors.grayStage),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Catat kunjungan lewat aplikasi HP — wajib foto kamera & lokasi GPS '
              'yang tidak tersedia di web.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
