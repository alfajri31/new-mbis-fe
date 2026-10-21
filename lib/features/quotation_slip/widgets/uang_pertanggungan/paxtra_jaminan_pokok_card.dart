import 'package:flutter/material.dart';

import '../common/label_input_row.dart';
import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';

/// Card Jaminan Pokok untuk PA Xtra (Uang Pertanggungan Meninggal Dunia)
class PaXtraJaminanPokokCard extends StatelessWidget {
  final TextEditingController upPaXtraCtrl;
  final VoidCallback? onFieldChanged;

  const PaXtraJaminanPokokCard({
    super.key,
    required this.upPaXtraCtrl,
    this.onFieldChanged,
  });

  double _parseNum(String s) =>
      double.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final upVal = _parseNum(upPaXtraCtrl.text);
    final upOver = upVal > 1000000000;

    return QsSectionCard(
      title: 'Jaminan Pokok',
      children: [
        LabelInputRow(
          label: 'Uang Pertanggungan (Meninggal Dunia)',
          controller: upPaXtraCtrl,
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
                'Maksimal Rp 1.000.000.000',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.redRequired,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
