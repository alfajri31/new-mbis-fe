import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../visit_rm_models.dart';

/// Kartu daftar RM yang belum melakukan visit pada periode filter terpilih
class VisitRmIdleCard extends StatelessWidget {
  final List<RmModel> idleRms;

  const VisitRmIdleCard({
    super.key,
    required this.idleRms,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border.all(color: AppColors.alertBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'RM belum melakukan visit pada periode ini',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColors.alertTitle,
            ),
          ),
          const SizedBox(height: 8),
          if (idleRms.isEmpty)
            const Text(
              'Semua RM sudah visit.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            )
          else
            ...idleRms.map((rm) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.badgeIdleDivider)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.badgeP2Bg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline, size: 18, color: AppColors.alertTitle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rm.nama,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            '${rm.jab} · KC ${rm.cab}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
