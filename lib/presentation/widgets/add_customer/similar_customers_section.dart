import 'package:flutter/material.dart';

import '../../../src/customer/customer_repository.dart';
import '../../../theme/app_theme.dart';

/// "Kemungkinan sudah ada" — daftar customer existing yang mungkin entitas yang
/// sama, ditampilkan sebelum RM menyimpan agar perusahaan swasta multi-cabang
/// tetap satu entitas. Murni presentational — diekstrak dari
/// `add_customer_screen.dart` (behavior-preserving).
class SimilarCustomersSection extends StatelessWidget {
  const SimilarCustomersSection({super.key, required this.similarCustomers});

  final List<SimilarCustomer> similarCustomers;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.navyBg,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.primaryNavy,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Kemungkinan sudah ada (${similarCustomers.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Customer serupa sudah terdaftar di cabang lain. Pastikan ini memang entitas '
            'baru sebelum menyimpan — hubungi RM pemilik bila perlu.',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: Column(
                children: similarCustomers
                    .map((s) => SimilarCustomerCard(customer: s))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu satu kandidat customer serupa. Murni presentational — diekstrak dari
/// `add_customer_screen.dart` (behavior-preserving).
class SimilarCustomerCard extends StatelessWidget {
  const SimilarCustomerCard({super.key, required this.customer});

  final SimilarCustomer customer;

  @override
  Widget build(BuildContext context) {
    final SimilarCustomer s = customer;
    final strong = s.confidence == 'HIGH';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusSm,
        border: Border.all(
          color: strong ? AppColors.secondaryOrange : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: strong ? AppColors.orangeLight : AppColors.grayBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  s.reason,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: strong
                        ? AppColors.secondaryOrange
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (s.officeName != null) s.officeName!,
              if (s.rmName != null) 'RM ${s.rmName}',
            ].join(' · '),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
