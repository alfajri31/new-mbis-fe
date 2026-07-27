import 'package:flutter/material.dart';

import '../../../src/customer/customer_repository.dart';
import '../../../theme/app_theme.dart';

/// Tab "Kontak" pada detail customer: dua kartu (Kontak Perusahaan & Kontak PIC)
/// dibangun dari field customer sendiri (tanpa API terpisah). Murni
/// presentational — diekstrak dari `customer_detail_screen.dart`
/// (behavior-preserving).
class CustomerKontakTab extends StatelessWidget {
  const CustomerKontakTab({super.key, required this.customer});

  final CustomerDetailModel customer;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final companyLines = [
      if ((c.companyPhone ?? '').isNotEmpty) c.companyPhone!,
      if ((c.companyEmail ?? '').isNotEmpty) c.companyEmail!,
    ];
    final picLines = [
      if ((c.picName ?? '').isNotEmpty) c.picName!,
      if ((c.picJabatan ?? '').isNotEmpty) c.picJabatan!,
      if ((c.picPhone ?? '').isNotEmpty) c.picPhone!,
    ];
    return Column(
      children: [
        _contactCard(Icons.business, 'Kontak Perusahaan', companyLines),
        const SizedBox(height: 10),
        _contactCard(Icons.person_outline, 'Kontak PIC', picLines),
      ],
    );
  }

  Widget _contactCard(IconData icon, String title, List<String> lines) {
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
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryNavy),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (lines.isEmpty)
            const Text(
              'Kontak belum ditambahkan',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            )
          else
            ...lines.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  l,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
