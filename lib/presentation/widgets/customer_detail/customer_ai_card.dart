import 'package:flutter/material.dart';

import '../../../src/assistant/assistant_repository.dart';
import '../../../theme/app_theme.dart';

/// "2026-07-03T14:20:33.1" -> "2026-07-03 14:20" (empty when absent). Lets the RM tell apart
/// multiple saved runs of the same activity now that history is kept.
String _formatSavedAt(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final noFraction = iso.replaceFirst('T', ' ').split('.').first;
  final parts = noFraction.split(':');
  return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : noFraction;
}

/// "Asisten AI" — a launcher (RM only) + the AI results saved on this customer
/// (anyone with access can read). Hidden entirely when there's nothing to show.
/// [canRun] gates the launcher (RM), [onRun] opens the assistant, dan
/// [onResultTap] membuka satu hasil tersimpan. Murni presentational — diekstrak
/// dari `customer_detail_screen.dart` (behavior-preserving).
class CustomerAiCard extends StatelessWidget {
  const CustomerAiCard({
    super.key,
    required this.canRun,
    required this.results,
    required this.onRun,
    required this.onResultTap,
  });

  final bool canRun;
  final List<SavedAiResult> results;
  final VoidCallback onRun;
  final ValueChanged<SavedAiResult> onResultTap;

  @override
  Widget build(BuildContext context) {
    if (!canRun && results.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
          boxShadow: const [AppShadows.level1],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.asset(
                  'assets/images/maskot.png',
                  width: 30,
                  height: 30,
                  // Aset 1309x1202; tanpa cacheWidth/cacheHeight Flutter men-decode
                  // resolusi penuh (±6 MB) walau digambar 30 px.
                  cacheWidth:
                      (30 * MediaQuery.devicePixelRatioOf(context)).round(),
                  cacheHeight:
                      (30 * MediaQuery.devicePixelRatioOf(context)).round(),
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.smart_toy_outlined,
                    size: 26,
                    color: AppColors.primaryNavy,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tanya Dubi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (canRun)
                  TextButton.icon(
                    onPressed: onRun,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryNavy,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 16),
                    label: const Text(
                      'Jalankan',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            if (results.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Belum ada hasil tersimpan. Jalankan aktivitas AI lalu simpan rangkumannya.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...results.map(
                (r) => _SavedResultTile(result: r, onTap: () => onResultTap(r)),
              ),
          ],
        ),
      ),
    );
  }
}

class _SavedResultTile extends StatelessWidget {
  const _SavedResultTile({required this.result, required this.onTap});

  final SavedAiResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: AppColors.navyBg,
        borderRadius: AppRadius.radiusMd,
        child: InkWell(
          borderRadius: AppRadius.radiusMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.activityName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (r.result.judul ?? '').isNotEmpty
                            ? r.result.judul!
                            : r.result.plainText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (_formatSavedAt(r.generatedAt).isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatSavedAt(r.generatedAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.grayStage,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.grayStage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
