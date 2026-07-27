import 'package:flutter/material.dart';

import '../../../src/visit/visit_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// Kartu satu kunjungan pada riwayat kunjungan customer: badge tipe, waktu, dan
/// catatan. Aksi tap (buka detail kunjungan) dikirim lewat [onTap]. Murni
/// presentational — diekstrak dari `customer_detail_screen.dart`
/// (behavior-preserving).
class CustomerVisitCard extends StatelessWidget {
  const CustomerVisitCard({
    super.key,
    required this.visit,
    required this.onTap,
  });

  final VisitModel visit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = visit;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
          boxShadow: const [AppShadows.level1],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.orangeLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.place_outlined,
                size: 17,
                color: AppColors.secondaryOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.navyBg,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          v.type,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.access_time,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          AppFormat.dateTime(v.activityDate),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if ((v.notes ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      v.notes!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.grayStage,
            ),
          ],
        ),
      ),
    );
  }
}
