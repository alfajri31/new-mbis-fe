import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Card section pembungkus informasi rekap detail dan review kunjungan RM
class VisitDetailSectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const VisitDetailSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border.all(color: AppColors.borderDivider),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Baris detail 2-kolom (Label di kiri, Content dinamis di kanan)
class VisitDetailRow extends StatelessWidget {
  final String label;
  final Widget content;
  final double labelWidth;

  const VisitDetailRow(
    this.label,
    this.content, {
    super.key,
    this.labelWidth = 135,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEF1F6))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF5A6475),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: content),
        ],
      ),
    );
  }
}
