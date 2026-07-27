import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Kartu statistik kecil (nilai besar berwarna + label) pada grid ringkasan
/// customer (Pipeline P3/P2/P1/Won). Murni presentational — diekstrak dari
/// `customer_detail_screen.dart` (behavior-preserving).
class CustomerStatCard extends StatelessWidget {
  const CustomerStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
