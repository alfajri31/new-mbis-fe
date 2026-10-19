import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_theme.dart';
import 'rupiah_input_formatter.dart';

export 'rupiah_input_formatter.dart';

/// Row input formulir terpadu Quotation Slip: label, tanda titik dua,
/// dan field input teks/angka rata kanan dengan akhiran ',-'.
class LabelInputRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool hasError;
  final bool isNumeric;
  final bool isCurrency;
  final int labelFlex;
  final int inputFlex;

  const LabelInputRow({
    super.key,
    required this.label,
    required this.controller,
    this.hasError = false,
    this.isNumeric = true,
    this.isCurrency = false,
    this.labelFlex = 1,
    this.inputFlex = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: labelFlex,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.textDark,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          ':',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: inputFlex,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasError
                    ? AppColors.redRequired
                    : AppColors.borderDefault,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    keyboardType: isNumeric
                        ? TextInputType.number
                        : TextInputType.text,
                    textAlign: TextAlign.right,
                    cursorColor: AppColors.orangeMbis,
                    inputFormatters: isCurrency
                        ? const [RupiahInputFormatter()]
                        : (isNumeric
                            ? [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.,]'),
                                ),
                              ]
                            : null),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.blueInputText,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '0',
                    ),
                  ),
                ),
                const Text(
                  ',-',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.blueInputText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
