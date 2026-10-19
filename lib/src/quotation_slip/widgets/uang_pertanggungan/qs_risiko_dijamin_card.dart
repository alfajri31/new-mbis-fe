import 'package:flutter/material.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';

/// Card Risiko Dijamin (uraian teks risiko yang dijamin dalam dokumen QS)
class QsRisikoDijaminCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onUseDefaultText;

  const QsRisikoDijaminCard({
    super.key,
    required this.controller,
    required this.onUseDefaultText,
  });

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: Icons.shield_outlined,
      title: 'Risiko Dijamin',
      subtitle: 'Teks di dokumen, terisi otomatis dari Jenis Risiko',
      children: [
        const Text(
          'Uraian risiko *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: 3,
          cursorColor: AppColors.orangeMbis,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.blueInputText,
            height: 1.45,
          ),
          decoration: InputDecoration(
            hintText: 'Uraian risiko yang dijamin',
            hintStyle: const TextStyle(
              fontSize: 14,
              color: AppColors.hintText,
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.borderDefault, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.borderDefault, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.orangeMbis, width: 2.0),
            ),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onUseDefaultText,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Gunakan teks standar',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.navyMbis,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
