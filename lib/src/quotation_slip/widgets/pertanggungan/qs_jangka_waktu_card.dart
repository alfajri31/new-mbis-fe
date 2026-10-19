import 'package:flutter/material.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';
import 'qs_pertanggungan_fields.dart';

/// Card Section 4: Jangka Waktu Pertanggungan
class QsJangkaWaktuCard extends StatelessWidget {
  final DateTime? tglMulai;
  final ValueChanged<DateTime?> onTglMulaiChanged;
  final DateTime? tglAkhir;
  final ValueChanged<DateTime?> onTglAkhirChanged;
  final int jumlahHari;
  final bool isEndBad;

  const QsJangkaWaktuCard({
    super.key,
    required this.tglMulai,
    required this.onTglMulaiChanged,
    required this.tglAkhir,
    required this.onTglAkhirChanged,
    required this.jumlahHari,
    required this.isEndBad,
  });

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: Icons.calendar_today_outlined,
      title: 'Jangka Waktu Pertanggungan',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: QsDatePickerField(
                label: 'Mulai',
                required: true,
                value: tglMulai,
                onChanged: (d) {
                  onTglMulaiChanged(d);
                  if (d != null && tglAkhir == null) {
                    final nextYear = DateTime(d.year + 1, d.month, d.day);
                    onTglAkhirChanged(nextYear);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: QsDatePickerField(
                label: 'Sampai dengan',
                required: true,
                value: tglAkhir,
                onChanged: onTglAkhirChanged,
              ),
            ),
          ],
        ),
        if (isEndBad) ...[
          const SizedBox(height: 6),
          const Text(
            'Tanggal akhir harus setelah tanggal mulai.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.redRequired,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              jumlahHari > 0
                  ? 'Masa Pertanggungan: $jumlahHari hari'
                  : 'Pilih tanggal mulai, akhir otomatis +1 tahun',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            OutlinedButton(
              onPressed: tglMulai == null
                  ? null
                  : () {
                      final m = tglMulai!;
                      final nextYear = DateTime(m.year + 1, m.month, m.day);
                      onTglAkhirChanged(nextYear);
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(
                    color: AppColors.borderDefault, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                minimumSize: const Size(0, 34),
              ),
              child: const Text(
                'Set 1 tahun',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyMbis,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Kedua tanggal berlaku pukul 12.00 siang waktu setempat di mana orang yang dipertanggungkan berada.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
