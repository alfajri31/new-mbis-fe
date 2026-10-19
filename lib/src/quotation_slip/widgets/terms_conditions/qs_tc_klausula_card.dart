import 'package:flutter/material.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';

/// Card Klausula Standar dengan tombol lihat/tutup daftar - Prototype 1:1
class QsTcKlausulaCard extends StatelessWidget {
  final List<String> klausulaList;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const QsTcKlausulaCard({
    super.key,
    required this.klausulaList,
    required this.isExpanded,
    required this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: Icons.format_list_bulleted,
      title: 'Klausula',
      subtitle:
          '${klausulaList.length} klausula standar · semua tercentang, tidak dapat diubah',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.blueLightBg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 12, color: AppColors.navyMbis),
            SizedBox(width: 4),
            Text(
              'Terkunci',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.navyMbis,
              ),
            ),
          ],
        ),
      ),
      children: [
        // Button Lihat / Tutup daftar
        InkWell(
          onTap: onToggleExpand,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.borderDefault,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.format_list_bulleted,
                  size: 16,
                  color: AppColors.navyMbis,
                ),
                const SizedBox(width: 6),
                Text(
                  isExpanded
                      ? 'Tutup daftar (${klausulaList.length})'
                      : 'Lihat daftar (${klausulaList.length})',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navyMbis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded list items
        if (isExpanded) ...[
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderDivider),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: klausulaList.asMap().entries.map((entry) {
                final isLast = entry.key == klausulaList.length - 1;
                return Container(
                  padding: const EdgeInsets.all(12),
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
                      // Checkbox locked
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: AppColors.grayStage,
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: AppColors.grayStage,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.surfaceWhite,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Number
                      SizedBox(
                        width: 22,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            '${entry.key + 1}.',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      // Title
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
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
        ],

        // Footnote
        const SizedBox(height: 12),
        const Text(
          'Klausula mengikuti ketentuan standar dan otomatis tercantum di lampiran QS.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
