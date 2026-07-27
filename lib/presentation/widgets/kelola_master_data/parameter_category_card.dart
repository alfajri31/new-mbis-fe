import 'package:flutter/material.dart';

import '../../../src/master_data/master_data_repository.dart';
import '../../../theme/app_theme.dart';
import 'parameter_value_row.dart';

/// Kartu satu kategori parameter (ExpansionTile berisi nilai + tombol tambah).
/// Murni presentational — diekstrak dari `kelola_master_data_screen.dart`
/// (`_ParameterTabState._categoryCard`), behavior-preserving. Definisi kategori
/// (`label`, `code`, `isSystem`) dihitung pemanggil; aksi lewat callback.
class ParameterCategoryCard extends StatelessWidget {
  const ParameterCategoryCard({
    super.key,
    required this.label,
    required this.code,
    required this.isSystem,
    required this.values,
    required this.onAddValue,
    required this.onEditValue,
    required this.onDeleteValue,
  });

  final String label;
  final String code;
  final bool isSystem;
  final List<ParameterItem> values;
  final VoidCallback onAddValue;
  final ValueChanged<ParameterItem> onEditValue;
  final ValueChanged<ParameterItem> onDeleteValue;

  @override
  Widget build(BuildContext context) {
    final sorted = [...values]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isSystem)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.secondaryOrange,
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.bgScreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${values.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              code,
              style: const TextStyle(fontSize: 11, color: AppColors.grayStage),
            ),
          ),
          children: [
            if (isSystem)
              const Padding(
                padding: EdgeInsets.fromLTRB(6, 0, 6, 8),
                child: Text(
                  'Kategori sistem — terkait alur aplikasi. Ubah hanya bila paham dampaknya.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryOrange,
                  ),
                ),
              ),
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Belum ada nilai.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              for (final p in sorted)
                ParameterValueRow(
                  item: p,
                  onEdit: () => onEditValue(p),
                  onDelete: () => onDeleteValue(p),
                ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddValue,
                icon: const Icon(Icons.add, size: 18),
                label: Text('Tambah $label'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryNavy,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
