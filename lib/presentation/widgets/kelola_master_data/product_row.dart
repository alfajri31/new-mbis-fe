import 'package:flutter/material.dart';

import '../../../src/master_data/master_data_repository.dart';
import '../../../src/product_knowledge/product_knowledge_models.dart'
    show pkCategoryIcon;
import '../../../theme/app_theme.dart';

/// Satu baris produk katalog (ikon kategori + nama + toggle aktif + menu).
/// Murni presentational — diekstrak dari `kelola_master_data_screen.dart`
/// (`_ProductTabState._row`), behavior-preserving. Kategori & warna dihitung
/// pemanggil; aksi (toggle/edit/hapus) lewat callback.
class ProductRow extends StatelessWidget {
  const ProductRow({
    super.key,
    required this.product,
    required this.category,
    required this.color,
    required this.onToggleActive,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductItem product;
  final ProductCategoryItem? category;
  final Color color;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final cat = category;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Opacity(
        opacity: p.active ? 1 : 0.6,
        child: ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.radiusMd,
            ),
            child: Icon(
              pkCategoryIcon(cat?.icon ?? 'shapes'),
              color: color,
              size: 22,
            ),
          ),
          title: Text(
            p.name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          subtitle: Text(
            cat?.name ?? p.lini,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch.adaptive(
                value: p.active,
                activeThumbColor: AppColors.successGreen,
                onChanged: (v) => onToggleActive(v),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Hapus',
                      style: TextStyle(color: AppColors.errorRed),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
