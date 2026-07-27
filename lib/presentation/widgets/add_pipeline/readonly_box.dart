import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Read-only labelled box (auto-calculated values like TSI/Premi in IDR).
/// Murni presentational — diekstrak dari `add_pipeline_screen.dart`
/// (behavior-preserving) agar layar lebih kecil.
class ReadonlyBox extends StatelessWidget {
  const ReadonlyBox({super.key, required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 52,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.grayBg,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
