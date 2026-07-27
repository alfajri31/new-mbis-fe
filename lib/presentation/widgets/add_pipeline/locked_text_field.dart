import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../field_label.dart';

/// Read-only field (locked) — dipakai untuk pihak pertama kerja sama (customer).
/// Murni presentational — diekstrak dari `add_pipeline_screen.dart`
/// (behavior-preserving) agar layar lebih kecil.
class LockedTextField extends StatelessWidget {
  const LockedTextField({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fieldLabel(label),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.border.withValues(alpha: 0.25),
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline,
                size: 14,
                color: AppColors.grayStage,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value.isEmpty ? '-' : value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
