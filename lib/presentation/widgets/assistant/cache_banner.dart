import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// Ditampilkan di atas jawaban tersimpan: hasil ini tidak memakai token, dan
/// kapan dibuat. Murni presentational — diekstrak dari `assistant_screen.dart`
/// (behavior-preserving). [cachedAt] disuplai layar (waktu simpan mentah).
class CacheBanner extends StatelessWidget {
  const CacheBanner({super.key, required this.cachedAt});

  final String? cachedAt;

  @override
  Widget build(BuildContext context) {
    final when = cachedAt != null ? AppFormat.dateTime(cachedAt) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.greenLight,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: AppColors.successGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.bookmark_outline,
            size: 18,
            color: AppColors.successGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              when != null
                  ? 'Hasil tersimpan ($when) — tidak memakai token. Jalankan ulang bila data sudah berubah.'
                  : 'Hasil tersimpan — tidak memakai token. Jalankan ulang bila data sudah berubah.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
