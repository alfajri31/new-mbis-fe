import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../src/app.dart';
import '../../src/customer/customer_repository.dart';
import '../../src/reference/reference_repository.dart';
import '../../src/dashboard/dashboard_repository.dart';
import '../providers/customer_list_provider.dart';
import '../widgets/customer_card.dart';
import '../widgets/glass_app_bar.dart';
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
  CustomerKpi? get _kpi => _cs.kpi;
  bool get _initialLoading => _cs.initialLoading;
  String? get _error => _cs.error;
  bool get _canAddCustomer => _cs.canAddCustomer;
  List<ScopeOffice> get _regions => _cs.regions;
  List<ScopeOffice> get _branches => _cs.branches;

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
  void _onRegionChanged(String? regionId) => _notifier.onRegionChanged(regionId);
  void _onBranchChanged(String? branchId) => _notifier.onBranchChanged(branchId);
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
                SliverToBoxAdapter(child: _buildFilterChipsBar()),
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
    // Total Customer + pipeline stage breakdown (P3/P2/P1/Won/Declined). Six cards
    // scroll horizontally so they stay readable on narrow screens.
    final cards = <Widget>[
      _kpiCard('Total Customer', v(kpi?.totalCustomer), AppColors.primaryNavy),
      _kpiCard('Pipeline P3', v(kpi?.p3), AppColors.grayStage),
      _kpiCard('Pipeline P2', v(kpi?.p2), AppColors.secondaryOrange),
      _kpiCard('Pipeline P1', v(kpi?.p1), AppColors.primaryNavy),
      _kpiCard('Pipeline Won', v(kpi?.won), AppColors.successGreen),
      _kpiCard('Pipeline Declined', v(kpi?.decline), AppColors.errorRed),
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
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // IntrinsicHeight + stretch: all cards share the tallest card's height so
            // a 2-line label doesn't make one card taller than the rest.
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
          // Minimalist pill search: soft-gray field on the white header, borderless,
          // rounded icons — clean and professional.
          Container(
            decoration: const BoxDecoration(
              color: AppColors.bgScreen,
              borderRadius: AppRadius.radiusFull,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Cari nama customer',
                hintStyle: const TextStyle(
                  color: AppColors.grayStage,
                  fontSize: 14,
                ),
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
          ),
          // Region/branch filter — supervisors only (RM/agent get an empty list,
          // so the row collapses). The header cards above track these too.
          if (_regions.isNotEmpty || _branches.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (_regions.isNotEmpty)
                  Expanded(
                    child: _filterDropdown(
                      hint: 'Semua wilayah',
                      value: _regionId,
                      options: _regions,
                      onChanged: _onRegionChanged,
                    ),
                  ),
                if (_regions.isNotEmpty && _branches.isNotEmpty)
                  const SizedBox(width: 10),
                if (_branches.isNotEmpty)
                  Expanded(
                    child: _filterDropdown(
                      hint: 'Semua cabang',
                      value: _branchId,
                      options: _branches,
                      onChanged: _onBranchChanged,
                    ),
                  ),
              ],
            ),
          ],
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

  Widget _buildFilterChipsBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
          bottom: BorderSide(color: AppColors.border, width: 1.0),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: [
            _buildFilterChip('Semua', null),
            // Entity-category chips from master parameter ENTITY_CATEGORY.
            for (final o in _entityOptions) ...[
              const SizedBox(width: 8),
              _buildFilterChip(o.value, o.value),
            ],
            // Separator + HVC toggle (combinable with the entity filter).
            Container(
              width: 1,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: AppColors.border,
            ),
            _hvcChip(),
          ],
        ),
      ),
    );
  }

  /// A compact fixed-width KPI card for the horizontally scrolling header row.
  Widget _kpiCard(String label, String value, Color valueColor) =>
      _buildHeaderStatCard(label: label, value: value, valueColor: valueColor);

  Widget _buildHeaderStatCard({
    required String label,
    required String value,
    required Color valueColor,
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
  }

  /// HVC toggle chip (separate from the entity filter; combinable).
  Widget _hvcChip() {
    final selected = _hvcFilter;
    return GestureDetector(
      onTap: _onHvcToggle,
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

  Widget _buildFilterChip(String label, String? entityValue) {
    final isSelected = _entityFilter == entityValue;
    return GestureDetector(
      onTap: () => _onEntityChanged(entityValue),
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
