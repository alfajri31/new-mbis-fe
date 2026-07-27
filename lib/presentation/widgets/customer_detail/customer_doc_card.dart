import 'package:flutter/material.dart';

import '../../../src/customer/customer_repository.dart';
import '../../../src/network/api_client.dart';
import '../../../src/network/auth_image.dart';
import '../../../theme/app_theme.dart';

/// Kartu satu dokumen customer (thumbnail/ikon + tipe + nama file + menu
/// lihat/ganti/hapus). Thumbnail memakai [apiClient] untuk gambar terproteksi;
/// aksi dikirim lewat [onView]/[onReplace]/[onDelete]. Murni presentational —
/// diekstrak dari `customer_detail_screen.dart` (behavior-preserving).
class CustomerDocCard extends StatelessWidget {
  const CustomerDocCard({
    super.key,
    required this.doc,
    required this.apiClient,
    required this.onView,
    required this.onReplace,
    required this.onDelete,
  });

  final CustomerDocumentModel doc;
  final ApiClient apiClient;
  final VoidCallback onView;
  final VoidCallback onReplace;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusLg,
        child: InkWell(
          borderRadius: AppRadius.radiusLg,
          onTap: onView,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail (images) or file-type icon
                ClipRRect(
                  borderRadius: AppRadius.radiusMd,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: doc.isImage
                        ? AuthImage(
                            apiClient: apiClient,
                            path: doc.fileUrl,
                            width: 52,
                            height: 52,
                          )
                        : Container(
                            color: AppColors.redLight,
                            child: const Icon(
                              Icons.picture_as_pdf,
                              color: AppColors.errorRed,
                              size: 26,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.docType,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        doc.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textSecondary,
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'view':
                        onView();
                        break;
                      case 'replace':
                        onReplace();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 18,
                            color: AppColors.primaryNavy,
                          ),
                          SizedBox(width: 10),
                          Text('Lihat'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'replace',
                      child: Row(
                        children: [
                          Icon(
                            Icons.swap_horiz,
                            size: 18,
                            color: AppColors.primaryNavy,
                          ),
                          SizedBox(width: 10),
                          Text('Ganti file'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: AppColors.errorRed,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Hapus',
                            style: TextStyle(color: AppColors.errorRed),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
