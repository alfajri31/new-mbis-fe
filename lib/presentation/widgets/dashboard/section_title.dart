import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Judul seksi pada dashboard, dengan opsi teks [trailing] atau aksi
/// ([actionLabel] + [onActionTap]) di sisi kanan. Murni presentational —
/// diekstrak dari `dashboard_screen.dart` (behavior-preserving).
class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.trailing,
    this.onActionTap,
    this.actionLabel,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onActionTap;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        if (onActionTap != null && actionLabel != null)
          InkWell(
            onTap: onActionTap,
            child: Row(
              children: [
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryOrange,
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: AppColors.secondaryOrange,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
