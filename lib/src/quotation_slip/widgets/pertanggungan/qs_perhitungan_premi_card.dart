import 'package:flutter/material.dart';

import '../common/qs_section_card.dart';
import '../../qs_form_state.dart';
import 'qs_pertanggungan_fields.dart';

/// Card Section 3: Mode Perhitungan Premi (Normal, Mutlak, Flat)
class QsPerhitunganPremiCard extends StatelessWidget {
  final QsPremiMode premiMode;
  final ValueChanged<QsPremiMode> onPremiModeChanged;

  const QsPerhitunganPremiCard({
    super.key,
    required this.premiMode,
    required this.onPremiModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: Icons.paid_outlined,
      title: 'Perhitungan Premi',
      requiredTitle: true,
      subtitle: 'Pilih cara menghitung premi',
      children: [
        Row(
          children: [
            Expanded(
              child: QsCalcModeCard(
                label: 'Normal',
                desc: 'Rate × UP',
                isSelected: premiMode == QsPremiMode.normal,
                onTap: () => onPremiModeChanged(QsPremiMode.normal),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: QsCalcModeCard(
                label: 'Mutlak',
                desc: 'Nominal premi',
                isSelected: premiMode == QsPremiMode.mutlak,
                onTap: () => onPremiModeChanged(QsPremiMode.mutlak),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: QsCalcModeCard(
                label: 'Flat',
                desc: 'Tarif per hari',
                isSelected: premiMode == QsPremiMode.flat,
                onTap: () => onPremiModeChanged(QsPremiMode.flat),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
