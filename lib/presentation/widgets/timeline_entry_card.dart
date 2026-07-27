import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../src/pipeline/pipeline_timeline.dart';

/// One row of the merged "Riwayat" (stage change / field edit / visit).
///
/// Shared by the pipeline detail preview card and the full Riwayat tab so the
/// two surfaces can't drift into rendering the same event differently. Visit
/// entries are tappable ([onTap] opens the detail sheet); stage/edit entries
/// have nothing further to show, so they aren't.
class TimelineEntryCard extends StatelessWidget {
  final TimelineEntry entry;
  final VoidCallback? onTap;

  const TimelineEntryCard({super.key, required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, Color bg) = switch (entry.kind) {
      TimelineKind.visit => (Icons.place_outlined, AppColors.secondaryOrange, AppColors.orangeLight),
      TimelineKind.edit => (Icons.edit_outlined, AppColors.grayStage, AppColors.grayBg),
      TimelineKind.stage => (Icons.flag_outlined, AppColors.primaryNavy, AppColors.navyBg),
    };

    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                if (entry.detail != null) ...[
                  const SizedBox(height: 4),
                  Text(entry.detail!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(AppFormat.dateTime(entry.at),
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                    if (entry.actorName != null) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(entry.actorName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, size: 18, color: AppColors.grayStage),
        ],
      ),
    );

    return onTap == null ? card : GestureDetector(onTap: onTap, child: card);
  }
}
