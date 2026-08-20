import 'package:flutter/material.dart';

import '../../../src/master_data/master_data_repository.dart';
import '../../../theme/app_theme.dart';

/// Satu baris cabang bank (nama + CIF/alamat + menu edit/hapus).
/// Murni presentational — diekstrak dari `kelola_master_data_screen.dart`
/// (`_BankBranchesScreenState._row`), behavior-preserving; aksi lewat callback.
class BankBranchRow extends StatelessWidget {
  const BankBranchRow({
    super.key,
    required this.branch,
    required this.onEdit,
    required this.onDelete,
    this.canEdit = true,
  });

  final BankBranchItem branch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// False bila induknya bukan bank HIMBARA sementara pemanggilnya kurator
  /// DIV_SOE — cabangnya boleh dilihat, tidak disunting.
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final b = branch;
    final sub = [
      if (b.cifNo != null && b.cifNo!.isNotEmpty) 'CIF ${b.cifNo}',
      if (b.address != null && b.address!.isNotEmpty) b.address!,
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
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: sub.isEmpty
            ? null
            : Text(
                sub,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
        trailing: canEdit
            ? PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child:
                        Text('Hapus', style: TextStyle(color: AppColors.errorRed)),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
