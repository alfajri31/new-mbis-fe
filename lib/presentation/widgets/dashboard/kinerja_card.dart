import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Satu kartu pada grid Kinerja (2x3): ikon berwarna, nilai + suffix, dan label.
/// Murni presentational — diekstrak dari `dashboard_screen.dart`
/// (behavior-preserving). Aksi tap dikirim lewat [onTap]; bila null, affordance
/// unfold disembunyikan (kartu non-tappable).
class KinerjaCard extends StatelessWidget {
  const KinerjaCard({
    super.key,
    required this.label,
    required this.value,
    this.suffix,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final String? suffix;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceWhite,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        borderRadius: AppRadius.radiusLg,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: AppColors.border),
            boxShadow: const [AppShadows.level1],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.unfold_more,
                      size: 16,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ),
                  if (suffix != null) ...[
                    const SizedBox(width: 2),
                    Text(
                      suffix!.trim(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
