import 'package:flutter/material.dart';

import '../../../src/master_data/master_data_repository.dart';
import '../../../theme/app_theme.dart';

/// Satu baris broker mitra (nama + kode + menu edit/hapus).
/// Murni presentational — diekstrak dari `kelola_master_data_screen.dart`
/// (`_BrokerTabState._row`), behavior-preserving; aksi lewat callback.
class BrokerRow extends StatelessWidget {
  const BrokerRow({
    super.key,
    required this.broker,
    required this.onEdit,
    required this.onDelete,
  });

  final BrokerItem broker;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final b = broker;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: ListTile(
        title: Text(
          b.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          b.brokerCode,
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
