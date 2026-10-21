import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common/label_input_row.dart';
import '../../../../theme/app_theme.dart';
import '../../qs_form_state.dart';

/// Card Section 2 PSAKDI: Jenis Risiko (A vs A/B, C, dan UP masing-masing) - Prototype 1:1
class PsakdiJenisRisikoCard extends StatelessWidget {
  final int? klasifikasiPeserta;
  final TextEditingController upACtrl;
  final PsakdiRiskType riskType;
  final ValueChanged<PsakdiRiskType> onRiskTypeChanged;
  final bool risikoC;
  final ValueChanged<bool> onRisikoCChanged;
  final TextEditingController upCCtrl;
  final double stdRateA;
  final double stdRateAB;
  final double stdRateC;
  final double batasC;
  final VoidCallback? onFieldChanged;

  const PsakdiJenisRisikoCard({
    super.key,
    required this.klasifikasiPeserta,
    required this.upACtrl,
    required this.riskType,
    required this.onRiskTypeChanged,
    required this.risikoC,
    required this.onRisikoCChanged,
    required this.upCCtrl,
    required this.stdRateA,
    required this.stdRateAB,
    required this.stdRateC,
    required this.batasC,
    this.onFieldChanged,
  });

  double _parseNum(String text) {
    final clean = text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(clean) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat('#,##0', 'id');
    final upVal = _parseNum(upACtrl.text);
    final upOver = upVal > 1000000000;
    final cVal = _parseNum(upCCtrl.text);
    final cOver = risikoC && cVal > batasC;

    final rateAText =
        klasifikasiPeserta != null ? '${stdRateA.toStringAsFixed(2)}%' : '–';
    final rateABText =
        klasifikasiPeserta != null ? '${stdRateAB.toStringAsFixed(2)}%' : '–';
    final rateCText =
        klasifikasiPeserta != null ? '${stdRateC.toStringAsFixed(2)}%' : '–';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Underlined Title & Kelas Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Jenis Risiko',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  decoration: TextDecoration.underline,
                  decorationThickness: 1.5,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.blueLightBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  klasifikasiPeserta != null
                      ? 'Kelas $klasifikasiPeserta'
                      : 'Kelas belum dipilih',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyMbis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Input Uang Pertanggungan (Meninggal Dunia)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LabelInputRow(
                label: 'Uang Pertanggungan (Meninggal Dunia)',
                controller: upACtrl,
                isNumeric: true,
                isCurrency: true,
                hasError: upOver,
              ),
              if (upOver)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Melebihi batas maks. Rp 1.000.000.000',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.redRequired,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Subtitle "Pilih salah satu:"
          const Text(
            'Pilih salah satu:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textLabel,
            ),
          ),
          const SizedBox(height: 8),

          // 4. Radio A & A/B Options
          _buildRadioOption(
            letter: 'A',
            title: 'Meninggal Dunia yang disebabkan karena kecelakaan (only)',
            rateText: rateAText,
            isSelected: riskType == PsakdiRiskType.a,
            onTap: () {
              if (riskType != PsakdiRiskType.a) {
                onRiskTypeChanged(PsakdiRiskType.a);
                if (risikoC) {
                  onRisikoCChanged(false);
                  upCCtrl.clear();
                }
                onFieldChanged?.call();
              }
            },
          ),
          const SizedBox(height: 8),
          _buildRadioOption(
            letter: 'A/B',
            title:
                'Meninggal Dunia / Cacat Tetap yang disebabkan karena kecelakaan',
            rateText: rateABText,
            isSelected: riskType == PsakdiRiskType.ab,
            onTap: () {
              if (riskType != PsakdiRiskType.ab) {
                onRiskTypeChanged(PsakdiRiskType.ab);
                onFieldChanged?.call();
              }
            },
          ),
          const SizedBox(height: 12),

          // 5. Subtitle "Tambahan:"
          const Text(
            'Tambahan:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textLabel,
            ),
          ),
          const SizedBox(height: 6),

          // 6. Checkbox Option C
          _buildCheckboxCOption(context, rateCText),

          // 7. Input Biaya Perawatan / Pengobatan when C is checked & active
          if (risikoC && riskType == PsakdiRiskType.ab) ...[
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabelInputRow(
                  label: 'Biaya Perawatan / Pengobatan',
                  controller: upCCtrl,
                  isNumeric: true,
                  isCurrency: true,
                  hasError: cOver,
                ),
                if (cOver)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Melebihi batas maks. Rp ${currFmt.format(batasC)} (10% UP, maks. Rp 10.000.000)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.redRequired,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // 8. Info Note
          const Text.rich(
            TextSpan(
              text: 'A dan A/B tidak bisa dipilih bersamaan. ',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.4,
              ),
              children: [
                TextSpan(
                  text: 'A tidak bisa digabung dengan C',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text:
                      ' (C hanya bersama A/B). Maks. C: 10% UP atau Rp 10.000.000.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioOption({
    required String letter,
    required String title,
    required String rateText,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.bgSelectedCard : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.navyMbis : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.navyMbis
                      : AppColors.borderInactive,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.navyMbis,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    letter,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.navyMbis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textDark,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                rateText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyMbis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxCOption(BuildContext context, String rateText) {
    final isDisabled = riskType == PsakdiRiskType.a;
    final isChecked = risikoC && !isDisabled;

    final cardBg = isDisabled
        ? AppColors.bgDisabledCard
        : (isChecked ? AppColors.bgSelectedCard : AppColors.surfaceWhite);
    final cardBd = isDisabled
        ? AppColors.borderDivider
        : (isChecked ? AppColors.navyMbis : AppColors.borderDefault);

    final boxBg = isDisabled
        ? AppColors.bgDisabled
        : (isChecked ? AppColors.navyMbis : AppColors.surfaceWhite);
    final boxBd = isDisabled
        ? AppColors.borderDefault
        : (isChecked ? AppColors.navyMbis : AppColors.borderInactive);

    final pgTextColor =
        isDisabled ? AppColors.textDisabled : AppColors.textDark;

    return InkWell(
      onTap: () {
        if (isDisabled) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'C tidak bisa digabung dengan A. Pilih A/B untuk menambahkan C.',
              ),
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }
        final nextVal = !risikoC;
        onRisikoCChanged(nextVal);
        if (!nextVal) {
          upCCtrl.clear();
        }
        onFieldChanged?.call();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBd, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    color: boxBg,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: boxBd, width: 1.5),
                  ),
                  child: isChecked
                      ? const Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.surfaceWhite,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'C',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isDisabled
                              ? AppColors.textDisabled
                              : AppColors.navyMbis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Biaya Perawatan / Pengobatan',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: pgTextColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    rateText,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navyMbis,
                    ),
                  ),
                ),
              ],
            ),
            if (isDisabled)
              const Padding(
                padding: EdgeInsets.only(left: 34, top: 6),
                child: Text(
                  'C tidak bisa digabung dengan A. Pilih A/B untuk menambahkan C.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.alertTitle,
                    height: 1.4,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
