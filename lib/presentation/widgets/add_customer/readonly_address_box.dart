import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../field_label.dart';

/// Kotak alamat read-only (diisi otomatis dari cabang bank terpilih). Murni
/// presentational — diekstrak dari `add_customer_screen.dart`
/// (behavior-preserving).
class ReadonlyAddressBox extends StatelessWidget {
  const ReadonlyAddressBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        fieldLabel('Alamat (dari cabang)'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
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
            ),
          ),
        ),
      ],
    );
  }
}
