import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/responsive.dart';
import '../../src/app.dart';
import '../../src/customer/customer_repository.dart';
import '../../src/reference/reference_repository.dart';
import '../../src/dashboard/dashboard_repository.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/customer_list_provider.dart';
import '../widgets/customer_card.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/rm_picker_sheet.dart';
import '../widgets/state_views.dart';
import 'add_customer_screen.dart';
import 'add_pipeline_screen.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  /// When true, lists the logged-in agent's customers (agent portal) and hides
  /// the "Tambah" action — agents browse their book but don't create customers.
  final bool agentScoped;

  const CustomerListScreen({super.key, this.agentScoped = false});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen>
    with RouteAware {
  // First page kept small so the list paints fast; more streams in on scroll.
  static const int _pageSize = kCustomerPageSize;

  // UI-ephemeral (tetap di widget): scroll, kolom cari, debounce.
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // State bisnis/async dikelola CustomerListNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  CustomerListState get _cs => ref.read(customerListProvider);
  CustomerListNotifier get _notifier => ref.read(customerListProvider.notifier);

  List<CustomerListModel> get _items => _cs.items;
  int get _page => _cs.page;
  int get _totalPages => _cs.totalPages;
  int get _totalElements => _cs.totalElements;
  List<ParamRef> get _entityOptions => _cs.entityOptions;
  String? get _regionId => _cs.regionId;
  String? get _branchId => _cs.branchId;
  String get _searchTerm => _cs.searchTerm;
  String? get _entityFilter => _cs.entityFilter;
  bool get _hvcFilter => _cs.hvcFilter;
  String? get _stageFilter => _cs.stageFilter;
  String get _sortBy => _cs.sortBy;
  String get _sortDir => _cs.sortDir;
  CustomerKpi? get _kpi => _cs.kpi;
  bool get _initialLoading => _cs.initialLoading;
  String? get _error => _cs.error;
  bool get _canAddCustomer => _cs.canAddCustomer;
  List<ScopeOffice> get _regions => _cs.regions;
  List<ScopeOffice> get _branches => _cs.branches;

  // Supervisor (atasan) monitoring: filter RM/COB + kartu Target/Realisasi/Visit.
  bool get _isSupervisor => _cs.isSupervisor;
  String? get _rmId => _cs.rmId;
  String? get _rmName => _cs.rmName;
  String? get _cob => _cs.cob;
  List<DashboardCategoryStat> get _cobOptions => _cs.cobOptions;
  CustomerScopedSummary? get _summary => _cs.summary;
  bool get _summaryFailed => _cs.summaryFailed;
  bool get _summaryIsFallback => _cs.summaryIsFallback;

  /// Ada filter wilayah/cabang/RM aktif — satu-satunya filter yang TIDAK bisa
  /// diikuti jalur cadangan (endpoint dashboard hanya menerima `year`).
  bool get _scopeFilterActive =>
      _cs.regionId != null || _cs.branchId != null || _cs.rmId != null;

  /// Agents use a small, server-fixed book — keep it client-side; everyone else
  /// is server-paginated so a supervisor's customer base never loads all at once.
  bool get _isPaged => !widget.agentScoped;

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (samakan timing lama). Sesi &
    // izin tambah dibaca notifier dari sessionProvider — tak perlu context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start(agentScoped: widget.agentScoped);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) MbisApp.routeObserver.subscribe(this, route);
  }

  /// Returned from a customer detail (which may have edited/added data) — refresh.
  @override
  void didPopNext() => _refresh();

  @override
  void dispose() {
    MbisApp.routeObserver.unsubscribe(this);
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Aksi filter/paging → delegasi ke CustomerListNotifier (logika dipindah utuh).
  void _onHvcToggle() => _notifier.onHvcToggle();
  void _onEntityChanged(String? entity) => _notifier.onEntityChanged(entity);
  void _onStageChanged(String? stage) => _notifier.onStageChanged(stage);

  void _onSortChanged(String sortBy, String dir) =>
      _notifier.onSortChanged(sortBy, dir);
  void _onRegionChanged(String? regionId) => _notifier.onRegionChanged(regionId);
  void _onBranchChanged(String? branchId) => _notifier.onBranchChanged(branchId);
  void _onRmChanged(String? rmId, String? rmName) =>
      _notifier.onRmChanged(rmId, rmName);
  void _onCobChanged(String? cob) => _notifier.onCobChanged(cob);
  void _resetAllFilters() => _notifier.resetAllFilters();
  Future<void> _refresh() => _notifier.refresh();

  /// Pindah halaman + scroll daftar balik ke atas (scroll = urusan widget).
  void _goToPage(int page) {
    _notifier.goToPage(page);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
  }

  /// Debounce tetap di widget (UI); nilai final diserahkan ke notifier.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _notifier.onSearchChanged(value);
    });
  }

  /// Client-side filtering — used only for the agent (non-paged) path.
  List<CustomerListModel> get _visibleItems {
    if (_isPaged) return _items; // already server-filtered
    final q = _searchTerm.toLowerCase();
    return _items.where((c) {
      final matchesQuery = q.isEmpty || c.name.toLowerCase().contains(q);
      final matchesEntity =
          _entityFilter == null || c.entityCategory == _entityFilter;
      return matchesQuery && matchesEntity;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(customerListProvider);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final customers = _visibleItems;

    // Header KPI: the paged path fetches scoped, filter-aware counts from the
    // backend; the agent portal derives only the total from its visible set (the
    // agent customer feed carries no per-stage breakdown).
    final CustomerKpi? kpi = _isPaged
        ? _kpi
        : CustomerKpi(totalCustomer: customers.length);

    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'Customer',
        actions: !_canAddCustomer
            ? const []
            : [_buildTambahButton(), const SizedBox(width: AppSpacing.lg)],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.isWide(context)
                ? Responsive.contentMaxWidthFor(context)
                : double.infinity,
          ),
          child: RefreshIndicator(
            color: AppColors.primaryNavy,
            displacement: topInset,
            onRefresh: _refresh,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: _buildStatsAndSearch(topInset: topInset, kpi: kpi),
                ),
                if (_initialLoading)
                  // SkeletonList is a ListView (scrollable); hasScrollBody must be
                  // true, else SliverFillRemaining tries to measure a viewport's
                  // intrinsic height and throws.
                  const SliverFillRemaining(
                    hasScrollBody: true,
                    child: SkeletonList(itemCount: 6),
                  )
                else if (_error != null && _items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorStateView(message: _error!, onRetry: _refresh),
                  )
                else if (customers.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    // Desktop/tablet: two columns so more customers fit per screen.
                    // Cards vary in height (name can wrap to 2 lines), so pair them
                    // into Rows rather than a fixed-extent grid to avoid overflow.
                    sliver: Responsive.isWide(context)
                        ? SliverList.builder(
                            itemCount: ((customers.length + 1) ~/ 2) + 1,
                            itemBuilder: (context, rowIndex) {
                              final rowCount = (customers.length + 1) ~/ 2;
                              if (rowIndex == rowCount) return _buildFooter();
                              final left = rowIndex * 2;
                              final right = left + 1;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: CustomerCard(
                                      customer: customers[left],
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: right < customers.length
                                        ? CustomerCard(
                                            customer: customers[right],
                                          )
                                        : const SizedBox.shrink(),
                                  ),
                                ],
                              );
                            },
                          )
                        : SliverList.builder(
                            itemCount: customers.length + 1,
                            itemBuilder: (context, index) {
                              if (index == customers.length) {
                                return _buildFooter();
                              }
                              return CustomerCard(customer: customers[index]);
                            },
                          ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (!_isPaged || _totalPages <= 1) {
      return const SizedBox(height: AppSpacing.md);
    }
    return _buildPaginationBar();
  }

  // ── Kontrol halaman (pengganti infinite scroll) ─────────────────────────────

  /// Nomor halaman yang ditampilkan (0-based); -1 = elipsis. Selalu memuat
  /// halaman pertama, terakhir, dan jendela ±1 di sekitar halaman aktif,
  /// mis. `1 … 41 42 43 … 2500`.
  List<int> _pageWindow() {
    const span = 1;
    final shown = <int>{0, _totalPages - 1};
    for (int p = _page - span; p <= _page + span; p++) {
      if (p >= 0 && p < _totalPages) shown.add(p);
    }
    final sorted = shown.toList()..sort();
    final out = <int>[];
    int? prev;
    for (final p in sorted) {
      if (prev != null && p - prev > 1) out.add(-1);
      out.add(p);
      prev = p;
    }
    return out;
  }

  Widget _buildPaginationBar() {
    final start = _page * _pageSize + 1;
    final end = (_page + 1) * _pageSize < _totalElements
        ? (_page + 1) * _pageSize
        : _totalElements;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              _pageNavButton(
                icon: Icons.chevron_left,
                enabled: _page > 0,
                onTap: () => _goToPage(_page - 1),
              ),
              for (final p in _pageWindow())
                p == -1
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '…',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : _pageNumberButton(p),
              _pageNavButton(
                icon: Icons.chevron_right,
                enabled: _page < _totalPages - 1,
                onTap: () => _goToPage(_page + 1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$start–$end dari $_totalElements customer',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageNumberButton(int page) {
    final active = page == _page;
    return InkWell(
      onTap: active ? null : () => _goToPage(page),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minWidth: 34),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryNavy : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.primaryNavy : AppColors.border,
          ),
        ),
        child: Text(
          '${page + 1}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _pageNavButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textPrimary : AppColors.border,
        ),
      ),
    );
  }

  Widget _buildTambahButton() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () async {
          final created = await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddCustomerScreen()));
          if (!mounted || created == null) return;
          // Agents: chain straight into adding a pipeline for the new customer.
          // Their book is pipeline-scoped, so the customer only appears once it
          // has an agent-sourced pipeline.
          if (widget.agentScoped && created is CustomerListModel) {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AddPipelineScreen(
                  customerId: created.id,
                  customerName: created.name,
                ),
              ),
            );
            if (!mounted) return;
          }
          _refresh();
        },
        icon: const Icon(Icons.add, size: 16, color: Colors.white),
        label: const Text(
          'Tambah',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryNavy,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
        ),
      ),
    );
  }

  Widget _buildStatsAndSearch({
    required double topInset,
    required CustomerKpi? kpi,
  }) {
    String v(int? n) => n?.toString() ?? '–';
    // Total Customer + pipeline stage breakdown (P3/P2/P1/Won/Declined).
    // Tiap kartu adalah jalan masuk ke daftar yang menyusun angkanya (CR-06):
    // `stage` di bawah harus tetap cocok dengan nilai di [_kStageOptions], karena
    // keduanya bermuara ke filter tahap yang sama.
    final cards = <Widget>[
      _kpiCard('Total Customer', v(kpi?.totalCustomer), AppColors.primaryNavy),
      _kpiCard('Pipeline P3', v(kpi?.p3), AppColors.grayStage, stage: 'P3'),
      _kpiCard('Pipeline P2', v(kpi?.p2), AppColors.secondaryOrange,
          stage: 'P2'),
      _kpiCard('Pipeline P1', v(kpi?.p1), AppColors.primaryNavy, stage: 'P1'),
      _kpiCard('Pipeline Won', v(kpi?.won), AppColors.successGreen,
          stage: 'WON'),
      _kpiCard('Pipeline Declined', v(kpi?.decline), AppColors.errorRed,
          stage: 'DECLINE'),
    ];
    return Container(
      color: AppColors.surfaceWhite,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topInset + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Supervisor monitoring: Target / Realisasi / Visit cards + COB filter.
          // With no filter these match the front dashboard for the caller's scope.
          if (_isSupervisor) ...[
            _buildSupervisorCards(),
            const SizedBox(height: 14),
          ],
          // KPI cards: Total Customer + pipeline stage breakdown. Centered on
          // desktop; horizontally scrollable on mobile so they stay readable.
          if (Responsive.isWide(context))
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in cards) SizedBox(width: 120, child: c),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              // IntrinsicHeight + stretch: all cards share the tallest card's
              // height so a 2-line label doesn't make one card taller.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 10),
                      SizedBox(width: 120, child: cards[i]),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          // Search field + a single consolidated "Filter" button. All filters
          // (tipe customer, HVC, and for supervisors wilayah/cabang/RM) live in
          // the sheet the button opens — keeping the header uncluttered.
          _buildSearchRow(),
        ],
      ),
    );
  }

  /// Baris pencarian: kolom cari + chip filter aktif + tombol Filter.
  ///
  /// Chip filter aktif hidup di BARIS YANG SAMA dan mengambil ruangnya dari
  /// kolom cari, jadi setiap filter baru memendekkan kolom itu. Diletakkan
  /// terpisah di bawahnya, deretan chip mudah terlewat justru saat paling
  /// penting: ketika daftar tampak kosong karena filter yang orang lupa sedang
  /// menyala.
  ///
  /// Keduanya memakai [Expanded] dengan flex, bukan lebar tetap: apa pun jumlah
  /// filternya, barisnya tidak bisa overflow di layar HP. Kolom cari tidak
  /// pernah turun di bawah sekitar sepertiga baris, supaya tetap bisa diketik.
  Widget _buildSearchRow() {
    final aktif = _activeFilters;
    // 0 filter → kolom cari penuh. Bertambah → porsinya turun bertahap lalu
    // berhenti; chip selebihnya dijangkau dengan menggeser, bukan dengan
    // menyusutkan kolom cari sampai tak terpakai.
    final chipFlex = aktif.isEmpty ? 0 : (aktif.length >= 3 ? 4 : aktif.length + 1);
    final searchFlex = aktif.isEmpty ? 10 : (aktif.length >= 3 ? 5 : 8 - aktif.length);

    // Dengan tombol "Customer Saya" ikut hadir, satu baris tidak lagi muat di layar
    // HP: kolom cari menyusut sampai tinggal ikon kaca pembesar dan chip filter
    // aktif terpotong di tengah kata. Karena itu susunannya dipecah dua baris —
    // kolom cari selebar layar, kendali filter di bawahnya. Pemakai yang tidak
    // mendapat tombol itu tetap memakai susunan satu baris seperti semula.
    if (_showOwnCustomersButton) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchField(),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildFilterButton(),
                const SizedBox(width: 8),
                _buildOwnCustomersButton(),
                if (aktif.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: aktif.map(_activeFilterPill).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: searchFlex, child: _buildSearchField()),
          if (aktif.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              flex: chipFlex,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: aktif.map(_activeFilterPill).toList(),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          _buildFilterButton(),
        ],
      ),
    );
  }

  /// Tombol "Customer Saya" hanya berguna bila cakupan pemakai memang melampaui
  /// dirinya sendiri. Untuk RM cabang daftarnya sudah berisi miliknya saja, jadi
  /// tombolnya akan jadi hiasan yang tidak pernah mengubah apa pun.
  ///
  /// Syarat kedua: pemakainya memang MEMILIKI customer. BM/RO/ADMIN tidak pernah
  /// jadi pemilik customer, jadi bagi mereka tombol ini hanya akan mengosongkan
  /// daftar — kekacauan yang tidak menolong siapa pun.
  bool get _showOwnCustomersButton =>
      _cs.scopeWiderThanOwn && _cs.ownRmId != null && _canAddCustomer;

  /// Pintasan satu ketukan ke customer sendiri, di samping tombol Filter.
  ///
  /// Sengaja berdiri sendiri, bukan disembunyikan di dalam sheet filter: bagi RM
  /// yang berkantor di Kanwil inilah tampilan sehari-harinya, sedangkan isi sheet
  /// dipakai sesekali untuk menengok cabang lain.
  Widget _buildOwnCustomersButton() {
    final active = _cs.onlyOwnCustomers;
    return InkWell(
      onTap: () => _notifier.toggleOwnCustomers(),
      borderRadius: AppRadius.radiusFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.secondaryOrange : AppColors.bgScreen,
          borderRadius: AppRadius.radiusFull,
          border: Border.all(
            color: active ? AppColors.secondaryOrange : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.person : Icons.person_outline,
              size: 18,
              color: active ? Colors.white : AppColors.grayStage,
            ),
            const SizedBox(width: 6),
            Text(
              'Customer Saya',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Minimalist pill search: soft-gray field on the white header, borderless.
  Widget _buildSearchField() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusFull,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Cari nama customer',
          hintStyle: const TextStyle(color: AppColors.grayStage, fontSize: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.grayStage,
            size: 20,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 0,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.grayStage,
                  ),
                  splashRadius: 18,
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  /// The single "Filter" button beside the search bar. Shows a badge with the
  /// number of active filters and opens the consolidated filter sheet.
  Widget _buildFilterButton() {
    final count = _activeFilterCount;
    final active = count > 0;
    return InkWell(
      onTap: _openFilterSheet,
      borderRadius: AppRadius.radiusFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryNavy : AppColors.bgScreen,
          borderRadius: AppRadius.radiusFull,
          border: Border.all(
            color: active ? AppColors.primaryNavy : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.tune_rounded,
              size: 18,
              color: active ? Colors.white : AppColors.grayStage,
            ),
            const SizedBox(width: 6),
            Text(
              'Filter',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Count of filters applied through the sheet (drives the button badge).
  int get _activeFilterCount => _activeFilters.length;

  /// Tahap pipeline yang bisa dipilih, berikut labelnya. Urutannya mengikuti
  /// perjalanan pipeline (P3 paling awal) — sama dengan urutan kartu KPI di
  /// header, supaya yang dilihat orang di dua tempat itu tidak bertukar posisi.
  static const List<({String value, String label})> _kStageOptions = [
    (value: 'P3', label: 'P3'),
    (value: 'P2', label: 'P2'),
    (value: 'P1', label: 'P1'),
    (value: 'WON', label: 'Won'),
    (value: 'DECLINE', label: 'Decline'),
  ];

  /// Opsi pengurutan daftar (CR-08). `value`/`dir` dikirim apa adanya ke server,
  /// yang menerjemahkannya lewat daftar putih — jadi keempatnya harus persis
  /// cocok dengan `CustomerService.SORT_PROPERTIES`, kalau tidak dibalas 400.
  ///
  /// Sengaja TANPA "nilai pipeline": angka itu agregat yang dihitung setelah
  /// paging di server, bukan kolom customer. Mengurutkannya mengembalikan pola
  /// query lama yang membuat layar ini memakan puluhan detik pada data besar.
  static const List<({String value, String dir, String label})> _kSortOptions = [
    (value: 'name', dir: 'asc', label: 'Nama A-Z'),
    (value: 'name', dir: 'desc', label: 'Nama Z-A'),
    (value: 'createdAt', dir: 'desc', label: 'Terbaru'),
    (value: 'createdAt', dir: 'asc', label: 'Terlama'),
  ];

  static String _stageLabel(String value) => _kStageOptions
      .firstWhere((o) => o.value == value, orElse: () => (value: value, label: value))
      .label;

  /// Filter yang sedang aktif: label untuk ditampilkan + cara mematikannya.
  ///
  /// Satu daftar dipakai bersama oleh badge hitungan DAN deretan chip, jadi
  /// keduanya tidak bisa berbeda — dulu hitungannya ditulis terpisah dan setiap
  /// filter baru harus diingat untuk ditambahkan ke sana.
  List<({String label, VoidCallback clear})> get _activeFilters {
    final out = <({String label, VoidCallback clear})>[];
    if (_entityFilter != null) {
      // Yang disimpan filter adalah paramKey; yang dibaca orang paramValue.
      out.add((
        label: _entityOptions
            .firstWhere(
              (o) => o.key == _entityFilter,
              orElse: () => ParamRef(_entityFilter!, _entityFilter!),
            )
            .value,
        clear: () => _onEntityChanged(null),
      ));
    }
    if (_hvcFilter) {
      out.add((label: 'HVC', clear: _onHvcToggle));
    }
    if (_stageFilter != null) {
      out.add((
        label: _stageLabel(_stageFilter!),
        clear: () => _onStageChanged(null),
      ));
    }
    if (_regionId != null) {
      out.add((
        label: _officeName(_regions, _regionId!),
        clear: () => _onRegionChanged(null),
      ));
    }
    if (_branchId != null) {
      out.add((
        label: _officeName(_branches, _branchId!),
        clear: () => _onBranchChanged(null),
      ));
    }
    if (_rmId != null) {
      out.add((label: _rmName ?? 'RM terpilih', clear: () => _onRmChanged(null, null)));
    }
    return out;
  }

  String _officeName(List<ScopeOffice> options, String id) {
    for (final o in options) {
      if (o.id == id) return o.name;
    }
    return id;
  }

  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) =>
            SingleChildScrollView(child: _buildFilterSheet(setSheetState)),
      ),
    );
  }

  Widget _sheetSectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      );

  /// Body of the consolidated filter sheet. Selections apply live (the list
  /// underneath is hidden while the sheet is open); [setSheetState] refreshes
  /// the sheet's own controls to reflect the new selection.
  Widget _buildFilterSheet(void Function(void Function()) setSheetState) {
    void refresh(VoidCallback fn) {
      fn();
      setSheetState(() {});
    }

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: AppColors.primaryNavy,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Filter',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_activeFilterCount > 0)
                  TextButton(
                    onPressed: () => refresh(_resetAllFilters),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        color: AppColors.secondaryOrange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _sheetSectionLabel('Tipe Customer'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildFilterChip('Semua', null, refresh),
                // Nilai filter memakai paramKey, BUKAN paramValue. Customer
                // menyimpan entityCategory sebagai paramKey (mis. 'SWASTA'), baik
                // di basis data maupun pada jalur saring di aplikasi. Dulu chip ini
                // mengirim paramValue ('Swasta'), lalu dibandingkan sama persis,
                // sehingga lima dari sembilan pilihan selalu menghasilkan 0 baris.
                for (final o in _entityOptions)
                  _buildFilterChip(o.value, o.key, refresh),
              ],
            ),
            if (_isPaged) ...[
              const SizedBox(height: 18),
              _sheetSectionLabel('Tahap Pipeline'),
              const SizedBox(height: 4),
              const Text(
                'Menampilkan customer yang punya pipeline di tahap ini.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _stageChip('Semua', null, refresh),
                  for (final o in _kStageOptions)
                    _stageChip(o.label, o.value, refresh),
                ],
              ),
              const SizedBox(height: 18),
              _sheetSectionLabel('Kategori Khusus'),
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerLeft, child: _hvcChip(refresh)),
              const SizedBox(height: 18),
              _sheetSectionLabel('Urutkan'),
              const SizedBox(height: 4),
              const Text(
                'Berlaku untuk seluruh daftar, bukan hanya halaman ini.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in _kSortOptions) _sortChip(o, refresh),
                ],
              ),
            ],
            // Filter wilayah/cabang digerbangi KETERSEDIAAN cakupan, bukan nama
            // peran: RM yang berkantor di Kanwil (CR-18) boleh melihat seluruh
            // cabang di bawahnya padahal perannya tetap RM. Server yang menentukan
            // isi daftarnya lewat /api/dashboard/scope-offices — untuk RM cabang
            // daftar itu kosong, jadi bagian ini tidak muncul sama sekali.
            if (_regions.isNotEmpty || _branches.isNotEmpty) ...[
              const SizedBox(height: 18),
              _sheetSectionLabel('Wilayah & Cabang'),
              const SizedBox(height: 10),
              if (_regions.isNotEmpty)
                _filterDropdown(
                  hint: 'Semua wilayah',
                  value: _regionId,
                  options: _regions,
                  onChanged: (v) => refresh(() => _onRegionChanged(v)),
                ),
              if (_branches.isNotEmpty) ...[
                const SizedBox(height: 10),
                _filterDropdown(
                  hint: 'Semua cabang',
                  value: _branchId,
                  options: _branches,
                  onChanged: (v) => refresh(() => _onBranchChanged(v)),
                ),
              ],
            ],
            if (_isSupervisor) ...[
              const SizedBox(height: 18),
              _sheetSectionLabel('Nama RM'),
              const SizedBox(height: 10),
              _buildRmPickerField(onDone: () => setSheetState(() {})),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.radiusMd,
                  ),
                ),
                child: const Text(
                  'Tutup',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Supervisor monitoring cards + COB/RM filters ────────────────────────────
  Widget _buildSupervisorCards() {
    final s = _summary;
    String count(int? v) => v?.toString() ?? '–';
    // Analysis header: a wide Target-vs-Realisasi progress bar (with the COB
    // picker embedded, like the dashboard) beside a compact Visit card, in a
    // 3:1 split. IntrinsicHeight gives the stretch Row a bounded cross-axis
    // extent inside the vertically-unbounded scroll view above.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: _buildTargetRealisasiBar(s)),
          const SizedBox(width: 10),
          Expanded(
            flex: 1,
            child: _summaryCard(
              'Visit bln ini',
              count(s?.visitCountMtd),
              Icons.location_on_rounded,
              AppColors.secondaryOrange,
              subtitle: s == null ? null : 'Total YTD ${s.visitCountYtd}',
            ),
          ),
        ],
      ),
    );
  }

  /// Target-vs-Realisasi progress bar with the COB picker embedded in its
  /// header, mirroring the front dashboard's "Pencapaian Target" card.
  Widget _buildTargetRealisasiBar(CustomerScopedSummary? s) {
    // Gagal memuat ≠ realisasi nol. Tanpa cabang ini kartu menggambar "Rp 0 / 0%"
    // untuk keduanya, dan masalah deploy/jaringan menyaru jadi bug data.
    if (_summaryFailed) return _buildTargetRealisasiUnavailable();
    final double target = s?.premiTarget ?? 0;
    final double real = s?.realisasi ?? 0;
    // Same business rule as the dashboard's DashboardCategoryStat.progress:
    // target 0 with some realisasi counts as 100% (not 0%), so the bar still
    // fills and shows its gradient instead of appearing empty/colourless.
    final rawPct = target > 0 ? real / target : (real > 0 ? 1.0 : 0.0);
    final pct = rawPct.clamp(0.0, 1.0);
    String money(double? v) => v == null ? '–' : AppFormat.currencyShort(v);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: _cobOptions.isNotEmpty
                    ? _buildCobDropdownInline()
                    : const Text(
                        'Realisasi vs Target',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryNavy,
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
          const SizedBox(height: 10),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.grayBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => Align(
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
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Realisasi ${money(real)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Target ${money(target)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          // Angka cadangan dari dashboard mengikuti COB, tetapi endpoint-nya tak
          // menerima wilayah/cabang/RM. Wajib dinyatakan — dan tepat bagian
          // MANA yang belum ikut: angka yang diam saat difilter tanpa
          // keterangan akan disangka bug perhitungan.
          if (_summaryIsFallback) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _scopeFilterActive
                        ? 'Angka lingkup penuh — filter wilayah/cabang/RM belum diterapkan'
                        : 'Angka lingkup penuh (sumber cadangan dashboard)',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Kartu Target/Realisasi saat `customer-summary` gagal dimuat.
  ///
  /// Bentuknya sengaja sama persis dengan kartu normal (ukuran, border, dropdown
  /// COB tetap bisa dipakai) supaya tata letak baris kartu tidak melompat —
  /// hanya bar dan angkanya diganti pesan yang jujur beserta tombol ulang.
  Widget _buildTargetRealisasiUnavailable() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: _cobOptions.isNotEmpty
                    ? _buildCobDropdownInline()
                    : const Text(
                        'Realisasi vs Target',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryNavy,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              const Text(
                '–',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Gagal memuat target & realisasi',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _notifier.reloadSummary(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Coba lagi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryNavy,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Borderless COB / target-category picker embedded in the bar's header.
  Widget _buildCobDropdownInline() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: _cob,
        isDense: true,
        isExpanded: true,
        borderRadius: BorderRadius.circular(8),
        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryNavy),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryNavy,
        ),
        hint: const Text(
          'Semua COB',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryNavy,
          ),
        ),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('Semua COB', overflow: TextOverflow.ellipsis),
          ),
          ..._cobOptions
              .where((c) => c.category != 'TOTAL')
              .map((c) => DropdownMenuItem<String?>(
                    value: c.category,
                    child: Text(c.label, overflow: TextOverflow.ellipsis),
                  )),
        ],
        onChanged: _onCobChanged,
      ),
    );
  }

  Widget _summaryCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRmPickerField({VoidCallback? onDone}) {
    final label = _rmName ?? 'Semua RM';
    final selected = _rmId != null;
    return InkWell(
      onTap: () => _openRmPicker(onDone: onDone),
      borderRadius: AppRadius.radiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgScreen,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.person_search_rounded,
              size: 18,
              color: AppColors.grayStage,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            if (selected)
              GestureDetector(
                onTap: () {
                  _onRmChanged(null, null);
                  onDone?.call();
                },
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.grayStage,
                ),
              )
            else
              const Icon(
                Icons.expand_more_rounded,
                size: 18,
                color: AppColors.grayStage,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openRmPicker({VoidCallback? onDone}) async {
    final dashRepo = ref.read(dashboardRepoProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RmPickerSheet(
        repo: dashRepo,
        regionId: _regionId,
        branchId: _branchId,
        onSelected: (rm) {
          _onRmChanged(rm?.id, rm?.name);
          onDone?.call();
        },
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
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(hint, style: const TextStyle(fontSize: 13)),
            ),
            ...options.map(
              (o) => DropdownMenuItem<String?>(
                value: o.id,
                child: Text(
                  o.name,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// A compact fixed-width KPI card for the horizontally scrolling header row.
  ///
  /// [stage] = tahap yang dipasang saat kartu ditekan (CR-06); `null` untuk kartu
  /// Total Customer, yang justru MELEPAS filter tahap sehingga daftar kembali ke
  /// himpunan penuh yang dihitung kartu itu. Filter yang sama dipakai chip di
  /// sheet, jadi menekan kartu = memilih chip: daftar, angka, dan chip filter
  /// aktif bergerak bersama, dan mematikannya kembali cukup dengan menekan ulang.
  ///
  /// Di jalur non-paged (feed customer agent) kartu dibiarkan mati: hitungannya
  /// tidak sadar-tahap, jadi tautan ke daftar per tahap akan menjanjikan sesuatu
  /// yang tidak bisa ditepati.
  Widget _kpiCard(String label, String value, Color valueColor,
          {String? stage}) =>
      _buildHeaderStatCard(
        label: label,
        value: value,
        valueColor: valueColor,
        selected: stage != null && _stageFilter == stage,
        onTap: _isPaged ? () => _onStageChanged(stage) : null,
      );

  Widget _buildHeaderStatCard({
    required String label,
    required String value,
    required Color valueColor,
    VoidCallback? onTap,
    bool selected = false,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: selected ? AppColors.navyBg : AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: selected ? AppColors.primaryNavy : AppColors.border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    // InkWell dibungkus Material agar riak sentuhnya terlihat di atas kartu yang
    // sudah punya latar sendiri; tanpa itu kartu terasa mati walau bisa ditekan.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusMd,
        child: card,
      ),
    );
  }

  /// HVC toggle chip (separate from the entity filter; combinable).
  Widget _hvcChip(void Function(VoidCallback) refresh) {
    final selected = _hvcFilter;
    return GestureDetector(
      onTap: () => refresh(_onHvcToggle),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.secondaryOrange : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? AppColors.secondaryOrange : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: 15,
              color: selected ? Colors.white : AppColors.secondaryOrange,
            ),
            const SizedBox(width: 4),
            Text(
              'HVC',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String? entityValue,
    void Function(VoidCallback) refresh,
  ) {
    final isSelected = _entityFilter == entityValue;
    return GestureDetector(
      onTap: () => refresh(() => _onEntityChanged(entityValue)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Chip tahap pipeline di dalam sheet. Bentuknya sengaja sama persis dengan
  /// [_buildFilterChip] — dua deret chip bersebelahan yang berbeda gaya akan
  /// terbaca sebagai dua jenis kontrol yang berbeda perilakunya, padahal sama.
  Widget _stageChip(
    String label,
    String? stageValue,
    void Function(VoidCallback) refresh,
  ) {
    final isSelected = _stageFilter == stageValue;
    return GestureDetector(
      onTap: () => refresh(() => _onStageChanged(stageValue)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Chip pilihan urutan di dalam sheet (CR-08). Bentuknya sama dengan
  /// [_stageChip] karena perilakunya sama: sekali ketuk, langsung berlaku.
  ///
  /// Bedanya satu dan disengaja — chip ini TIDAK bisa dimatikan dengan
  /// mengetuknya lagi. Selalu ada satu urutan yang berlaku, jadi "tanpa urutan"
  /// bukan keadaan yang bisa dipilih, dan chip yang bisa dimatikan akan
  /// menjanjikan sesuatu yang tidak ada.
  Widget _sortChip(
    ({String value, String dir, String label}) option,
    void Function(VoidCallback) refresh,
  ) {
    final isSelected = _sortBy == option.value && _sortDir == option.dir;
    return GestureDetector(
      onTap: () => refresh(() => _onSortChanged(option.value, option.dir)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryNavy : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppColors.primaryNavy : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          option.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Satu chip filter aktif di header: labelnya + silang untuk mematikannya.
  Widget _activeFilterPill(({String label, VoidCallback clear}) f) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: AppColors.navyBg,
          borderRadius: AppRadius.radiusFull,
          border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              f.label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryNavy,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 13, color: AppColors.primaryNavy),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              splashRadius: 12,
              tooltip: 'Hapus filter ${f.label}',
              onPressed: f.clear,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final filtering = _searchTerm.isNotEmpty || _entityFilter != null;
    return EmptyStateView(
      icon: filtering ? Icons.search_off : Icons.people_outline,
      title: 'Tidak ada customer ditemukan',
      subtitle: filtering
          ? 'Coba ubah pencarian atau filter entitas Anda.'
          : (widget.agentScoped
                ? 'Belum ada customer pada portofolio Anda.'
                : 'Tekan "Tambah" untuk menambahkan customer baru.'),
    );
  }
}
