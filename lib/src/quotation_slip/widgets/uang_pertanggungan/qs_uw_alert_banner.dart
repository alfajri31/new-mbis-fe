import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../qs_form_state.dart';

/// Banner alert jika ada penyimpangan underwriting (UW)
class QsUwAlertBanner extends StatelessWidget {
  final List<UwDeviation> deviations;

  const QsUwAlertBanner({
    super.key,
    required this.deviations,
  });

  @override
  Widget build(BuildContext context) {
    if (deviations.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.alertBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.alertBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '⚠ Memerlukan Approval Underwriting (UW)',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.alertTitle,
            ),
          ),
          const SizedBox(height: 6),
          ...deviations.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.alertText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${d.field}: ${d.message}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.alertText,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          const Text(
            'QS tetap bisa disimpan sebagai Draft (tanpa nomor) dan dilihat di Preview. Ajukan ke UW dari Preview QS, atau sesuaikan isian agar sesuai ketentuan.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
