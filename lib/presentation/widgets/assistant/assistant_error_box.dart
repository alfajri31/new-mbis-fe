import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Kotak error merah (ikon + teks). Murni presentational — diekstrak dari
/// `assistant_screen.dart` (behavior-preserving).
class AssistantErrorBox extends StatelessWidget {
  const AssistantErrorBox({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.redLight,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.errorRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: AppColors.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}
