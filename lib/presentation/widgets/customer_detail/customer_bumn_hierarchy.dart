import 'package:flutter/material.dart';

import '../../../src/customer/customer_repository.dart';
import '../../../theme/app_theme.dart';

/// BUMN position on the customer header: a badge for the customer's own level,
/// then its ancestors stated explicitly (e.g. "Induk: PLN", "Anak: PLN IP").
/// Murni presentational — diekstrak dari `customer_detail_screen.dart`
/// (behavior-preserving).
class CustomerBumnHierarchy extends StatelessWidget {
  const CustomerBumnHierarchy({super.key, required this.customer});

  final CustomerDetailModel customer;

  Color _bumnLevelColor(String? level) {
    switch (level) {
      case 'Induk':
        return AppColors.primaryNavy;
      case 'Anak':
        return AppColors.secondaryOrange;
      case 'Cucu':
        return AppColors.successGreen;
      case 'Cicit':
        return AppColors.purpleAccent;
      default:
        return AppColors.grayStage;
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = customer.bumnPath;
    final self = path.last;
    final ancestors = path.sublist(0, path.length - 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Level badge (white chip, colored text — readable on the navy header).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_tree,
                size: 12,
                color: _bumnLevelColor(self.level),
              ),
              const SizedBox(width: 4),
              Text(
                self.level ?? 'BUMN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _bumnLevelColor(self.level),
                ),
              ),
            ],
          ),
        ),
        for (final a in ancestors)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '${a.level ?? 'Induk'}: ${a.name}',
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
      ],
    );
  }
}
