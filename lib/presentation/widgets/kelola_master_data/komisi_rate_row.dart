import 'package:flutter/material.dart';

import '../../../src/master_data/master_data_repository.dart';
import '../../../theme/app_theme.dart';

/// Satu baris rate komisi produk (ToC) — nama + badge persentase + tombol edit.
/// Murni presentational — diekstrak dari `kelola_master_data_screen.dart`
/// (`_KomisiTabState._row`), behavior-preserving; aksi edit lewat callback.
class KomisiRateRow extends StatelessWidget {
  const KomisiRateRow({super.key, required this.rate, required this.onEdit});

  final MasterProductRate rate;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = rate;
    final pct = p.percent;
    // Unset rate falls back to the backend default (10%); show it as a hint.
    final label = pct == null ? 'default (10%)' : '${_fmtPct(pct)}%';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        title: Text(
          p.tocName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          [
            if (p.cobName != null) p.cobName!,
            if (!p.active) 'nonaktif',
          ].join(' • '),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: pct == null ? AppColors.bgScreen : AppColors.navyBg,
                borderRadius: AppRadius.radiusSm,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: pct == null
                      ? AppColors.textSecondary
                      : AppColors.primaryNavy,
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: onEdit,
            ),
          ],
        ),
      ),
    );
  }

  /// Trims a trailing ".0" so 10.0 shows as "10" but 12.5 stays "12.5".
  String _fmtPct(double v) {
    final s = v.toStringAsFixed(2);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
