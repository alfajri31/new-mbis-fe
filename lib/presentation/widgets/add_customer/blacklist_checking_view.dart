import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Tampilan loading saat proses pengecekan blacklist berjalan (spinner +
/// keterangan). Murni presentational — diekstrak dari `add_customer_screen.dart`
/// (behavior-preserving).
class BlacklistCheckingView extends StatelessWidget {
  const BlacklistCheckingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(height: 20),
        SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.primaryNavy,
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Memeriksa Blacklist...',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Menyimpan data & mengecek INAPROC (LKPP) + NPWP',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        SizedBox(height: 20),
      ],
    );
  }
}
