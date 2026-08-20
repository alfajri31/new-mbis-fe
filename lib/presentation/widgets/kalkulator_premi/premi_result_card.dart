import 'package:flutter/material.dart';

import '../../../data/premi_rates.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// Kartu "Hasil Perhitungan" pada Kalkulator Premi — murni presentational
/// (read-only), diekstrak dari `kalkulator_premi_screen.dart`
/// (behavior-preserving) agar layar lebih kecil. Semua nilai turunan dihitung
/// di layar dan diberikan lewat constructor.
class PremiResultCard extends StatelessWidget {
  const PremiResultCard({
    super.key,
    required this.category,
    required this.rate,
    required this.diskon,
    required this.currency,
    required this.tsiOriginal,
    required this.tsiIdr,
    required this.minPremiApplied,
    required this.premi,
    this.biayaAdmin = 0,
    num? totalTagihan,
  }) : totalTagihan = totalTagihan ?? premi + biayaAdmin;

  final PremiCategory category;
  final double? rate;
  final num diskon;
  final String currency;
  final num tsiOriginal;
  final num tsiIdr;
  final bool minPremiApplied;
  final num premi;

  /// Biaya admin nominal di luar premi (CR-21). 0 = kartu tampil persis seperti
  /// sebelum CR-21, tanpa baris tambahan.
  final num biayaAdmin;

  /// Yang ditagihkan: [premi] + [biayaAdmin].
  final num totalTagihan;

  @override
  Widget build(BuildContext context) {
    final showDiscount = category.allowsDiscount && diskon > 0;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.calculate_outlined,
                  size: 17,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Hasil Perhitungan',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _infoRow('Kategori', category.label),
          if (currency != 'IDR')
            _infoRow(
              'TSI',
              '$currency ${AppFormat.thousands(tsiOriginal.round())}',
            ),
          _infoRow('TSI (IDR)', AppFormat.rupiah(tsiIdr)),
          _infoRow('Rate', rate == null ? '—' : '${_trimRate(rate!)}%'),
          if (showDiscount) _infoRow('Diskon', '${diskon.toStringAsFixed(0)}%'),
          if (minPremiApplied)
            _infoRow('Minimum estimasi premi', AppFormat.rupiah(kBondMinPremi)),
          // Rincian CR-21: premi dan biaya admin disebut terpisah supaya terlihat
          // dari mana angka totalnya datang. Tanpa biaya admin, kartu ini tampil
          // persis seperti sebelumnya — satu baris "Estimasi Premi" saja.
          if (biayaAdmin > 0) ...[
            _infoRow('Estimasi Premi', AppFormat.rupiah(premi)),
            _infoRow('Biaya Admin', AppFormat.rupiah(biayaAdmin)),
          ],
          const Divider(height: 1, thickness: 1, color: AppColors.border),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  biayaAdmin > 0 ? 'Total' : 'Estimasi Premi',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
                Text(
                  AppFormat.rupiah(totalTagihan),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Trims trailing zeros from a rate percent for display (0.0480 → "0.048").
  String _trimRate(double rate) => _trimNum(rate, places: 4);

  String _trimNum(num value, {int places = 2}) {
    var s = value.toStringAsFixed(places);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }
}
