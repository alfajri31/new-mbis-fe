import 'package:flutter/material.dart';

import '../../../src/master_data/master_data_repository.dart';
import '../../../theme/app_theme.dart';

/// Satu baris BUMN (nama + level/badan hukum/induk + menu edit/hapus).
/// Murni presentational — diekstrak dari `kelola_master_data_screen.dart`
/// (`_BumnTabState._row`), behavior-preserving; aksi lewat callback.
class BumnRow extends StatelessWidget {
  const BumnRow({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final BumnMasterItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final b = item;
    final sub = [
      if (b.level != null && b.level!.isNotEmpty) b.level!,
      if (b.badanHukum != null && b.badanHukum!.isNotEmpty) b.badanHukum!,
      if (b.parentName != null && b.parentName!.isNotEmpty)
        'Induk: ${b.parentName}'
      else
        'Induk teratas',
      if (!b.active) 'nonaktif',
    ].join(' • ');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        title: Text(
          b.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: b.active ? null : AppColors.grayStage,
          ),
        ),
        subtitle: Text(
          sub,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: 'delete',
              child: Text('Hapus', style: TextStyle(color: AppColors.errorRed)),
            ),
          ],
        ),
      ),
    );
  }
}
