import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Kotak disclaimer oranye (ikon info + teks). Murni presentational —
/// diekstrak dari `assistant_screen.dart` (behavior-preserving).
class AssistantDisclaimer extends StatelessWidget {
  const AssistantDisclaimer({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.orangeBg),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.secondaryOrange,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
