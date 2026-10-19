import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../qs_form_state.dart';

/// Card Section 6: Accordion Ketentuan Standar (read-only)
class QsKetentuanStandarCard extends StatelessWidget {
  final QsProduct product;
  final bool showStd;
  final VoidCallback onToggleShowStd;

  const QsKetentuanStandarCard({
    super.key,
    required this.product,
    required this.showStd,
    required this.onToggleShowStd,
  });

  @override
  Widget build(BuildContext context) {
    final prodWording = product == QsProduct.psakdi
        ? 'Polis Standar Asuransi Kecelakaan Diri Indonesia'
        : 'Personal Accident Xtra Insurance';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggleShowStd,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                const Icon(Icons.lock_outline,
                    size: 18, color: AppColors.textMuted),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ketentuan standar (tidak dapat diubah)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Text(
                  showStd ? 'Tutup' : 'Lihat',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyMbis,
                  ),
                ),
              ],
            ),
          ),
          if (showStd) ...[
            const SizedBox(height: 12),
            Column(
              children: [
                _buildStdDashedItem(
                  title: 'JENIS PERTANGGUNGAN',
                  desc: 'Asuransi Kecelakaan Diri',
                ),
                const SizedBox(height: 10),
                _buildStdDashedItem(
                  title: 'WORDING',
                  desc: prodWording,
                ),
                const SizedBox(height: 10),
                _buildStdDashedItem(
                  title: 'RISIKO SENDIRI',
                  desc: 'Nil',
                ),
                const SizedBox(height: 10),
                _buildStdDashedItem(
                  title: 'KLAUSULA, KONDISI & WARANTI',
                  desc: 'Terlampir',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStdDashedItem({
    required String title,
    required String desc,
  }) {
    return CustomPaint(
      painter: DashedRectPainter(
        color: AppColors.borderDashed,
        strokeWidth: 1.0,
        gap: 5.0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgLightGray,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child:
                  Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
