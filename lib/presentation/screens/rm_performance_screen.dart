import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../utils/format.dart';
import '../../src/dashboard/dashboard_repository.dart';
import '../providers/rm_performance_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/state_views.dart';

/// Full, server-paginated per-RM performance list ("Lihat Semua RM"). Loaded one
/// page at a time (infinite scroll) so a DPJ's national roster never loads all at
/// once. Filterable by region/branch and searchable by RM name or NIP.
class RmPerformanceScreen extends ConsumerStatefulWidget {
  /// Optional initial filter applied on open (e.g. when arriving from a per-wilayah
  /// / per-cabang card on the dashboard, or an RM card via name search).
  final String? initialRegionId;
  final String? initialBranchId;
  final String? initialSearch;

  const RmPerformanceScreen({
    super.key,
    this.initialRegionId,
    this.initialBranchId,
    this.initialSearch,
  });

  @override
  ConsumerState<RmPerformanceScreen> createState() =>
      _RmPerformanceScreenState();
}

class _RmPerformanceScreenState extends ConsumerState<RmPerformanceScreen> {
  // UI-ephemeral (tetap di widget): scroll, kolom cari, debounce.
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // State bisnis/async dikelola RmPerformanceNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  RmPerformanceState get _rmp => ref.read(rmPerformanceProvider);
  RmPerformanceNotifier get _notifier => ref.read(rmPerformanceProvider.notifier);

  // Repo dipakai FutureBuilder di dialog detail (`getRmMonthly`). Nullable seperti
  // field `_repo` lama agar `_repo?.` di bawah tak berubah.
  DashboardRepository? get _repo => _notifier.repo;
  List<RmStat> get _items => _rmp.items;
  bool get _last => _rmp.last;
  int get _total => _rmp.total;
  int get _filteredActivePipelines => _rmp.filteredActivePipelines;
  double get _filteredRealisasi => _rmp.filteredRealisasi;
  int get _rmsWithoutPipeline => _rmp.rmsWithoutPipeline;
  int get _p3 => _rmp.p3;
  int get _p2 => _rmp.p2;
  int get _p1 => _rmp.p1;
  int get _won => _rmp.won;
  int get _decline => _rmp.decline;
  String? get _regionId => _rmp.regionId;
  String? get _branchId => _rmp.branchId;
  bool get _connectOnly => _rmp.connectOnly;
  bool get _initialLoading => _rmp.initialLoading;
  bool get _loadingMore => _rmp.loadingMore;
  String? get _error => _rmp.error;
  List<ScopeOffice> get _regions => _rmp.regions;
  List<ScopeOffice> get _branches => _rmp.branches;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Kolom cari (UI) diseed sinkron; filter awal (region/branch/search) diserahkan
    // ke notifier saat start post-frame. Sesi dibaca notifier dari provider.
    _searchController.text = widget.initialSearch ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start(
        initialRegionId: widget.initialRegionId,
        initialBranchId: widget.initialBranchId,
        initialSearch: widget.initialSearch,
      );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Aksi filter/paging/reset → delegasi ke RmPerformanceNotifier (logika dipindah utuh).
  Future<void> _resetAndLoad() => _notifier.resetAndLoad();
  void _onRegionChanged(String? regionId) => _notifier.onRegionChanged(regionId);
  void _onBranchChanged(String? branchId) => _notifier.onBranchChanged(branchId);
  void _onConnectOnlyChanged(bool value) => _notifier.onConnectOnlyChanged(value);

  /// Scroll listener tetap di widget (butuh ScrollController). Guard + deteksi
  /// posisi mendekati bawah di sini; set flag + muat halaman → notifier.
  void _onScroll() {
    if (_loadingMore || _last || _initialLoading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 320) {
      _notifier.loadMore();
    }
  }

