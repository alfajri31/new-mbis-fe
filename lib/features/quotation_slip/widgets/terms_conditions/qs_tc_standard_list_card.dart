import 'package:flutter/material.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';

/// Card daftar standar dengan icon checklist terkunci (Kondisi, Waranti, Pengecualian)
class QsTcStandardListCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> items;
  final IconData icon;

  const QsTcStandardListCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.items,
    this.icon = Icons.format_list_bulleted,
  });

  @override
  Widget build(BuildContext context) {
    return QsSectionCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      children: [
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
                      margin: const EdgeInsets.only(top: 1),
                      decoration: BoxDecoration(
                        color: AppColors.grayStage,
                        borderRadius: BorderRadius.circular(7),
                      ),
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
      ],
    );
  }
}
