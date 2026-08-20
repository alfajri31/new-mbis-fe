import 'package:flutter/material.dart';

import '../../../src/dashboard/dashboard_periode.dart';
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
    this.periode = DashboardPeriode.ytd,
    this.angka,
  });

  /// Potongan periode terpilih (CR-02) — hanya untuk penamaan; angkanya di [angka].
  final DashboardPeriode periode;

  /// Target & realisasi kategori terpilih untuk [periode]. null bila data kategori
  /// belum termuat; kartu lalu jatuh ke angka ringkasan seperti sebelumnya.
  final AngkaPeriode? angka;

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
    // Pembandingnya target YTD — target sampai bulan berjalan, bukan target setahun.
    //
    // Sebelumnya kartu ini memakai targetFullYear padahal judulnya sudah "Target YTD",
    // sehingga realisasi berjalan dibagi target 12 bulan dan pencapaian RM tampil jauh
    // lebih kecil dari sebenarnya (umpan balik piloting Tangerang). Target setahun tetap
    // ditampilkan di baris bawah sebagai konteks, jadi tidak ada angka yang hilang.
    //
    // Jalur tanpa kategori (mis. agen, atau /categories gagal dimuat) tidak punya angka
    // target YTD — di situ saja kartu jatuh kembali ke target setahun, dan labelnya ikut
    // menyesuaikan supaya tidak ada klaim yang menyesatkan.
    //
    // Angka periode (CR-02) dihitung di klien dari 12 bulan yang sudah dikirim server;
    // YTD hanyalah salah satu potongannya, bukan kasus istimewa lagi.
    final bool adaTargetYtd = cat != null && angka != null;
    final bool belumTiba = angka?.belumTiba ?? false;
    final double? realVal = angka?.realisasi ?? s?.totalRealization;
    final double? targetVal = angka?.target ?? s?.premiTarget;
    final realisasi =
        (belumTiba || realVal == null) ? '–' : AppFormat.currencyShort(realVal);
    final target =
        (belumTiba || targetVal == null) ? '–' : AppFormat.currencyShort(targetVal);
    final rawPct = angka != null
        ? angka!.progress
        : ((s != null && s.premiTarget > 0)
              ? s.totalRealization / s.premiTarget
              : 0.0);
    final pct = rawPct.clamp(0.0, 1.0);
    final title = cat != null
        ? 'Realisasi vs Target ${periode.label} — ${cat.label}'
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
              // Periode yang belum tiba tidak punya pencapaian. Menuliskan "0%"
              // di sana terbaca sebagai kegagalan RM, padahal bulannya memang
              // belum berjalan — persis yang dihindari oleh baris rupiah di
              // bawah yang sudah memakai tanda "–".
              Text(
                belumTiba ? '–' : '${(rawPct * 100).round()}%',
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
                adaTargetYtd ? 'Target ${periode.label} $target' : 'Target $target',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          // Periode yang belum tiba (mis. Triwulan IV dilihat bulan Agustus) dinyatakan
          // apa adanya. Tanpa ini kartu menampilkan 0% dan terbaca seolah RM gagal
          // total, padahal periodenya memang belum berjalan.
          if (belumTiba)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Periode ini belum berjalan.',
                style: TextStyle(fontSize: 10, color: AppColors.grayStage),
              ),
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
