import 'package:flutter/material.dart';

import '../../src/customer/customer_repository.dart';
import '../../src/nav.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';

/// Kartu ringkas satu customer di daftar (avatar + nama/subtitle + chevron,
/// lalu baris statistik Pipeline/Potensi/Realisasi). Murni presentational —
/// diekstrak dari `customer_list_screen.dart` (behavior-preserving) agar layar
/// lebih kecil & siap dipakai ulang saat migrasi Riverpod.
class CustomerCard extends StatelessWidget {
  const CustomerCard({super.key, required this.customer});

  final CustomerListModel customer;

  @override
  Widget build(BuildContext context) {
    final entitas = customer.entityCategory ?? '-';

    Color entityColor;
    switch (entitas) {
      case 'BUMN':
        entityColor = AppColors.primaryNavy;
        break;
      case 'Swasta':
        entityColor = AppColors.secondaryOrange;
        break;
      case 'BUMD':
        entityColor = AppColors.successGreen;
        break;
      case 'Perorangan':
      default:
        entityColor = AppColors.grayStage;
        break;
    }

    final subtitle = <String>[
      if (entitas != '-') entitas,
      if (customer.state != null && customer.state!.isNotEmpty) customer.state!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level2],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusXl,
        child: InkWell(
          borderRadius: AppRadius.radiusXl,
          onTap: () async {
            // Nested route so the customer detail gets its own URL and survives
            // a web refresh; the list refreshes on return via didPopNext.
            goRel(context, '/${customer.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _avatar(customer.name, entityColor),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              height: 1.3,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: AppColors.grayStage,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      _statColumn(
                        'Pipeline',
                        '${customer.pipelineCount}',
                        AppColors.primaryNavy,
                      ),
                      _statDivider(),
                      _statColumn(
                        'Potensi',
                        AppFormat.currencyShort(customer.totalPotential),
                        AppColors.secondaryOrange,
                      ),
                      _statDivider(),
                      _statColumn(
                        'Realisasi',
                        AppFormat.currencyShort(customer.totalRealization),
                        AppColors.successGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(String name, Color color) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusMd,
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _statColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 28, color: AppColors.border);
}
