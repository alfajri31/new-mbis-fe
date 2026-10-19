import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../common/label_input_row.dart';
import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';
import '../../qs_form_state.dart';

/// Item definisi santunan tambahan PA Xtra
class SantunanDef {
  final String key;
  final String label;
  final double cap;
  final double defaultRate;

  const SantunanDef({
    required this.key,
    required this.label,
    required this.cap,
    required this.defaultRate,
  });
}

const List<SantunanDef> kPaxSantunanList = [
  SantunanDef(
    key: 'ambulan',
    label: 'Ambulan & Evakuasi',
    cap: 2000000,
    defaultRate: 2.00,
  ),
  SantunanDef(
    key: 'pemakaman',
    label: 'Pemakaman / Kremasi',
    cap: 2000000,
    defaultRate: 0.10,
  ),
  SantunanDef(
    key: 'barang',
    label: 'Kehilangan Barang Pribadi',
    cap: 500000,
    defaultRate: 2.00,
  ),
  SantunanDef(
    key: 'dokumen',
    label: 'Pengurusan Dokumen',
    cap: 500000,
    defaultRate: 2.00,
  ),
  SantunanDef(
    key: 'pendidikan',
    label: 'Biaya Pendidikan',
    cap: 5000000,
    defaultRate: 0.10,
  ),
  SantunanDef(
    key: 'pemulangan',
    label: 'Biaya Pemulangan Jenazah / Repatriasi',
    cap: 5000000,
    defaultRate: 0.10,
  ),
];

/// Horizontal dashed divider
class DashedHorizontalDivider extends StatelessWidget {
  final double height;
  final Color color;
  final double dashWidth;
  final double dashSpace;

