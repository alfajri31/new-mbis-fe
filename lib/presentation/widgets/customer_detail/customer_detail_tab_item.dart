import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Satu item tab bar pada detail customer (Ringkasan/Dokumen/Kontak): label
/// dengan garis bawah navy saat aktif. Status aktif dikirim lewat [isActive] dan
/// aksi tap lewat [onTap] (parent yang memegang state tab). Murni presentational
/// — diekstrak dari `customer_detail_screen.dart` (behavior-preserving).
class CustomerDetailTabItem extends StatelessWidget {
  const CustomerDetailTabItem({
    super.key,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? AppColors.primaryNavy : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? AppColors.primaryNavy : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
