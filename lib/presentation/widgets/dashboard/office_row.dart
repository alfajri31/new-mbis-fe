import 'package:flutter/material.dart';

import '../../../src/dashboard/dashboard_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// A per-wilayah/cabang/RM row on the dashboard. Tapping opens the RM list
/// filtered to that office (or, for an RM row, searched by the RM's name) —
/// the navigation decision lives in the parent and arrives via [onTap].
/// Murni presentational — diekstrak dari `dashboard_screen.dart`
/// (behavior-preserving).
class OfficeRow extends StatelessWidget {
  const OfficeRow({super.key, required this.office, this.onTap});

  final OfficeStat office;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final o = office;
    final isRm = o.type == 'RM';
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusLg,
        child: InkWell(
          borderRadius: AppRadius.radiusLg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isRm ? Icons.person_outline : Icons.business_outlined,
                      size: 18,
                      color: AppColors.primaryNavy,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        o.name ?? o.id,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (!isRm)
                      Text(
                        '${o.rmCount} RM',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: AppColors.grayStage,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: 6,
                  children: [
                    _rmChip(
                      Icons.people_outline,
                      '${o.totalCustomers} customer',
                    ),
                    _rmChip(
                      Icons.account_tree_outlined,
                      '${o.activePipelines} aktif',
                    ),
                    _rmChip(Icons.emoji_events_outlined, '${o.wonCount} won'),
                    _rmChip(Icons.place_outlined, '${o.visitCountYtd} visit'),
                    _rmChip(
                      Icons.trending_up,
                      AppFormat.currencyShort(o.realisasi),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _rmChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
