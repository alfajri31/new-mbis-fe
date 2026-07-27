import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'assistant_mascot.dart';

/// Gelembung chat dari maskot (avatar + kotak teks). Murni presentational —
/// diekstrak dari `assistant_screen.dart` (behavior-preserving).
class AssistantBubble extends StatelessWidget {
  const AssistantBubble({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AssistantMascot(size: 36, dark: true),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.border),
              boxShadow: const [AppShadows.level1],
            ),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
