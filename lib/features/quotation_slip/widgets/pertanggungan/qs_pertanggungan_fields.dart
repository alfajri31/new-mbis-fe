import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_theme.dart';

/// Label field dengan tanda bintang merah jika wajib diisi
class QsLabelText extends StatelessWidget {
  final String text;
  final bool required;

  const QsLabelText(
    this.text, {
    super.key,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textLabel,
          ),
        ),
        if (required)
          const Text(
            '*',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.redRequired,
            ),
          ),
      ],
    );
  }
}

/// Text input field standar Quotation Slip
class QsTextInputField extends StatelessWidget {
  final String label;
  final bool required;
  final TextEditingController controller;
  final String? placeholder;
  final String? helperText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const QsTextInputField({
    super.key,
    required this.label,
    this.required = false,
    required this.controller,
    this.placeholder,
    this.helperText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QsLabelText(label, required: required),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            onChanged: onChanged,
            validator: validator,
            cursorColor: AppColors.orangeMbis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.blueInputText,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              counterText: '',
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.textPlaceholder,
                fontWeight: FontWeight.w400,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.redRequired, width: 1.5),
              ),
            ),
          ),
          if (helperText != null) ...[
            const SizedBox(height: 6),
            Text(
              helperText!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Text area multi-line standar Quotation Slip
class QsTextAreaField extends StatelessWidget {
  final String label;
  final bool required;
  final TextEditingController controller;
  final String? placeholder;
  final String? Function(String?)? validator;

  const QsTextAreaField({
    super.key,
    required this.label,
    this.required = false,
    required this.controller,
    this.placeholder,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QsLabelText(label, required: required),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            maxLines: 2,
            validator: validator,
            cursorColor: AppColors.orangeMbis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.blueInputText,
              height: 1.45,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: const TextStyle(
                fontSize: 14,
                color: AppColors.textPlaceholder,
                fontWeight: FontWeight.w400,
              ),
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
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.redRequired, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Date picker field dengan trigger dialog kalender
class QsDatePickerField extends StatelessWidget {
  final String label;
  final bool required;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const QsDatePickerField({
    super.key,
    required this.label,
    this.required = false,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      validator: required
          ? (_) => value == null ? 'Wajib diisi' : null
          : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          QsLabelText(label, required: required),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(1920),
                lastDate: DateTime(2050),
              );
              if (picked != null) {
                onChanged(picked);
                field.didChange(picked);
              }
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: field.hasError
                      ? AppColors.redRequired
                      : AppColors.borderDefault,
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    value != null
                        ? '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}'
                        : 'Pilih tanggal',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: value != null
                          ? AppColors.blueInputText
                          : AppColors.textPlaceholder,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (field.hasError) ...[
            const SizedBox(height: 4),
            Text(
              field.errorText!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.redRequired,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Quick selection chip (untuk bidang usaha & pekerjaan)
class QsQuickChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const QsQuickChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.navyMbis : AppColors.textLabel,
          ),
        ),
      ),
    );
  }
}

/// Pill toggle button (misalnya Ya / Tidak)
class QsPillButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;

  const QsPillButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.activeColor = AppColors.navyMbis,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textLabel,
          ),
        ),
      ),
    );
  }
}

/// Card pilihan mode perhitungan premi (Normal, Mutlak, Flat)
class QsCalcModeCard extends StatelessWidget {
  final String label;
  final String desc;
  final bool isSelected;
  final VoidCallback onTap;

  const QsCalcModeCard({
    super.key,
    required this.label,
    required this.desc,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyMbis : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.navyMbis
                : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 11.5,
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.8)
                    : AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
