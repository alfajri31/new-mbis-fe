import 'package:flutter/material.dart';

import '../../../src/customer/customer_repository.dart';
import '../../../theme/app_theme.dart';
import 'customer_info_row.dart';

/// Kartu "Informasi Perusahaan" di tab Ringkasan: NPWP, NIB, alamat, dan
/// kontak — sebelumnya hanya terlihat saat "Edit Customer". Baris yang kosong
/// disembunyikan; kalau semua kosong, kartunya tidak dirender. NPWP sudah
/// diformat oleh pemanggil ([npwpDisplay]). Murni presentational — diekstrak
/// dari `customer_detail_screen.dart` (behavior-preserving).
class CustomerIdentitySection extends StatelessWidget {
  const CustomerIdentitySection({
    super.key,
    required this.customer,
    required this.npwpDisplay,
  });

  final CustomerDetailModel customer;
  final String? npwpDisplay;

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final rows = <Widget>[];
    void add(IconData icon, String label, String? value) {
      if (value == null || value.trim().isEmpty) return;
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 20, color: AppColors.border));
      }
      rows.add(CustomerInfoRow(icon: icon, label: label, value: value.trim()));
    }

    add(Icons.badge_outlined, 'NPWP', npwpDisplay);
    add(Icons.assignment_outlined, 'NIB', c.nib);
    add(Icons.location_on_outlined, 'Alamat', c.address);
    add(Icons.email_outlined, 'Email Perusahaan', c.companyEmail);
    add(Icons.phone_outlined, 'Telepon Perusahaan', c.companyPhone);
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
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
              const Text(
                'Informasi Perusahaan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ...rows,
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
