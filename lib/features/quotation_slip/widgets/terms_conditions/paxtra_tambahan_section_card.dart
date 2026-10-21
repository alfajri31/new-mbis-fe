import 'package:flutter/material.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';

/// Card seksi dengan daftar standar terkunci + daftar tambahan (Kondisi, Waranti, Pengecualian di PA Xtra) - Prototype 1:1
class PaXtraTambahanSectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> standardItems;
  final String tambahanTitle;
  final String draftPlaceholder;
  final TextEditingController draftCtrl;
  final List<String> items;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const PaXtraTambahanSectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.standardItems,
    required this.tambahanTitle,
    required this.draftPlaceholder,
    required this.draftCtrl,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: Icons.format_list_bulleted,
      title: title,
      subtitle: subtitle,
      children: [
        // 1. Standard locked items list
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderDivider),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: standardItems.asMap().entries.map((entry) {
              final isLast = entry.key == standardItems.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.bgDisabledCard,
                  border: isLast
                      ? null
                      : const Border(
                          bottom: BorderSide(color: AppColors.bgDisabled),
                        ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.grayStage,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: AppColors.surfaceWhite,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 14),

        // 2. Tambahan section
        Text(
          tambahanTitle,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textLabel,
          ),
        ),
        const SizedBox(height: 10),

        // 3. Added items list (if any)
        if (items.isNotEmpty) ...[
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderDivider),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: items.asMap().entries.map((entry) {
                final isLast = entry.key == items.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    border: isLast
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppColors.bgDisabled),
                          ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: AppColors.blueInputText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () => onRemove(entry.key),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: AppColors.redRequired,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // 4. Draft input row & Tambah button
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.borderDefault,
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: draftCtrl,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.blueInputText,
                    fontWeight: FontWeight.w600,
                  ),
                  cursorColor: AppColors.orangeMbis,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintText: draftPlaceholder,
                    hintStyle: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPlaceholder,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.blueLightBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      size: 16,
                      color: AppColors.navyMbis,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Tambah',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyMbis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
