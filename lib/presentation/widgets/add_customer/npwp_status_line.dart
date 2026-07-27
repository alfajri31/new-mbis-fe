import 'package:flutter/material.dart';

import '../../../src/customer/customer_repository.dart';
import '../../../theme/app_theme.dart';

/// Baris status validasi NPWP (terdaftar DJP / tidak / tidak divalidasi).
/// Murni presentational — diekstrak dari `add_customer_screen.dart`
/// (behavior-preserving).
class NpwpStatusLine extends StatelessWidget {
  const NpwpStatusLine({super.key, required this.result});

  final BlacklistCheckResult result;

  @override
  Widget build(BuildContext context) {
    final bool? valid = result.npwpValid;
    final String text;
    final Color color;
    final IconData icon;
    if (valid == null) {
      text = 'NPWP: tidak divalidasi';
      color = AppColors.textSecondary;
      icon = Icons.help_outline;
    } else if (valid) {
      text = 'NPWP terdaftar di DJP';
      color = AppColors.successGreen;
      icon = Icons.verified_outlined;
    } else {
      text = 'NPWP tidak ditemukan di DJP';
      color = AppColors.errorRed;
      icon = Icons.report_gmailerrorred_outlined;
    }
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
