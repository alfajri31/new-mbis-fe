import 'package:flutter/material.dart';

import '../../../src/master_data/master_data_repository.dart';
import '../../../theme/app_theme.dart';

/// Satu baris bank induk (nama + tipe + menu; tap membuka daftar cabang).
/// Murni presentational — diekstrak dari `kelola_master_data_screen.dart`
/// (`_BankTabState._row`), behavior-preserving; aksi lewat callback.
class BankRow extends StatelessWidget {
  const BankRow({
    super.key,
    required this.bank,
    required this.onOpenBranches,
    required this.onEdit,
    required this.onDelete,
    this.canEdit = true,
  });

  final BankItem bank;
  final VoidCallback onOpenBranches;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// False bila pemanggil boleh MELIHAT baris ini tapi tidak menyuntingnya —
  /// kurator DIV_SOE atas bank non-HIMBARA. Menu ubah/hapus disembunyikan dan
  /// baris diberi keterangan, alih-alih menyodorkan aksi yang pasti ditolak server.
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final b = bank;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        onTap: onOpenBranches,
        title: Text(
          b.name,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          [
            canEdit ? 'Kelola cabang' : 'Bukan HIMBARA — hanya bisa dilihat',
            if (b.tipeBank != null && b.tipeBank!.isNotEmpty) b.tipeBank!,
          ].join(' • '),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'branches') onOpenBranches();
            if (v == 'edit') onEdit();
            if (v == 'delete') onDelete();
          },
          itemBuilder: (_) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
                value: 'branches', child: Text('Kelola cabang')),
            if (canEdit)
              const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
            if (canEdit)
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Hapus', style: TextStyle(color: AppColors.errorRed)),
              ),
          ],
        ),
      ),
    );
  }
}
