import 'package:flutter/material.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';

/// Card Penerbitan (Kota, Tanggal, Cabang, Penandatangan, Jabatan) - StatelessWidget
class QsTcPenerbitanCard extends StatelessWidget {
  final TextEditingController kotaCtrl;
  final DateTime tglPenerbitan;
  final ValueChanged<DateTime> onTglPenerbitanChanged;
  final TextEditingController cabangCtrl;
  final TextEditingController penandatanganCtrl;
  final TextEditingController jabatanCtrl;
  final VoidCallback? onFieldChanged;

  const QsTcPenerbitanCard({
    super.key,
    required this.kotaCtrl,
    required this.tglPenerbitan,
    required this.onTglPenerbitanChanged,
    required this.cabangCtrl,
    required this.penandatanganCtrl,
    required this.jabatanCtrl,
    this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: Icons.edit_outlined,
      title: 'Penerbitan',
      subtitle: 'PT Asuransi Kredit Indonesia',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInputField(
                label: 'Kota',
                controller: kotaCtrl,
                placeholder: 'cth. Padang',
                isRequired: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDatePickerField(
                context: context,
                label: 'Tanggal',
                value: tglPenerbitan,
                onChanged: (d) {
                  if (d != null) {
                    onTglPenerbitanChanged(d);
                    onFieldChanged?.call();
                  }
                },
                placeholder: 'dd/mm/yyyy',
                isRequired: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildInputField(
          label: 'Cabang',
          controller: cabangCtrl,
          placeholder: 'cth. PADANG',
          isRequired: true,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildInputField(
                label: 'Penandatangan',
                controller: penandatanganCtrl,
                placeholder: 'Nama',
                isRequired: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInputField(
                label: 'Jabatan',
                controller: jabatanCtrl,
                placeholder: 'cth. Pemimpin Cabang',
                isRequired: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String placeholder,
    bool isRequired = false,
  }) {
    return FormField<String>(
      key: ValueKey(controller.text),
      initialValue: controller.text,
      validator: isRequired
          ? (_) => controller.text.trim().isEmpty ? 'Wajib diisi' : null
          : null,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLabel,
                ),
                children: isRequired
                    ? const [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: AppColors.redRequired,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: field.hasError
                      ? AppColors.redRequired
                      : AppColors.borderDefault,
                  width: 1.5,
                ),
              ),
              child: TextField(
                controller: controller,
                onChanged: (val) {
                  field.didChange(val);
                  onFieldChanged?.call();
                },
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.blueInputText,
                ),
                cursorColor: AppColors.orangeMbis,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintText: placeholder,
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.normal,
                    color: AppColors.textPlaceholder,
                  ),
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
        );
      },
    );
  }

  Widget _buildDatePickerField({
    required BuildContext context,
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime?> onChanged,
    required String placeholder,
    bool isRequired = false,
  }) {
    return FormField<DateTime>(
      key: ValueKey(value),
      initialValue: value,
      validator: isRequired
          ? (_) => value == null ? 'Wajib diisi' : null
          : null,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(
                text: label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textLabel,
                ),
                children: isRequired
                    ? const [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: AppColors.redRequired,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: Theme.of(ctx)
                          .colorScheme
                          .copyWith(primary: AppColors.navyMbis),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  onChanged(picked);
                  field.didChange(picked);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: field.hasError
                        ? AppColors.redRequired
                        : AppColors.borderDefault,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value != null
                            ? '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}'
                            : placeholder,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: value != null
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: value != null
                              ? AppColors.blueInputText
                              : AppColors.textPlaceholder,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.navyMbis,
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
        );
      },
    );
  }
}
