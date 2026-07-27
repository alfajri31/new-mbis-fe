import 'package:flutter/material.dart';

import '../../../src/master_data/master_data_repository.dart';
import '../../../src/product_knowledge/product_knowledge_models.dart'
    show pkCategoryIcon;
import '../../../theme/app_theme.dart';

/// Satu baris kategori produk (ikon berwarna + nama + urutan + menu).
/// Murni presentational — diekstrak dari `kelola_master_data_screen.dart`
/// (`_CategoryTabState._row`), behavior-preserving. Warna dihitung pemanggil;
/// aksi lewat callback.
class CategoryRow extends StatelessWidget {
  const CategoryRow({
    super.key,
    required this.item,
    required this.color,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductCategoryItem item;
  final Color color;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = item;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppRadius.radiusMd,
          ),
          child: Icon(
            pkCategoryIcon(c.icon ?? 'shapes'),
            color: color,
            size: 22,
          ),
        ),
        title: Text(
          c.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '${c.id} • urutan ${c.sortOrder}',
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
