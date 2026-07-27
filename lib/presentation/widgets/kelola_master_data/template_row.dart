import 'package:flutter/material.dart';

import '../../../src/agent/agent_repository.dart';
import '../../../theme/app_theme.dart';

/// Satu baris template onboarding: nama, kode, status unggah, tombol unggah/ganti,
/// dan menu ubah/hapus. Murni presentational — semua aksi dikontrol pemanggil.
///
/// [onEdit]/[onDelete] opsional supaya baris ini tetap bisa dipakai di layar
/// yang hanya menampilkan (mis. daftar unduhan untuk RM), bukan mengelola.
class TemplateRow extends StatelessWidget {
  const TemplateRow({
    super.key,
    required this.item,
    required this.busy,
    required this.onUpload,
    this.onEdit,
    this.onDelete,
  });

  final AgentTemplateItem item;
  final bool busy;
  final VoidCallback onUpload;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = item;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    // Ikon status lebih cepat dibaca daripada teks warna saja.
                    Icon(
                      t.available ? Icons.check_circle : Icons.upload_file,
                      size: 12,
                      color: t.available ? AppColors.successGreen : AppColors.grayStage,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        t.available
                            ? (t.fileName.isEmpty ? 'Terunggah' : t.fileName)
                            : 'Belum ada berkas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: t.available
                              ? AppColors.successGreen
                              : AppColors.grayStage,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  t.code,
                  style: const TextStyle(fontSize: 10, color: AppColors.grayStage),
                ),
              ],
            ),
          ),
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            TextButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_file, size: 18),
              label: Text(t.available ? 'Ganti' : 'Unggah'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryNavy),
            ),
            if (onEdit != null || onDelete != null)
              PopupMenuButton<String>(
                tooltip: 'Aksi lain',
                icon: const Icon(Icons.more_vert, size: 20, color: AppColors.grayStage),
                onSelected: (v) {
                  if (v == 'edit') onEdit?.call();
                  if (v == 'delete') onDelete?.call();
                },
                itemBuilder: (_) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(Icons.edit_outlined, size: 18),
                        title: Text('Ubah nama / urutan'),
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(Icons.delete_outline,
                            size: 18, color: AppColors.errorRed),
                        title: Text('Hapus template',
                            style: TextStyle(color: AppColors.errorRed)),
                      ),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
