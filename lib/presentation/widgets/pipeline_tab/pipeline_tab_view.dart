import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../src/pipeline/pipeline_repository.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../providers/pipeline_list_provider.dart';
import '../../screens/pipeline_detail_screen.dart';

class PipelineTabView extends ConsumerStatefulWidget {
  final double topInset;
  final VoidCallback? onRefresh;

  const PipelineTabView({
    super.key,
    required this.topInset,
    this.onRefresh,
  });

  @override
  ConsumerState<PipelineTabView> createState() => _PipelineTabViewState();
}

class _PipelineTabViewState extends ConsumerState<PipelineTabView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pipelineListProvider);
    final notifier = ref.read(pipelineListProvider.notifier);

    if (state.isLoading && state.allItems.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primaryNavy),
        ),
      );
    }

    if (state.error != null && state.allItems.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.error!,
                style: const TextStyle(color: AppColors.errorRed),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => notifier.fetchPipelines(),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = state.filteredItems;
    final stageCounts = state.stageCounts;

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            color: AppColors.surfaceWhite,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Chip Tahap (Semua, P3, P2, P1, Won, Decline) - Atas
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStageChip(
                        label: 'Semua (${stageCounts[''] ?? 0})',
                        isSelected: state.stage.isEmpty,
                        onTap: () => notifier.setStage(''),
                      ),
                      const SizedBox(width: 8),
                      _buildStageChip(
                        label: 'P3 (${stageCounts['P3'] ?? 0})',
                        isSelected: state.stage == 'P3',
                        onTap: () => notifier.setStage('P3'),
                      ),
                      const SizedBox(width: 8),
                      _buildStageChip(
                        label: 'P2 (${stageCounts['P2'] ?? 0})',
                        isSelected: state.stage == 'P2',
                        onTap: () => notifier.setStage('P2'),
                      ),
                      const SizedBox(width: 8),
                      _buildStageChip(
                        label: 'P1 (${stageCounts['P1'] ?? 0})',
                        isSelected: state.stage == 'P1',
                        onTap: () => notifier.setStage('P1'),
                      ),
                      const SizedBox(width: 8),
                      _buildStageChip(
                        label: 'Won (${stageCounts['WON'] ?? 0})',
                        isSelected: state.stage == 'WON',
                        onTap: () => notifier.setStage('WON'),
                      ),
                      const SizedBox(width: 8),
                      _buildStageChip(
                        label: 'Decline (${stageCounts['DECLINE'] ?? 0})',
                        isSelected: state.stage == 'DECLINE',
                        onTap: () => notifier.setStage('DECLINE'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 2. Kolom pencarian - Tengah (sesuai prototype)
                Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgScaffold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: notifier.setSearch,
                          decoration: const InputDecoration(
                            hintText: 'Cari customer, BUMN, atau produk',
                            hintStyle: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.hintText,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            notifier.setSearch('');
                          },
                          child: const Icon(Icons.clear, size: 18, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Baris Dropdown Filter (Produk, Sumber, Pengelola, Urutkan)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Filter Produk
                      _buildFilterDropdown<String>(
                        value: state.prod,
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Semua produk')),
                          DropdownMenuItem(value: 'psakdi', child: Text('PSAKDI')),
                          DropdownMenuItem(value: 'paxtra', child: Text('PA Xtra')),
                          DropdownMenuItem(value: 'other', child: Text('Produk lain')),
                        ],
                        onChanged: (val) => notifier.setProd(val ?? ''),
                      ),
                      const SizedBox(width: 8),

                      // Filter Sumber
                      _buildFilterDropdown<String>(
                        value: state.src,
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Semua sumber')),
                          DropdownMenuItem(value: 'cust', child: Text('Customer')),
                          DropdownMenuItem(value: 'bumn', child: Text('BUMN')),
                        ],
                        onChanged: (val) => notifier.setSrc(val ?? ''),
                      ),
                      const SizedBox(width: 8),

                      // Filter Pengelola
                      _buildFilterDropdown<String>(
                        value: state.mine,
                        items: const [
                          DropdownMenuItem(value: '', child: Text('Semua pengelola')),
                          DropdownMenuItem(value: 'me', child: Text('Milik saya')),
                        ],
                        onChanged: (val) => notifier.setMine(val ?? ''),
                      ),
                      const SizedBox(width: 8),

                      // Filter Urutkan
                      _buildFilterDropdown<String>(
                        value: state.sort,
                        items: const [
                          DropdownMenuItem(value: 'new', child: Text('Terbaru')),
                          DropdownMenuItem(value: 'pot', child: Text('Potensi terbesar')),
                        ],
                        onChanged: (val) => notifier.setSort(val ?? 'new'),
                      ),

                      if (state.hasActiveFilter) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            notifier.resetFilters();
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'Reset filter',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.orangeDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Ringkasan Jumlah & Total Potensi
                Text(
                  '${filtered.length} pipeline · Potensi ${AppFormat.rupiah(state.totalPotensi)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),

        // List item atau Empty state
        if (filtered.isEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text(
                  'Tidak ada pipeline sesuai filter.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final p = filtered[index];
                return _buildPipelineCard(context, p);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStageChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyMbis : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.navyMbis : AppColors.borderDefault,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.surfaceWhite : AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderDefault, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          isDense: true,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
          icon: const Icon(Icons.arrow_drop_down, size: 18, color: AppColors.iconDropdown),
        ),
      ),
    );
  }

  Widget _buildPipelineCard(BuildContext context, PipelineListModel p) {
    final title = (p.projectName != null && p.projectName!.trim().isNotEmpty)
        ? p.projectName!.trim()
        : ((p.product != null && p.product!.trim().isNotEmpty)
            ? p.product!.trim()
            : 'Pipeline - ${p.customerName}');

    final isBumn = p.isBumn ||
        (p.sourceType ?? '').toLowerCase().contains('bumn') ||
        (p.bumnName != null && p.bumnName!.isNotEmpty);

    final kanwil = (p.kanwil != null && p.kanwil!.isNotEmpty) ? p.kanwil! : 'Kantor Wilayah 1';
    final kc = (p.kc != null && p.kc!.isNotEmpty)
        ? (p.kc!.startsWith('KC ') ? p.kc! : 'KC ${p.kc}')
        : 'KC Padang';
    final rm = (p.rmName != null && p.rmName!.isNotEmpty) ? p.rmName! : 'Mohammad Ridwan Majid';
    final pengelolaText = '$kanwil · $kc · $rm';

    final stageInfo = _getStageInfo(p.stage);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PipelineDetailScreen(pipelineId: p.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderDivider),
          boxShadow: const [AppShadows.level1],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header kartu: Judul, Customer/BUMN, Badge Stage
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navyMbis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              p.customerName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textLabel,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.bgScaffold,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              isBumn ? 'BUMN' : 'Customer',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: stageInfo.bgColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    stageInfo.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: stageInfo.textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Box Tengah: 3 Kolom (Sumber Bisnis, TSI, Potensi Premi)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgDisabledCard,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sumber Bisnis',
                          style: TextStyle(fontSize: 10.5, color: AppColors.iconDropdown),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          p.sourceType ?? '-',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TSI',
                          style: TextStyle(fontSize: 10.5, color: AppColors.iconDropdown),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          AppFormat.rupiah(p.tsiIdr),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Potensi Premi',
                          style: TextStyle(fontSize: 10.5, color: AppColors.iconDropdown),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          AppFormat.rupiah(p.potensiPremi ?? p.premi ?? 0),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.orangeDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Footer kartu: Kanwil · KC · RM
            Text(
              pengelolaText,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  _StageInfo _getStageInfo(String stage) {
    switch (stage.toUpperCase()) {
      case 'P3':
        return const _StageInfo('P3 · Prospek', AppColors.blueLightBg, AppColors.navyMbis);
      case 'P2':
        return const _StageInfo('P2 · Proses', AppColors.badgeP2Bg, AppColors.alertTitle);
      case 'P1':
        return const _StageInfo('P1 · Penerbitan', AppColors.badgeP1Bg, AppColors.greenTotal);
      case 'WON':
        return const _StageInfo('Won', AppColors.greenTotal, AppColors.surfaceWhite);
      case 'DECLINE':
      default:
        return const _StageInfo('Decline', AppColors.errorBannerBg, AppColors.redRequired);
    }
  }
}

class _StageInfo {
  final String label;
  final Color bgColor;
  final Color textColor;

  const _StageInfo(this.label, this.bgColor, this.textColor);
}
