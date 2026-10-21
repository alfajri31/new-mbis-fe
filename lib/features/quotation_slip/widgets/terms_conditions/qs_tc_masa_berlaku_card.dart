import 'package:flutter/material.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';

/// Card Masa Berlaku Penawaran dengan quick day chips (+7 hari, +14 hari) - StatelessWidget
class QsTcMasaBerlakuCard extends StatelessWidget {
  final DateTime masaBerlaku;
  final DateTime baseDate;
  final ValueChanged<DateTime> onMasaBerlakuChanged;
  final List<int> quickDays;
  final VoidCallback? onFieldChanged;

  const QsTcMasaBerlakuCard({
    super.key,
    required this.masaBerlaku,
    required this.baseDate,
    required this.onMasaBerlakuChanged,
    this.quickDays = const [7, 14],
    this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: Icons.calendar_today_outlined,
      title: 'Masa Berlaku Penawaran',
      children: [
        _buildDatePickerField(
          context: context,
          label: 'Berlaku sampai dengan',
          value: masaBerlaku,
          onChanged: (d) {
            if (d != null) {
              onMasaBerlakuChanged(d);
              onFieldChanged?.call();
            }
          },
          placeholder: 'dd/mm/yyyy',
          isRequired: true,
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickDays.map((days) {
            final target = baseDate.add(Duration(days: days));
            final isSelected = masaBerlaku.year == target.year &&
                masaBerlaku.month == target.month &&
                masaBerlaku.day == target.day;

            return InkWell(
              onTap: () {
                onMasaBerlakuChanged(target);
                onFieldChanged?.call();
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.blueLightBg
                      : AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.navyMbis
                        : AppColors.borderDefault,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '+$days hari',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? AppColors.navyMbis
                            : AppColors.textLabel,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text(
          'Penawaran bukan bukti bahwa risiko telah dijamin.',
          style:
              TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
        ),
      ],
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
