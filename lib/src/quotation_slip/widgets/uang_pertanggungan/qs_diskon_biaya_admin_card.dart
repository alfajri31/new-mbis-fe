import 'package:flutter/material.dart';

import '../common/input_with_suffix.dart';
import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';
import '../../qs_form_state.dart';

/// Card Diskon & Biaya Admin (Asuransi vs e-Polis MBIS)
class QsDiskonBiayaAdminCard extends StatelessWidget {
  final String title;
  final TextEditingController diskonCtrl;
  final double diskonPersen;
  final QsPolisType polisType;
  final ValueChanged<QsPolisType> onPolisTypeChanged;
  final VoidCallback? onFieldChanged;

  const QsDiskonBiayaAdminCard({
    super.key,
    required this.title,
    required this.diskonCtrl,
    required this.diskonPersen,
    required this.polisType,
    required this.onPolisTypeChanged,
    this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    const discOptions = [
      (0.0, 'Tanpa diskon'),
      (10.0, '10%'),
      (15.0, '15%'),
      (20.0, '20%'),
    ];

    final isEPolis = polisType == QsPolisType.ePolis;
    final admDetail = isEPolis
        ? 'e-Polis: Materai Rp 10.000 (tanpa Biaya Polis)'
        : 'Biaya Polis Rp 20.000 + Materai Rp 10.000';
    final admAmount = isEPolis ? 'Rp 10.000' : 'Rp 30.000';
    final discOver = diskonPersen > 20.0;
    final isDiscEmpty = diskonCtrl.text.trim().isEmpty;

    return QsSectionCard(
      icon: Icons.monetization_on_outlined,
      title: title,
      children: [
        const Text(
          'Diskon',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 6),
        InputWithSuffix(
          controller: diskonCtrl,
          suffixText: '%',
          hasError: isDiscEmpty || discOver,
        ),
        const SizedBox(height: 10),
        Wrap(
          direction: Axis.horizontal,
          alignment: WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          children: discOptions.map((opt) {
            final isSelected = (diskonPersen - opt.$1).abs() < 0.001;
            return InkWell(
              onTap: () {
                diskonCtrl.text = opt.$1.toStringAsFixed(0);
                onFieldChanged?.call();
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.blueLightBg : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.navyMbis
                        : AppColors.borderDefault,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      opt.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.navyMbis
                            : AppColors.textLabel,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        const Text(
          'Jenis Polis',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDefault, width: 1.5),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<QsPolisType>(
              value: polisType,
              isExpanded: true,
              dropdownColor: Colors.white,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.iconDropdown),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.blueInputText,
              ),
              items: const [
                DropdownMenuItem(
                  value: QsPolisType.cetak,
                  child: Text('Cetak Biasa'),
                ),
                DropdownMenuItem(
                  value: QsPolisType.ePolis,
                  child: Text('e-Polis (hanya Materai Rp 10.000)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  onPolisTypeChanged(val);
                  onFieldChanged?.call();
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgLightGray,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  admDetail,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                admAmount,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyMbis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'e-Polis: hanya dikenakan Materai (tanpa Biaya Polis). Cetak biasa: Biaya Polis + Materai. Nominal mengikuti ketentuan UW.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.alertTitle,
            height: 1.4,
          ),
        ),
        if (discOver) ...[
          const SizedBox(height: 6),
          const Text(
            'Maksimal diskon 20% (include VAT)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.redRequired,
            ),
          ),
        ],
        const SizedBox(height: 6),
        const Text(
          'Diskon maks. 20% (include VAT). Biaya admin mengikuti Jenis Polis.',
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
