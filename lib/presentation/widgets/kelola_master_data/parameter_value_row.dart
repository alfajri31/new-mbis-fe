import 'package:flutter/material.dart';

import '../../../src/master_data/master_data_repository.dart';
import '../../../theme/app_theme.dart';

/// Satu baris nilai parameter (label + meta rate/nonaktif + menu edit/hapus).
/// Murni presentational — diekstrak dari `kelola_master_data_screen.dart`
/// (`_ParameterTabState._valueRow`), behavior-preserving; aksi lewat callback.
class ParameterValueRow extends StatelessWidget {
  const ParameterValueRow({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final ParameterItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = item;
    final meta = [
      if (p.numericValue != null) 'rate ${p.numericValue}',
      if (!p.active) 'nonaktif',
    ].join(' • ');
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      title: Text(
        p.paramValue,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
          color: p.active ? null : AppColors.grayStage,
        ),
      ),
      subtitle: meta.isEmpty
          ? null
          : Text(
              meta,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
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
    );
  }
}
