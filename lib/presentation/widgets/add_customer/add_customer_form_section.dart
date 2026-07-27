import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Kartu section berjudul (header + garis) yang membungkus sekelompok field
/// pada form Tambah Customer. Murni presentational — diekstrak dari
/// `add_customer_screen.dart` (behavior-preserving) agar layar lebih kecil.
class AddCustomerFormSection extends StatelessWidget {
  const AddCustomerFormSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
