import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../visit_rm_models.dart';

/// Komponen kartu item kunjungan RM individual dalam daftar kunjungan
class VisitItemCard extends StatelessWidget {
  final VisitModel visit;
  final RmModel rm;
  final bool isReviewed;
  final VoidCallback onTap;

  const VisitItemCard({
    super.key,
    required this.visit,
    required this.rm,
    required this.isReviewed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final stageInfo = VisitRmHelpers.getStageInfo(visit.stage);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar circle with camera badge
            _buildAvatarWithBadge(visit),
            const SizedBox(width: 12),

            // Company, Time/Cabang, and Badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visit.perusahaan,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${visit.jam} · KC ${rm.cab}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: stageInfo.bg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          stageInfo.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: stageInfo.fg,
                          ),
                        ),
                      ),
                      if (isReviewed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.badgeP1Bg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '✓ Ditinjau',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.greenTotal,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // RM name and Pipeline Value
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rm.nama,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textLabel,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  VisitRmHelpers.formatRupiah(visit.nilai),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyMbis,
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Nilai pipeline',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.iconDropdown,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWithBadge(VisitModel v) {
    if (!v.foto) {
      return const SizedBox(width: 52, height: 52);
    }
    final initials = VisitRmHelpers.getCompanyInitials(v.perusahaan);
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: VisitRmHelpers.getAvatarGradient(v.id),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.surfaceWhite,
              ),
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderDivider),
              ),
              child: const Icon(
                Icons.camera_alt_outlined,
                size: 11,
                color: AppColors.navyMbis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
