import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../theme/app_theme.dart';

/// Input field dengan trailing label / suffix (misal: '%', 'thn', dll.)
/// yang digunakan dalam perhitungan rate, santunan, dan diskon.
class InputWithSuffix extends StatelessWidget {
  final TextEditingController controller;
  final String suffixText;
  final bool hasError;
  final String errorText;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  const InputWithSuffix({
    super.key,
    required this.controller,
    required this.suffixText,
    this.hasError = false,
    this.errorText = 'Wajib diisi',
    this.hintText = '0.00',
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: enabled ? AppColors.surfaceWhite : AppColors.bgScaffold,
            borderRadius: BorderRadius.circular(12),
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
                  enabled: enabled,
                  onChanged: onChanged,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  cursorColor: AppColors.orangeMbis,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                  ],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blueInputText,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.hintText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                suffixText,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              errorText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.redRequired,
              ),
            ),
          ),
      ],
    );
  }
}
