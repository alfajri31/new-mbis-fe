import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Baris info generik: ikon navy + label kecil di atas nilai tebal. Dipakai
/// bersama oleh kartu Kepemilikan & kartu Informasi Perusahaan di detail
/// customer. Murni presentational — diekstrak dari `customer_detail_screen.dart`
/// (behavior-preserving).
class CustomerInfoRow extends StatelessWidget {
  const CustomerInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryNavy),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
