import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../field_label.dart';

/// Read-only display for a mandatory tender step (process can't be changed).
/// Murni presentational — diekstrak dari `add_pipeline_screen.dart`
/// (behavior-preserving) agar layar lebih kecil.
class LockedProcessField extends StatelessWidget {
  const LockedProcessField({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fieldLabel('Proses Tender *'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  label,
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
