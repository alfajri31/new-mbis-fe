import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../theme/app_theme.dart';

/// Card Rincian Biaya Asuransi untuk PA Xtra (hasil kalkulasi real-time)
class PaXtraRincianBiayaCard extends StatelessWidget {
  final String lblPokok;
  final double premiPokok;
  final bool showTambahan;
  final String lblTambahan;
  final double premiTambahan;
  final double gross;
  final double diskonAmt;
  final String diskonPercentStr;
  final double netto;
  final int biayaAdmin;
  final double total;

  const PaXtraRincianBiayaCard({
    super.key,
    required this.lblPokok,
    required this.premiPokok,
    this.showTambahan = false,
    this.lblTambahan = '',
    this.premiTambahan = 0,
    required this.gross,
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
          // Header: Rincian Biaya Asuransi · dihitung otomatis
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Rincian Biaya Asuransi ',
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

          // Premi Jaminan Pokok
          _buildRow(lblPokok, 'Rp ${currFmt.format(premiPokok)}'),

          // Premi Jaminan Tambahan (jika aktif)
          if (showTambahan) ...[
            const SizedBox(height: 10),
            _buildRow(lblTambahan, 'Rp ${currFmt.format(premiTambahan)}'),
          ],

          // Gross Premi
          const SizedBox(height: 10),
          _buildRow(
            'Gross Premi',
            'Rp ${currFmt.format(gross)}',
          ),

          // Discount
          const SizedBox(height: 10),
          _buildRow(
            'Discount ($diskonPercentStr%)',
            '– Rp ${currFmt.format(diskonAmt)}',
            valueColor: AppColors.redRequired,
          ),

          // Nett Premi
          const SizedBox(height: 10),
          _buildRow(
            'Nett Premi',
            'Rp ${currFmt.format(netto)}',
          ),

          // Adm Cost
          const SizedBox(height: 10),
          _buildRow(
            'Adm Cost',
            'Rp ${currFmt.format(biayaAdmin)}',
          ),

          // Divider
          const SizedBox(height: 10),
          Container(
            height: 1,
            color: AppColors.borderDivider,
          ),
          const SizedBox(height: 10),

          // Total Biaya Asuransi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Biaya Asuransi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              Text(
                'Rp ${currFmt.format(total)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.greenTotal,
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
              fontWeight: FontWeight.w400,
              color: AppColors.textMuted,
              height: 1.4,
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
