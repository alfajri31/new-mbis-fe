import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';

/// Card Dokumen Pendukung (Upload KTP Pemegang Polis / PIC) - Prototype 1:1
class QsTcDokumenPendukungCard extends StatelessWidget {
  final String? labelKtp;
  final String? activeFileName;
  final int? activeFileSize;
  final Uint8List? activeFileBytes;
  final String? activeFilePath;
  final VoidCallback onUploadDocument;
  final VoidCallback? onHapusDocument;

  const QsTcDokumenPendukungCard({
    super.key,
    this.labelKtp,
    required this.activeFileName,
    this.activeFileSize,
    this.activeFileBytes,
    this.activeFilePath,
    required this.onUploadDocument,
    this.onHapusDocument,
  });

  String _formatFileSize(int bytes) {
    if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    }
    final kb = (bytes / 1024).round();
    return '${kb < 1 ? 1 : kb} KB';
  }

  bool get _isImage {
    if (activeFileName == null) return false;
    final lower = activeFileName!.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp');
  }

  Widget _buildThumbnail() {
    if (activeFileBytes != null) {
      return Image.memory(
        activeFileBytes!,
        width: 56,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => _buildPlaceholderIcon(),
      );
    }
    if (!kIsWeb && activeFilePath != null && activeFilePath!.isNotEmpty) {
      return Image.file(
        File(activeFilePath!),
        width: 56,
        height: 38,
        fit: BoxFit.cover,
        errorBuilder: (_, error, stackTrace) => _buildPlaceholderIcon(),
      );
    }
    return _buildPlaceholderIcon();
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      width: 56,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.blueLightBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Icon(
        _isImage ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
        size: 20,
        color: AppColors.navyMbis,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: Icons.description_outlined,
      title: 'Dokumen Pendukung (opsional)',
      subtitle: 'Untuk penerbitan polis dan/atau persetujuan UW. Tidak wajib.',
      children: [
        // Label KTP
        Text(
          labelKtp ?? 'KTP Pemegang Polis / PIC',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 8),

        // Keadaan sudah upload (hasKtp)
        if (activeFileName != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgUploadSuccess,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderUploadSuccess),
            ),
            child: Row(
              children: [
                // Pratinjau Thumbnail Gambar / File
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 56,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.borderDivider),
                      color: AppColors.surfaceWhite,
                    ),
                    child: _buildThumbnail(),
                  ),
                ),
                const SizedBox(width: 10),

                // Info Nama File & Ukuran
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '✓ $activeFileName',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activeFileSize != null
                            ? _formatFileSize(activeFileSize!)
                            : '',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Tombol Hapus
                InkWell(
                  onTap: onHapusDocument,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Text(
                      'Hapus',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.redRequired,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          // Keadaan belum upload (noKtp): Dashed border compact 46px
          InkWell(
            onTap: onUploadDocument,
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              painter: DashedRectPainter(
                color: AppColors.borderUploadDashed,
                strokeWidth: 1.5,
                gap: 5.0,
              ),
              child: Container(
                height: 46,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.bgUploadBox,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.file_upload_outlined,
                      size: 18,
                      color: AppColors.navyMbis,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Unggah KTP (JPG/PNG/PDF, maks. 5 MB)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyMbis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
