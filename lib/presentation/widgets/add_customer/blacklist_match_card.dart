import 'package:flutter/material.dart';

import '../../../src/customer/customer_repository.dart';
import '../../../theme/app_theme.dart';

/// Kartu satu kemungkinan kecocokan blacklist (INAPROC/LKPP). Murni
/// presentational — diekstrak dari `add_customer_screen.dart`
/// (behavior-preserving).
class BlacklistMatchCard extends StatelessWidget {
  const BlacklistMatchCard({super.key, required this.match});

  final BlacklistMatch match;

  @override
  Widget build(BuildContext context) {
    final BlacklistMatch m = match;
    final Color chipColor = m.confidence == 'HIGH'
        ? AppColors.errorRed
        : m.confidence == 'MEDIUM'
        ? const Color(0xFFB7791F)
        : AppColors.textSecondary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  m.providerName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${m.confidence} · ${m.score}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: chipColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Cocok via: ${m.matchedBy.join(', ')}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (m.npwp != null && m.npwp!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'NPWP: ${m.npwp}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (m.violation != null && m.violation!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Pelanggaran: ${m.violation}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (m.skNumber != null && m.skNumber!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'SK: ${m.skNumber}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
