import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Keadaan informatif & ramah saat kuota AI harian RM habis (HTTP 429).
/// Nada "tunggu" hangat (bukan error merah) dan menjelaskan langkah lanjut.
/// Murni presentational — diekstrak dari `assistant_screen.dart`
/// (behavior-preserving).
class AssistantLimitBox extends StatelessWidget {
  const AssistantLimitBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: AppColors.secondaryOrange.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.orangeBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_bottom_rounded,
              size: 18,
              color: AppColors.secondaryOrange,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kuota AI harian Anda sudah habis',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Anda telah memakai seluruh jatah menjalankan AI untuk hari ini. '
                  'Kuota pulih otomatis besok (tengah malam WIB). Bila mendesak, '
                  'minta admin untuk mereset kuota Anda.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
