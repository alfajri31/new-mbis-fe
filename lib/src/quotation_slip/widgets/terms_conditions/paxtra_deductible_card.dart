import 'package:flutter/material.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';

/// Card Deductible PA Xtra (Personal Accident) - StatelessWidget
class PaXtraDeductibleCard extends StatelessWidget {
  final TextEditingController deductibleCtrl;
  final VoidCallback? onFieldChanged;

  const PaXtraDeductibleCard({
    super.key,
    required this.deductibleCtrl,
    this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: Icons.shield_outlined,
      title: 'Deductible',
      children: [
        const Text(
          'Personal Accident',
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
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDefault, width: 1.5),
          ),
          child: TextFormField(
            controller: deductibleCtrl,
            onChanged: (_) => onFieldChanged?.call(),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.blueInputText,
            ),
            cursorColor: AppColors.orangeMbis,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
              hintText: 'Nil',
              hintStyle: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.normal,
                color: AppColors.textPlaceholder,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
