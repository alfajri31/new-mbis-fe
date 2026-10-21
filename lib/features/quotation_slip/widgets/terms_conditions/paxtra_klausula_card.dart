import 'package:flutter/material.dart';

import '../common/qs_section_card.dart';
import '../../../../theme/app_theme.dart';

/// Card Klausula PA Xtra (13 Klausula Standar + Pilihan Klausul Tambahan) - Prototype 1:1
class PaXtraKlausulaCard extends StatelessWidget {
  final List<String> standardKlausula;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final List<String> klausulTambahanList;
  final TextEditingController draftKlausulCtrl;
  final VoidCallback onAddKlausul;
  final ValueChanged<int> onRemoveKlausul;

  const PaXtraKlausulaCard({
    super.key,
    required this.standardKlausula,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.klausulTambahanList,
    required this.draftKlausulCtrl,
    required this.onAddKlausul,
    required this.onRemoveKlausul,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Klausula Standar Card
        QsSectionCard(
          icon: Icons.article_outlined,
          title: 'Klausula',
          subtitle:
              '${standardKlausula.length} klausula standar · semua tercentang, tidak dapat diubah',
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
                    Icon(
                      isExpanded
                          ? Icons.format_list_bulleted
                          : Icons.format_list_bulleted,
                      size: 16,
                      color: AppColors.navyMbis,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isExpanded
                          ? 'Tutup daftar (${standardKlausula.length})'
                          : 'Lihat daftar (${standardKlausula.length})',
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
            if (isExpanded) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderDivider),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: standardKlausula.asMap().entries.map((entry) {
                    final isLast = entry.key == standardKlausula.length - 1;
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
        ),

        const SizedBox(height: 14),

        // 2. Pilihan Klausul Tambahan Card
        QsSectionCard(
          icon: Icons.format_list_bulleted,
          title: 'Pilihan Klausul Tambahan',
          subtitle:
              'Tambahan di luar ${standardKlausula.length} klausula standar',
          children: [
            if (klausulTambahanList.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.borderDivider),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: klausulTambahanList.asMap().entries.map((entry) {
                    final isLast = entry.key == klausulTambahanList.length - 1;
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
                            onTap: () => onRemoveKlausul(entry.key),
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
              const SizedBox(height: 12),
            ],
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
                      controller: draftKlausulCtrl,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.blueInputText,
                        fontWeight: FontWeight.w600,
                      ),
                      cursorColor: AppColors.orangeMbis,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                        hintText: 'Tulis klausul tambahan…',
                        hintStyle: TextStyle(
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
                  onTap: onAddKlausul,
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
        ),
      ],
    );
  }
}
