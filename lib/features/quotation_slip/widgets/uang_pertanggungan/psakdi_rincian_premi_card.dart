import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../theme/app_theme.dart';

/// Card Rincian Premi Otomatis untuk PSAKDI (hasil kalkulasi real-time) - Prototype 1:1
class PsakdiRincianPremiCard extends StatelessWidget {
  final bool isCalculated;
  final String noPremiTxt;
  final String? noPremiShort;
  final String lblPokok;
  final double premiPokok;
  final bool showTambahan;
  final String lblTambahan;
  final double premiTambahan;
  final bool showGross;
  final double gross;
  final double diskonAmt;
  final String diskonPercentStr;
  final double netto;
  final int biayaAdmin;
  final double total;

  const PsakdiRincianPremiCard({
    super.key,
    required this.isCalculated,
    required this.noPremiTxt,
    this.noPremiShort,
    required this.lblPokok,
    required this.premiPokok,
    this.showTambahan = false,
    this.lblTambahan = '',
    this.premiTambahan = 0,
    this.showGross = false,
    this.gross = 0,
    required this.diskonAmt,
    required this.diskonPercentStr,
    required this.netto,
    required this.biayaAdmin,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat('#,##0', 'id');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navyMbis, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Rincian Premi · dihitung otomatis
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Rincian Premi ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                TextSpan(
                  text: '· dihitung otomatis',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greenTotal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Row 1: Premi Pokok
          _buildRow(lblPokok, 'Rp ${currFmt.format(premiPokok)}'),

          // Row 2: Premi Tambahan (jika aktif)
          if (showTambahan) ...[
            const SizedBox(height: 10),
            _buildRow(lblTambahan, 'Rp ${currFmt.format(premiTambahan)}'),
          ],

          // Row 3: Diskon
          const SizedBox(height: 10),
          _buildRow(
            'Diskon ($diskonPercentStr%)',
            '– Rp ${currFmt.format(diskonAmt)}',
            valueColor: AppColors.redRequired,
          ),

          // Row 4: Premi Netto
          const SizedBox(height: 10),
          _buildRow(
            'Premi Netto',
            'Rp ${currFmt.format(netto)}',
          ),

          // Row 5: Biaya Admin
          const SizedBox(height: 10),
          _buildRow(
            'Biaya Admin',
            'Rp ${currFmt.format(biayaAdmin)}',
          ),

          // Divider
          const SizedBox(height: 10),
          Container(
            height: 1,
            color: AppColors.borderDivider,
          ),
          const SizedBox(height: 10),

          // Alert banner jika premi belum terbentuk (noPremi)
          if (!isCalculated) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.alertBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.alertBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 18,
                    color: AppColors.orangeDark,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      noPremiTxt,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.alertText,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Row Total Premi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Total Premi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                isCalculated
                    ? 'Rp ${currFmt.format(total)}'
                    : (noPremiShort ?? 'Belum terbentuk'),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isCalculated
                      ? AppColors.greenTotal
                      : AppColors.orangeDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: valueColor ?? AppColors.textDark,
          ),
        ),
      ],
    );
  }
}