  /// Debounce tetap di widget (UI); nilai final diserahkan ke notifier.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _notifier.onSearchChanged(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(rmPerformanceProvider);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'Kinerja RM',
        leading: canPop
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.isWide(context)
                ? Responsive.contentMaxWidthFor(context)
                : double.infinity,
          ),
          child: Column(
            children: [
              _buildSearchAndFilters(topInset),
              Expanded(child: _buildList()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(double topInset) {
    final regions = _regions;
    final branches = _branches;
    return Container(
      color: AppColors.surfaceWhite,
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, topInset + AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: Column(
        children: [
          _buildStatCards(),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Cari nama atau NIP RM',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              filled: true,
              fillColor: AppColors.bgScreen,
              border: OutlineInputBorder(
                borderRadius: AppRadius.radiusMd,
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (regions.isNotEmpty || branches.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (regions.isNotEmpty)
                  Expanded(
                    child: _filterDropdown(
                      hint: 'Semua wilayah',
                      value: _regionId,
                      options: regions,
                      onChanged: _onRegionChanged,
                    ),
                  ),
                if (regions.isNotEmpty && branches.isNotEmpty)
                  const SizedBox(width: AppSpacing.sm),
                if (branches.isNotEmpty)
                  Expanded(
                    child: _filterDropdown(
                      hint: 'Semua cabang',
                      value: _branchId,
                      options: branches,
                      onChanged: _onBranchChanged,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Connect saja', style: TextStyle(fontSize: 12.5)),
              selected: _connectOnly,
              onSelected: _onConnectOnlyChanged,
              visualDensity: VisualDensity.compact,
              showCheckmark: false,
              selectedColor: AppColors.primaryNavy.withValues(alpha: 0.12),
              labelStyle: TextStyle(
                color: _connectOnly ? AppColors.primaryNavy : AppColors.textSecondary,
                fontWeight: _connectOnly ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(color: _connectOnly ? AppColors.primaryNavy : AppColors.border),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    // All cards track the active region/branch/search filter (server aggregates).
    final loading = _initialLoading;
    String v(int n) => loading ? '–' : '$n';
    // Row 1 — RM summary: total, how many have no pipeline yet, active pipelines, realisasi.
    final summary = <Widget>[
      _statCard(label: 'Total RM', value: v(_total), color: AppColors.primaryNavy),
      _statCard(
          label: 'RM Tanpa Pipeline',
          value: v(_rmsWithoutPipeline),
          color: AppColors.errorRed),
      _statCard(
          label: 'Pipeline Aktif',
          value: v(_filteredActivePipelines),
          color: AppColors.secondaryOrange),
      _statCard(
          label: 'Realisasi YTD',
          value: loading ? '–' : AppFormat.currencyShort(_filteredRealisasi),
          color: AppColors.successGreen),
    ];
    // Row 2 — pipeline stage breakdown across all matching RMs.
    final stages = <Widget>[
      _statCard(label: 'Pipeline P3', value: v(_p3), color: AppColors.grayStage),
      _statCard(label: 'Pipeline P2', value: v(_p2), color: AppColors.secondaryOrange),
      _statCard(label: 'Pipeline P1', value: v(_p1), color: AppColors.primaryNavy),
      _statCard(label: 'Pipeline Won', value: v(_won), color: AppColors.successGreen),
      _statCard(label: 'Pipeline Declined', value: v(_decline), color: AppColors.errorRed),
    ];
    return Column(
      children: [
        _kpiRow(summary),
        const SizedBox(height: AppSpacing.sm),
        _kpiRow(stages),
      ],
    );
  }

  /// A horizontally scrolling row of fixed-width KPI cards, so 4–5 cards stay
  /// readable on narrow screens instead of being squeezed by Expanded.
  Widget _kpiRow(List<Widget> cards) {
    // IntrinsicHeight + stretch: every card takes the height of the tallest one, so
    // a 2-line label (e.g. "RM Belum Punya Pipeline") doesn't make its card taller.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              SizedBox(width: 128, child: cards[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard({required String label, required String value, required Color color}) {
    return Container(
      // Match the BUMN/Broker KPI tiles: light-gray fill, bordered, no shadow.
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(label,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String hint,
    required String? value,
    required List<ScopeOffice> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusMd,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: Text(hint, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(hint, style: const TextStyle(fontSize: 13)),
            ),
            ...options.map((o) => DropdownMenuItem<String?>(
                  value: o.id,
                  child: Text(o.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_initialLoading) {
      return const SkeletonList(itemCount: 8);
    }
    if (_error != null && _items.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 60),
        ErrorStateView(message: _error!, onRetry: _resetAndLoad),
      ]);
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        color: AppColors.primaryNavy,
        onRefresh: _resetAndLoad,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text('Tidak ada RM yang cocok dengan filter ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ),
          ],
        ),
      );
    }
    // Desktop/tablet: two cards per row (header + footer stay full-width). Cards
    // vary in height (name/office can wrap), so pair them into Rows rather than a
    // fixed-extent grid to avoid overflow.
    final wide = Responsive.isWide(context);
    final rowCount = wide ? ((_items.length + 1) ~/ 2) : _items.length;
    return RefreshIndicator(
      color: AppColors.primaryNavy,
      onRefresh: _resetAndLoad,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(AppSpacing.lg),
        // +1 header row, +1 footer (loader / end-of-list).
        itemCount: rowCount + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text('$_total RM dalam cakupan',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            );
          }
          if (index == rowCount + 1) {
            return _buildFooter();
          }
          if (!wide) {
            return _buildRmCard(_items[index - 1]);
          }
          final left = (index - 1) * 2;
          final right = left + 1;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildRmCard(_items[left])),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: right < _items.length
                    ? _buildRmCard(_items[right])
                    : const SizedBox.shrink(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      // Non-scrolling skeleton placeholders for the next page (this sits inside
      // the outer ListView, so it must not be a scrollable on its own).
      return const Padding(
        padding: EdgeInsets.only(top: AppSpacing.sm),
        child: Column(
          children: [
            _RmSkeletonCard(),
            SizedBox(height: AppSpacing.sm),
            _RmSkeletonCard(),
          ],
        ),
      );
    }
    if (_last && _items.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
        child: Center(
          child: Text('— akhir daftar —',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ),
      );
    }
    return const SizedBox(height: AppSpacing.lg);
  }

  // Card design mirrors the Broker card: avatar + name/subtitle + chevron header,
  // then a bordered 3-column stats row. Full breakdown via the tap dialog.
  Widget _buildRmCard(RmStat rm) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level2],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusXl,
        child: InkWell(
          borderRadius: AppRadius.radiusXl,
          onTap: () => _showRmDetail(rm),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _avatar(rm.rmName ?? rm.rmId),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(rm.rmName ?? rm.rmId,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              ),
                              if (rm.isConnect) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryNavy.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: const Text('Connect',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryNavy)),
                                ),
                              ],
                            ],
                          ),
                          if (rm.officeLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(rm.officeLabel!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20, color: AppColors.grayStage),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Row(
                    children: [
                      _statColumn('Pipeline Aktif', '${rm.activePipelines}', AppColors.primaryNavy),
                      _statDivider(),
                      _statColumn('Target', AppFormat.currencyShort(rm.target), AppColors.textSecondary),
                      _statDivider(),
                      _statColumn('Realisasi', AppFormat.currencyShort(rm.realisasi), AppColors.secondaryOrange),
                      _statDivider(),
                      _statColumn('Won', '${rm.wonCount}', AppColors.successGreen),
                    ],
                  ),
                ),
                if (rm.target > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _targetProgress(rm),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Progress bar of realisasi (YTD) toward the RM's full-year target.
  Widget _targetProgress(RmStat rm) {
    final pct = (rm.targetProgress * 100).round();
    final reached = pct >= 100;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Realisasi vs Target',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            Text('$pct%',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: reached ? AppColors.successGreen : AppColors.primaryNavy)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: rm.targetProgress,
            minHeight: 6,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(
                reached ? AppColors.successGreen : AppColors.secondaryOrange),
          ),
        ),
      ],
    );
  }

  Widget _avatar(String name) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.primaryNavy.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusMd,
      ),
      child: Center(
        child: Text(_initials(name),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Widget _statColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 28, color: AppColors.border);

  /// Popup with the fuller per-RM breakdown when a card is tapped.
  void _showRmDetail(RmStat rm) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        // Cap the popup width so the detail isn't stretched wide on desktop.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: AppColors.navyBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline, color: AppColors.primaryNavy, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rm.rmName ?? rm.rmId,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        if (rm.officeLabel != null)
                          Text(rm.officeLabel!,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: AppSpacing.xl, color: AppColors.border),
              _detailRow('Total customer', '${rm.totalCustomers}'),
              _detailRow('Pipeline aktif', '${rm.activePipelines}'),
              _detailRow('Pipeline won (YTD)', '${rm.wonCount}'),
              _detailRow('Kunjungan (YTD)', '${rm.visitCountYtd}'),
              _detailRow('Realisasi (YTD)', AppFormat.rupiah(rm.realisasi)),
              _detailRow('Target (tahun)', AppFormat.rupiah(rm.target)),
              const SizedBox(height: AppSpacing.md),
              const Text('Target vs Realisasi per Bulan',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 220,
                child: FutureBuilder<List<DashboardMonthRow>>(
                  future: _repo?.getRmMonthly(rm.rmId),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(strokeWidth: 2)));
                    }
                    final months = snap.data ?? const <DashboardMonthRow>[];
                    if (months.isEmpty) {
                      return const Center(
                          child: Text('Belum ada data bulanan',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary)));
                    }
                    return SingleChildScrollView(child: _monthlyChart(months));
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primaryNavy),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  /// Per-month realisasi bar against its monthly target (target = yearly / 12).
  Widget _monthlyChart(List<DashboardMonthRow> months) {
    return Column(
      children: [
        for (final m in months)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                    width: 32,
                    child: Text(m.label,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary))),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppFormat.currencyShort(m.realisasi),
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w600)),
                          Text('/ ${AppFormat.currencyShort(m.target)}',
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: m.target > 0
                              ? (m.realisasi / m.target).clamp(0.0, 1.0)
                              : 0.0,
                          minHeight: 5,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              AppColors.secondaryOrange),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

}

/// A single static skeleton card used in the "load more" footer (non-scrolling).
class _RmSkeletonCard extends StatelessWidget {
  const _RmSkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget box(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.grayBg,
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          box(160, 12),
          const SizedBox(height: 12),
          Row(children: [box(70, 18), const SizedBox(width: 8), box(70, 18), const SizedBox(width: 8), box(70, 18)]),
        ],
      ),
    );
  }
}
