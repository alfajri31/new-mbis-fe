import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import 'assistant_mascot.dart';

/// Layar tunggu saat AI sedang menyusun jawaban (maskot + spinner + teks).
/// Murni presentational — diekstrak dari `assistant_screen.dart`
/// (behavior-preserving).
class AssistantLoadingView extends StatelessWidget {
  const AssistantLoadingView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AssistantMascot(size: 64),
        const SizedBox(height: 16),
        const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
        const SizedBox(height: 16),
        const Text(
          'Sedang menyusun jawaban…',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Bisa beberapa detik bila meriset di web.',
          style: TextStyle(fontSize: 12, color: AppColors.grayStage),
        ),
      ],
    ),
  );
}
