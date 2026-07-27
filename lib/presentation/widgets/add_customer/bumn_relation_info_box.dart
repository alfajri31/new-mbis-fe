import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Kotak informasi read-only struktur relasi & induk untuk customer BUMN.
/// Diturunkan otomatis dari node master_bumn yang dipilih (bukan input manual).
/// Murni presentational — diekstrak dari `add_customer_screen.dart`
/// (behavior-preserving).
class BumnRelationInfoBox extends StatelessWidget {
  const BumnRelationInfoBox({
    super.key,
    required this.strukturRelasi,
    required this.bumnInduk,
  });

  final String strukturRelasi;
  final String? bumnInduk;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Struktur Relasi: ${strukturRelasi.isEmpty ? '-' : strukturRelasi}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            'Induk: ${(bumnInduk == null || bumnInduk!.isEmpty) ? 'Induk teratas' : bumnInduk!}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
