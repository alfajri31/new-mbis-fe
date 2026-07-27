import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Slot dokumen kosong (garis putus-putus + tombol upload) untuk tipe dokumen
/// yang belum diunggah. Aksi tap (pilih & unggah file) dikirim lewat [onTap].
/// Murni presentational — diekstrak dari `customer_detail_screen.dart`
/// (behavior-preserving).
class CustomerEmptyDocSlot extends StatelessWidget {
  const CustomerEmptyDocSlot({
    super.key,
    required this.docType,
    required this.onTap,
  });

  final String docType;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: DashedRectPainter(
            color: AppColors.grayStage,
            strokeWidth: 1.5,
            gap: 4.0,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.bgScreen,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.upload_file_outlined,
                  color: AppColors.grayStage,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        docType,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Belum diunggah — ketuk untuk upload',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'Upload',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
