import 'package:flutter/material.dart';

import '../../../src/master_data/master_data_repository.dart';
import '../../../theme/app_theme.dart';

/// Office type code → Indonesian label.
String _officeTypeLabel(String type) => switch (type) {
  'REGIONAL' => 'Kanwil',
  'BRANCH' => 'Cabang',
  'KUP' => 'KUP/Connect',
  _ => type,
};

/// Satu baris kantor (ikon per tipe + nama + kode/induk + menu).
/// Murni presentational — diekstrak dari `kelola_master_data_screen.dart`
/// (`_OfficeTabState._row`), behavior-preserving; aksi lewat callback.
class OfficeRow extends StatelessWidget {
  const OfficeRow({
    super.key,
    required this.office,
    required this.onEdit,
    required this.onDelete,
  });

  final OfficeAdminItem office;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final o = office;
    final sub = [
      o.id,
      _officeTypeLabel(o.type),
      if (o.parentName != null && o.parentName!.isNotEmpty)
        'Induk: ${o.parentName}'
      else if (o.type != 'REGIONAL')
        'Tanpa induk',
      if (!o.active) 'nonaktif',
    ].join(' • ');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Icon(
          o.type == 'REGIONAL'
              ? Icons.account_balance_outlined
              : o.type == 'BRANCH'
              ? Icons.business_outlined
              : Icons.store_mall_directory_outlined,
          color: o.active ? AppColors.primaryNavy : AppColors.grayStage,
        ),
        title: Text(
          o.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: o.active ? null : AppColors.grayStage,
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
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (o.active)
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Nonaktifkan',
                  style: TextStyle(color: AppColors.errorRed),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
