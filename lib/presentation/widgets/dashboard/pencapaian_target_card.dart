import 'package:flutter/material.dart';

import '../../../src/dashboard/dashboard_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// Kartu headline "Realisasi vs Target YTD": header (dropdown kategori 11 target
/// bila tersedia, atau judul), persentase, progress bar bergradien, dan baris
/// Realisasi/Target. Memilih kategori dikirim balik lewat [onCategoryChanged].
/// Murni presentational — diekstrak dari `dashboard_screen.dart`
/// (behavior-preserving).
class PencapaianTargetCard extends StatelessWidget {
  const PencapaianTargetCard({
    super.key,
    required this.summary,
    required this.selectedCat,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final DashboardSummary? summary;

  /// Kategori terpilih (mengalahkan angka summary lama).
  final DashboardCategoryStat? selectedCat;
  final DashboardCategories? categories;
  final String? selectedCategory;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final cat =
        selectedCat; // kategori terpilih (mengalahkan angka summary lama)
    // Target yang ditampilkan = target SETAHUN penuh (admin upload target setahun),
    // dibandingkan dengan realisasi berjalan. Bukan target YTD.
    final double? realVal = cat?.realisasiYtd ?? s?.totalRealization;
    final double? targetVal = cat?.targetFullYear ?? s?.premiTarget;
    final realisasi = realVal != null ? AppFormat.currencyShort(realVal) : '–';
    final target = targetVal != null ? AppFormat.currencyShort(targetVal) : '–';
    final rawPct = cat != null
        ? cat.progressFullYear
        : ((s != null && s.premiTarget > 0)
              ? s.totalRealization / s.premiTarget
              : 0.0);
    final pct = rawPct.clamp(0.0, 1.0);
    final title = cat != null
        ? 'Realisasi vs Target — ${cat.label}'
        : 'Realisasi vs Target Tahun Ini';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: (categories != null && categories!.categories.isNotEmpty)
                    ? _buildCategoryDropdown()
                    : Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(rawPct * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.grayBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: constraints.maxWidth * pct,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryNavy,
                          AppColors.secondaryOrange,
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Realisasi $realisasi',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Target $target',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Dropdown 11 target (image-1.png) di header kartu pencapaian. Memilih kategori
  /// mengubah progress bar + kartu Target/Realisasi YTD. Default Non Program Non Askred.
  Widget _buildCategoryDropdown() {
    final c = categories!;
    final selected = selectedCategory ?? c.defaultCategory;
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selected,
        isDense: true,
        isExpanded: true,
        borderRadius: BorderRadius.circular(8),
        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryNavy),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryNavy,
        ),
        items: [
          for (final item in c.categories)
            DropdownMenuItem(
              value: item.category,
              child: Text(item.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: (v) {
          if (v != null) onCategoryChanged(v);
        },
      ),
    );
  }
}
