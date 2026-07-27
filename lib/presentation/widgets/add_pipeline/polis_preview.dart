import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Preview nama gabungan yang akan tampil pada polis (sesuai jenis kerja sama).
/// Murni presentational — diekstrak dari `add_pipeline_screen.dart`
/// (behavior-preserving) agar layar lebih kecil. Nama polis dihitung di layar
/// dan diberikan lewat [previewName].
class PolisPreview extends StatelessWidget {
  const PolisPreview({super.key, required this.previewName});

  final String previewName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navyBg,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview Nama pada Polis',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryNavy,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            previewName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