  const DashedHorizontalDivider({
    super.key,
    this.height = 1.0,
    this.color = AppColors.borderDivider,
    this.dashWidth = 4.0,
    this.dashSpace = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        final dashCount = (boxWidth / (dashWidth + dashSpace)).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: height,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Card Jaminan Tambahan & Perluasan PA Xtra (StatelessWidget)
class PaXtraJaminanTambahanCard extends StatelessWidget {
  final double upVal;
  final double batasC;
  final bool cacatTetap;
  final ValueChanged<bool> onCacatTetapChanged;
  final bool perawatanPengobatan;
  final ValueChanged<bool> onPerawatanChanged;
  final TextEditingController Function(String key) getSantunanCtrl;
  final VoidCallback? onFieldChanged;

  const PaXtraJaminanTambahanCard({
    super.key,
    required this.upVal,
    required this.batasC,
    required this.cacatTetap,
    required this.onCacatTetapChanged,
    required this.perawatanPengobatan,
    required this.onPerawatanChanged,
    required this.getSantunanCtrl,
    this.onFieldChanged,
  });

  double _parseNum(String s) =>
      double.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final currFmt = NumberFormat('#,##0', 'id');
    final hasNoUp = upVal <= 0;
    final ctrlC = getSantunanCtrl('pengobatan');
    final cVal = _parseNum(ctrlC.text);
    final cOver = perawatanPengobatan && cacatTetap && cVal > batasC;

    return QsSectionCard(
      title: 'Jaminan Tambahan',
      children: [
        // Row Cacat Tetap
        Row(
          children: [
            InkWell(
              onTap: () {
                final nextVal = !cacatTetap;
                onCacatTetapChanged(nextVal);
                if (!nextVal && perawatanPengobatan) {
                  onPerawatanChanged(false);
                  getSantunanCtrl('pengobatan').clear();
                }
                onFieldChanged?.call();
              },
              borderRadius: BorderRadius.circular(7),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: cacatTetap ? AppColors.navyMbis : Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: cacatTetap
                        ? AppColors.navyMbis
                        : AppColors.borderInactive,
                    width: 1.5,
                  ),
                ),
                child: cacatTetap
                    ? const Icon(Icons.check,
                        size: 14, color: AppColors.surfaceWhite)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              flex: 10,
              child: Text(
                'Termasuk Risiko Cacat Tetap',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textDark,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 10,
              child: Text(':', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 11,
              child: Text(
                cacatTetap ? '100% UP Meninggal Dunia' : 'Tidak dijamin',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: cacatTetap
                      ? AppColors.blueInputText
                      : AppColors.textDisabled,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Card Perawatan & Pengobatan
        _buildPaXtraPerawatanBox(ctrlC, currFmt),
        // Input Biaya Perawatan / Pengobatan jika aktif
        if (perawatanPengobatan && cacatTetap) ...[
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LabelInputRow(
                label: 'Biaya Perawatan / Pengobatan',
                controller: ctrlC,
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
                      'Maksimal Rp ${currFmt.format(batasC)} (maks. 10% UP)',
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
        const SizedBox(height: 10),
        const Text.rich(
          TextSpan(
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              height: 1.4,
            ),
            children: [
              TextSpan(
                text:
                    'Perawatan & Pengobatan hanya bisa diambil bersama Cacat Tetap',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              TextSpan(
                text:
                    ' (A tidak bisa digabung dengan C). Maks. C: 10% UP atau Rp 10.000.000.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Sub-seksi Perluasan dengan garis dashed
        const DashedHorizontalDivider(
          color: AppColors.borderDivider,
          height: 1,
          dashWidth: 4,
          dashSpace: 3,
        ),
        const SizedBox(height: 10),
        const Text(
          'Perluasan',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.alertTitle,
          ),
        ),
        const SizedBox(height: 8),
        if (hasNoUp)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.alertBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Isi UP Meninggal Dunia terlebih dahulu. Batas tiap perluasan maks. 10% dari UP tersebut.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.alertText,
                height: 1.3,
              ),
            ),
          )
        else ...[
          ...kPaxSantunanList
              .map((s) => _buildSantunanItemRow(s, currFmt)),
        ],
        const SizedBox(height: 4),
        const Text(
          'Premi dihitung otomatis dari tarif standar PA Xtra. Jaminan Pokok memakai 0.10%, atau 0.15% bila termasuk Cacat Tetap.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildPaXtraPerawatanBox(
      TextEditingController ctrl, NumberFormat currFmt) {
    final isDisabled = !cacatTetap;
    final isChecked = perawatanPengobatan && cacatTetap;

    final cardBg = isDisabled
        ? AppColors.bgDisabledCard
        : (isChecked ? AppColors.bgSelectedCard : Colors.white);
    final cardBd = isDisabled
        ? AppColors.borderDivider
        : (isChecked ? AppColors.navyMbis : AppColors.borderDefault);

    final boxBg = isDisabled
        ? AppColors.bgDisabled
        : (isChecked ? AppColors.navyMbis : Colors.white);
    final boxBd = isDisabled
        ? AppColors.borderDefault
        : (isChecked ? AppColors.navyMbis : AppColors.borderInactive);

    final textColor = isDisabled ? AppColors.textDisabled : AppColors.textDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cardBd,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: isDisabled
                    ? null
                    : () {
                        final nextVal = !perawatanPengobatan;
                        onPerawatanChanged(nextVal);
                        if (!nextVal) {
                          ctrl.clear();
                        } else {
                          ctrl.text = currFmt.format(batasC);
                        }
                        onFieldChanged?.call();
                      },
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: boxBg,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: boxBd,
                      width: 1.5,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check,
                          size: 14, color: AppColors.surfaceWhite)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Perawatan & Pengobatan',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          if (isDisabled)
            const Padding(
              padding: EdgeInsets.only(left: 34, top: 6),
              child: Text(
                'Centang Cacat Tetap terlebih dahulu. Perawatan & Pengobatan tidak bisa diambil tanpa Cacat Tetap.',
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
    );
  }

  Widget _buildSantunanItemRow(SantunanDef def, NumberFormat currFmt) {
    final key = def.key;
    final label = def.label;
    final ctrl = getSantunanCtrl(key);
    final maxLimit = batasSantunan(key, upVal);
    final currentVal = _parseNum(ctrl.text);
    final isChecked = ctrl.text.isNotEmpty && currentVal > 0;
    final isOver = currentVal > maxLimit;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  if (isChecked) {
                    ctrl.clear();
                  } else {
                    ctrl.text = currFmt.format(min(maxLimit, def.cap));
                  }
                  onFieldChanged?.call();
                },
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isChecked ? AppColors.navyMbis : Colors.white,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: isChecked
                          ? AppColors.navyMbis
                          : AppColors.borderInactive,
                      width: 1.5,
                    ),
                  ),
                  child: isChecked
                      ? const Icon(Icons.check,
                          size: 14, color: AppColors.surfaceWhite)
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 10,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textDark,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 10,
                child: Text(':', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 11,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isChecked ? Colors.white : AppColors.bgLightGray,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOver
                          ? AppColors.redRequired
                          : AppColors.borderDefault,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: ctrl,
                          enabled: isChecked,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.right,
                          cursorColor: AppColors.orangeMbis,
                          inputFormatters: const [
                            RupiahInputFormatter(),
                          ],
                          onChanged: (_) {
                            onFieldChanged?.call();
                          },
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isChecked
                                ? AppColors.blueInputText
                                : AppColors.textDisabled,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: '0',
                          ),
                        ),
                      ),
                      Text(
                        ',-',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isChecked
                              ? AppColors.blueInputText
                              : AppColors.textDisabled,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (isOver)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Maksimal Rp ${currFmt.format(maxLimit)} (maks. 10% UP)',
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
    );
  }
}
