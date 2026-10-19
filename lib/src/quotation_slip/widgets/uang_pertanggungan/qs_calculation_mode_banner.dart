import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';
import '../../qs_form_state.dart';

/// Banner informasi mode perhitungan premi yang aktif
class QsCalculationModeBanner extends StatelessWidget {
  final QsPremiMode premiMode;
  final VoidCallback? onJumpToStep1;

  const QsCalculationModeBanner({
    super.key,
    required this.premiMode,
    this.onJumpToStep1,
  });

  @override
  Widget build(BuildContext context) {
    final String modeText;
    switch (premiMode) {
      case QsPremiMode.normal:
        modeText = 'Normal · rate × UP × hari/365';
        break;
      case QsPremiMode.flat:
        modeText = 'Flat · tarif per hari × hari × peserta';
        break;
      case QsPremiMode.mutlak:
        modeText = 'Mutlak · nominal premi diisi langsung';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.blueLightBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.monetization_on_outlined,
            size: 18,
            color: AppColors.navyMbis,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Perhitungan: ',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textDark,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: modeText,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onJumpToStep1,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Ubah di Pertanggungan',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.orangeDark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
