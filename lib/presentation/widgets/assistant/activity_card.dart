import 'package:flutter/material.dart';

import '../../../src/assistant/assistant_repository.dart';
import '../../../theme/app_theme.dart';

/// Kartu satu aktivitas AI di daftar (ikon + nama/deskripsi + alasan tak
/// tersedia + chevron). Murni presentational — diekstrak dari
/// `assistant_screen.dart` (behavior-preserving). [enabled] & [onTap] disuplai
/// oleh layar (bergantung eligibility + peran RM).
class ActivityCard extends StatelessWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    required this.enabled,
    this.onTap,
  });

  final AiActivity activity;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radius2Xl,
          border: Border.all(color: AppColors.border),
          boxShadow: const [AppShadows.level1],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.radius2Xl,
          child: InkWell(
            borderRadius: AppRadius.radius2Xl,
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.navyBg,
                      borderRadius: AppRadius.radiusLg,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      a.icon ?? '🤖',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if ((a.description ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            a.description!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                        if (!a.eligible &&
                            (a.ineligibleReason ?? '').isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Tidak tersedia — ${a.ineligibleReason}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.errorRed,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (enabled)
                    const Icon(Icons.chevron_right, color: AppColors.grayStage),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
