import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/bumn/bumn_repository.dart';
import '../../src/common/partner_kpi.dart';
import '../../utils/responsive.dart';
import '../providers/bumn_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/kpi_drilldown_sheet.dart';
import '../widgets/state_views.dart';
import 'bumn_tree_screen.dart';
import 'tender_report_screen.dart';

/// BUMN — read-only view over BUMN customers connected to the RM and their
/// pipelines. Mirrors the Broker screen: each BUMN is one card; tapping it opens
/// a sheet listing that BUMN's pipelines, which link back into the Customer flow.
class BumnScreen extends ConsumerStatefulWidget {
  const BumnScreen({super.key});

  @override
  ConsumerState<BumnScreen> createState() => _BumnScreenState();
}

class _BumnScreenState extends ConsumerState<BumnScreen> with RouteAware {
  final TextEditingController _searchController = TextEditingController();
  // Debounce the recursive ~515-node tree filter so it runs once the user pauses,
  // not on every keystroke.
  Timer? _searchDebounce;

  // Bootstrap sekali per mount (dulu guard `if (_future == null)` di State).
  bool _bootstrapped = false;

  static const List<Color> _avatarColors = [
    AppColors.primaryNavy,
    AppColors.secondaryOrange,
    AppColors.successGreen,
    AppColors.purpleAccent,
    Color(0xFF0891B2),
  ];

  // State bisnis/async dikelola BumnNotifier. Getter berikut memproksinya agar
  // seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  BumnState get _bs => ref.read(bumnProvider);
  BumnNotifier get _notifier => ref.read(bumnProvider.notifier);

  Future<List<BumnTreeCustomer>>? get _future => _bs.future;
  // KPI layar BUMN dari server: `total` = ekosistem master (±515), sisanya
  // (with-pipeline, won, premi, stages) mengikuti cakupan pemanggil.
  PartnerKpi? get _kpi => _bs.kpi;
  String get _query => _bs.query;
  // Manual expand/collapse (decoupled from row tap) + the selected node whose
  // subtree stats drive the KPI cards. Null selection → KPI keseluruhan.
  Set<String> get _expanded => _bs.expanded;
  Set<String> get _searchCollapsed => _bs.searchCollapsed;
  String? get _selectedId => _bs.selectedId;
  BumnTreeCustomer? get _selectedNode => _bs.selectedNode;
  // Selected-node card scope: true = node + descendants, false = this node only.
  bool get _includeDescendants => _bs.includeDescendants;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Bootstrap data sekali per mount (dulu `if (_future == null)` di State).
    // Sesi dibaca notifier lewat bumnRepoProvider → tak perlu context.
    if (!_bootstrapped) {
      _bootstrapped = true;
      // Tunda ke post-frame: memodifikasi provider (start menyetel state) SAAT
      // didChangeDependencies/build dilarang Riverpod ("Tried to modify a
      // provider while the widget tree was building").
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _notifier.start();
      });
    }
    final route = ModalRoute.of(context);
    if (route is PageRoute) MbisApp.routeObserver.subscribe(this, route);
  }

  @override
  void didPopNext() {
    if (_bootstrapped) _refresh();
  }

  @override
  void dispose() {
    MbisApp.routeObserver.unsubscribe(this);
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Aksi refresh/seleksi/expand → delegasi ke BumnNotifier (logika dipindah utuh).
  Future<void> _refresh() => _notifier.refresh();
  void _selectNode(BumnTreeCustomer n) => _notifier.selectNode(n);
  void _clearSelection() => _notifier.clearSelection();
  void _toggleExpand(String id) => _notifier.toggleExpand(id);

  List<({BumnTreeCustomer node, int depth})> _searchRows(
      List<BumnTreeCustomer> roots, String query) =>
      bumnSearchRows(roots, query, _searchCollapsed);

  Color _avatarColor(String id) => _avatarColors[id.hashCode.abs() % _avatarColors.length];

  Color _levelColor(String? level) {
    switch (level) {
      case 'Induk':
        return AppColors.primaryNavy;
      case 'Anak':
        return AppColors.secondaryOrange;
      case 'Cucu':
        return AppColors.successGreen;
      case 'Cicit':
        return AppColors.purpleAccent;
      default:
        return AppColors.grayStage;
    }
  }

  void _openPipelineInCustomer(BuildContext sheetContext, BumnLink link) {
    Navigator.of(sheetContext).pop();
    context.go('/customer/${link.customer.id}/pipeline/${link.pipelineId}');
  }

  /// Opens the pipeline sheet for a customer node (reuses the existing sheet).
  void _openNodeSheet(BumnTreeCustomer node) {
    _showBumnSheet(BumnView(
      bumn: BumnModel(id: node.id, name: node.name, strukturRelasi: node.level),
      links: node.links,
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(bumnProvider);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'BUMN',
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_outlined, color: AppColors.textPrimary),
            tooltip: 'Report Tender',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TenderReportScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.account_tree_outlined, color: AppColors.textPrimary),
            tooltip: 'Ekosistem BUMN',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BumnTreeScreen()),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<BumnTreeCustomer>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SkeletonList(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, topInset, AppSpacing.lg, AppSpacing.lg),
            );
          }
          if (snapshot.hasError) {
            return ErrorStateView(
                message: 'Gagal memuat data BUMN', onRetry: _refresh);
          }

          final roots = snapshot.data ?? const <BumnTreeCustomer>[];
          // Search keeps matches together with their ancestors (a "cucu" match is
          // shown under its induk, auto-expanded); tapping a row still just filters
          // the KPI cards. Otherwise show the full pruned tree.
          final searching = _query.isNotEmpty;
          final rows = searching ? _searchRows(roots, _query) : _visibleRows(roots);

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.isWide(context)
                    ? Responsive.contentMaxWidthFor(context)
                    : double.infinity,
              ),
              // KPI header is sticky (outside the scroll view); only the tree scrolls.
              child: Column(
                children: [
                  _buildHeader(topInset, roots),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.primaryNavy,
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        slivers: [
                          if (rows.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: EmptyStateView(
                                icon: searching
                                    ? Icons.search_off
                                    : Icons.account_balance_outlined,
                                title: searching
                                    ? 'BUMN tidak ditemukan'
                                    : 'Belum ada BUMN dengan customer',
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm),
                              // Lazy: build only the rows on screen. `rows` is already
                              // a flat (node, depth) list, so this is a drop-in swap.
                              sliver: SliverList.builder(
                                itemCount: rows.length,
                                itemBuilder: (context, i) {
                                  final row = rows[i];
                                  final id = row.node.id;
                                  // Mode pencarian: terbuka KECUALI ditutup manual.
                                  // Chevron-nya tetap tombol sungguhan di kedua mode —
                                  // dulu di mode pencarian ia hanya Icon mati yang
                                  // bentuknya sama persis, jadi terbaca sebagai rusak.
                                  return _treeRow(row.node, row.depth,
                                      expanded: searching
                                          ? !_searchCollapsed.contains(id)
                                          : _expanded.contains(id),
                                      onToggle: searching
                                          ? () => _notifier.toggleSearchCollapse(id)
                                          : () => _toggleExpand(id));
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(double topInset, List<BumnTreeCustomer> roots) {
    // Cards follow the selected node (its own or its subtree); tanpa pilihan
    // dipakai KPI keseluruhan dari server.
    final k = _selectedNode == null
        ? _kpi
        : (_includeDescendants ? _selectedNode!.subtree : _selectedNode!.own);
    String n(int? v) => v?.toString() ?? '–';
    // Rincian kartu (CR-06) memakai simpul yang SAMA dengan yang menyusun angkanya:
    // tanpa pilihan = seluruh pohon, dengan pilihan = simpul itu saja atau berikut
    // keturunannya, mengikuti sakelar "Node ini / + Turunan".
    final scopeNodes = _drilldownNodes(roots);
    // Baris 1 — "Total BUMN" adalah ukuran ekosistem master (±515) dan memang tetap
    // angka global; tiga sisanya (ber-Pipeline, Pernah Won, Realisasi Premi) sudah
    // ter-scope di server, jadi bagi RM angkanya bicara tentang miliknya sendiri.
    final summary = <Widget>[
      // Ekosistem master tidak ikut termuat layar ini (pohonnya sudah dipangkas ke
      // cabang yang punya customer), jadi kartu ini membuka layar Ekosistem BUMN
      // yang memang menyajikan ±515 simpul itu — bukan daftar separuh yang menyamar.
      _kpiTile('Total BUMN', n(k?.total), AppColors.primaryNavy,
          onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BumnTreeScreen()),
              )),
      _kpiTile('BUMN ber-Pipeline', n(k?.withPipeline), AppColors.secondaryOrange,
          onTap: () => _openNodeListSheet(
                'BUMN ber-Pipeline',
                scopeNodes.where((x) => x.links.isNotEmpty).toList(),
                'Belum ada BUMN dengan pipeline di cakupan Anda.',
              )),
      _kpiTile('BUMN Pernah Won', n(k?.everWon), AppColors.successGreen,
          onTap: () => _openNodeListSheet(
                'BUMN Pernah Won',
                scopeNodes
                    .where((x) => x.links.any((l) => l.stage == 'WON'))
                    .toList(),
                'Belum ada BUMN dengan pipeline WON di cakupan Anda.',
              )),
      _kpiTile('Realisasi Premi', k?.totalRealisasiPremiShort ?? '–',
          AppColors.primaryNavy,
          onTap: () => _openPipelineListSheet(
                'Realisasi Premi',
                scopeNodes,
                (l) => l.stage == 'WON',
                'Belum ada pipeline WON di cakupan Anda.',
              )),
    ];
    // Row 2 — pipeline stage breakdown across all BUMN-linked pipelines.
    final stages = <Widget>[
      _kpiTile('Pipeline P3', n(k?.p3), AppColors.grayStage,
          onTap: () => _openStageSheet(scopeNodes, 'P3')),
      _kpiTile('Pipeline P2', n(k?.p2), AppColors.secondaryOrange,
          onTap: () => _openStageSheet(scopeNodes, 'P2')),
      _kpiTile('Pipeline P1', n(k?.p1), AppColors.primaryNavy,
          onTap: () => _openStageSheet(scopeNodes, 'P1')),
      _kpiTile('Pipeline Won', n(k?.won), AppColors.successGreen,
          onTap: () => _openStageSheet(scopeNodes, 'WON')),
      _kpiTile('Pipeline Declined', n(k?.decline), AppColors.errorRed,
          onTap: () => _openStageSheet(scopeNodes, 'DECLINE')),
    ];

    return Container(
      color: AppColors.surfaceWhite,
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg, topInset + AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        children: [
          _kpiRow(summary),
          const SizedBox(height: AppSpacing.sm),
          _kpiRow(stages),
          if (_selectedNode != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InputChip(
                    label: Text(_selectedNode!.name,
                        style: const TextStyle(fontSize: 12)),
                    avatar: const Icon(Icons.filter_alt_outlined, size: 16),
                    onDeleted: _clearSelection,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    backgroundColor: AppColors.navyBg,
                    side: BorderSide.none,
                  ),
                  // Scope toggle: this node only vs node + descendants.
                  ChoiceChip(
                    label: const Text('Node ini', style: TextStyle(fontSize: 12)),
                    selected: !_includeDescendants,
                    onSelected: (_) => _notifier.setIncludeDescendants(false),
                    labelStyle: TextStyle(
                        fontSize: 12,
                        color: !_includeDescendants
                            ? Colors.white
                            : AppColors.textSecondary),
                    selectedColor: AppColors.primaryNavy,
                  ),
                  ChoiceChip(
                    label: const Text('+ Turunan', style: TextStyle(fontSize: 12)),
                    selected: _includeDescendants,
                    onSelected: (_) => _notifier.setIncludeDescendants(true),
                    labelStyle: TextStyle(
                        fontSize: 12,
                        color: _includeDescendants
                            ? Colors.white
                            : AppColors.textSecondary),
                    selectedColor: AppColors.primaryNavy,
                  ),
                  if (_selectedNode!.hasCustomer)
                    ActionChip(
                      avatar: const Icon(Icons.receipt_long_outlined, size: 16),
                      label: Text('Lihat ${_selectedNode!.pipelineCount} pipeline',
                          style: const TextStyle(fontSize: 12)),
                      onPressed: () => _openNodeSheet(_selectedNode!),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 44,
            child: TextField(
              controller: _searchController,
              // The field text updates instantly (via the controller); only the
              // expensive recursive filter is debounced 400ms after the last keystroke.
              onChanged: (v) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 400), () {
                  if (!mounted) return;
                  // Trim + drop-selection-on-non-empty dipindah ke notifier.
                  _notifier.setQuery(v);
                });
              },
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Cari BUMN...',
                hintStyle: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search,
                    size: 20, color: AppColors.grayStage),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close,
                            size: 18, color: AppColors.grayStage),
                        tooltip: 'Hapus pencarian',
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _searchController.clear();
                          _notifier.setQuery('');
                        },
                      ),
                filled: true,
                fillColor: AppColors.bgScreen,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.radiusMd,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.radiusMd,
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.radiusMd,
                  borderSide:
                      const BorderSide(color: AppColors.primaryNavy, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A horizontally scrolling row of fixed-width KPI tiles (so 4–5 cards stay
  /// readable on narrow screens instead of being squeezed).
  Widget _kpiRow(List<Widget> tiles) {
    // IntrinsicHeight + stretch: every tile takes the height of the tallest one, so
    // a 2-line label (e.g. "BUMN dengan Pipeline") doesn't make its card taller.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.sm),
              tiles[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _kpiTile(String label, String value, Color color,
      {VoidCallback? onTap}) {
    final tile = SizedBox(
      width: 128,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
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
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(label,
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return tile;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusMd,
        child: tile,
      ),
    );
  }

  // ── CR-06: kartu KPI dibuka jadi daftar (bottom banner) ─────────────────

  /// Simpul yang menyusun angka kartu saat ini — cerminan persis pilihan node +
  /// sakelar "+ Turunan" yang dipakai [_buildHeader].
  List<BumnTreeCustomer> _drilldownNodes(List<BumnTreeCustomer> roots) {
    final selected = _selectedNode;
    if (selected == null) return _flattenNodes(roots);
    return _includeDescendants ? _flattenNodes([selected]) : [selected];
  }

  List<BumnTreeCustomer> _flattenNodes(List<BumnTreeCustomer> nodes) {
    final out = <BumnTreeCustomer>[];
    void walk(BumnTreeCustomer n) {
      out.add(n);
      for (final c in n.children) {
        walk(c);
      }
    }

    for (final n in nodes) {
      walk(n);
    }
    return out;
  }

  /// Daftar simpul BUMN → detail simpulnya.
  void _openNodeListSheet(
      String title, List<BumnTreeCustomer> nodes, String empty) {
    showKpiDrilldownSheet(
      context,
      title: title,
      subtitle: 'Tekan satu baris untuk membuka detail BUMN-nya',
      emptyMessage: empty,
      rows: [
        for (final n in nodes)
          KpiDrilldownRow(
            title: n.name,
            subtitle: '${n.level ?? 'BUMN'} · ${n.links.length} pipeline',
            onTap: () => _openNodeSheet(n),
          ),
      ],
    );
  }

  /// Daftar pipeline → pipeline itu di dalam konteks customer-nya.
  ///
  /// Judul baris SELALU nama customer: daftar pipeline tanpa nama customer tidak
  /// menjawab pertanyaan siapa pun. Nama simpul BUMN dan tahapnya jadi keterangan.
  void _openPipelineListSheet(String title, List<BumnTreeCustomer> nodes,
      bool Function(BumnLink) where, String empty) {
    final rows = <KpiDrilldownRow>[];
    for (final n in nodes) {
      for (final l in n.links.where(where)) {
        rows.add(KpiDrilldownRow(
          title: l.customer.name,
          subtitle: '${n.name} · ${l.stage}',
          trailing: l.premiShort,
          onTap: () =>
              context.go('/customer/${l.customer.id}/pipeline/${l.pipelineId}'),
        ));
      }
    }
    showKpiDrilldownSheet(
      context,
      title: title,
      subtitle: 'Tekan satu baris untuk membuka pipeline-nya',
      emptyMessage: empty,
      rows: rows,
    );
  }

  void _openStageSheet(List<BumnTreeCustomer> nodes, String stage) {
    _openPipelineListSheet(
      'Pipeline $stage',
      nodes,
      (l) => l.stage == stage,
      'Belum ada pipeline BUMN pada tahap $stage di cakupan Anda.',
    );
  }

  Widget _dot(String? level) => Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.only(top: 4),
        decoration:
            BoxDecoration(color: _levelColor(level), shape: BoxShape.circle),
      );

  /// Tappable chip on a node that has customers → opens its pipeline sheet.
  Widget _pipelineBadge(BumnTreeCustomer n) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _openNodeSheet(n),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.navyBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            n.pipelineCount > 0 ? '${n.pipelineCount} pipeline' : 'Lihat',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryNavy),
          ),
        ),
      ),
    );
  }

  String _nodeSubtitle(BumnTreeCustomer n) {
    final parts = <String>[];
    if (n.level != null && n.level!.isNotEmpty) parts.add(n.level!);
    if (n.hasChildren) parts.add('${n.children.length} anak usaha');
    return parts.join(' · ');
  }

  /// Flattens the tree into the currently visible rows (respecting _expanded).
  List<({BumnTreeCustomer node, int depth})> _visibleRows(
      List<BumnTreeCustomer> roots) {
    final out = <({BumnTreeCustomer node, int depth})>[];
    void walk(List<BumnTreeCustomer> nodes, int depth) {
      for (final n in nodes) {
        out.add((node: n, depth: depth));
        if (n.hasChildren && _expanded.contains(n.id)) {
          walk(n.children, depth + 1);
        }
      }
    }

    walk(roots, 0);
    return out;
  }

  /// One tree row: chevron (expand, if any children) · dot · name (tap = select,
  /// updates the KPI cards) · pipeline badge (own pipelines). [onToggle] null →
  /// chevron is a static indicator; layar ini selalu mengirimnya, termasuk saat
  /// mencari, supaya tidak ada panah yang tampak bisa dipencet tapi diam saja.
  Widget _treeRow(BumnTreeCustomer n, int depth,
      {required bool expanded, VoidCallback? onToggle}) {
    final selected = _selectedId == n.id;
    return Container(
      color: selected ? AppColors.navyBg : null,
      padding: EdgeInsets.only(left: AppSpacing.lg + depth * 16.0, right: AppSpacing.lg),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: !n.hasChildren
                ? const SizedBox.shrink()
                : (onToggle == null
                    ? Icon(expanded ? Icons.expand_more : Icons.chevron_right,
                        size: 22, color: AppColors.grayStage)
                    : IconButton(
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        tooltip: expanded ? 'Tutup' : 'Buka anak',
                        icon: Icon(
                            expanded ? Icons.expand_more : Icons.chevron_right,
                            size: 22, color: AppColors.grayStage),
                        onPressed: onToggle,
                      )),
          ),
          _dot(n.level),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: InkWell(
              onTap: () => _selectNode(n),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.name,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.primaryNavy
                                : AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(_nodeSubtitle(n),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
          if (n.hasCustomer) ...[const SizedBox(width: AppSpacing.sm), _pipelineBadge(n)],
        ],
      ),
    );
  }

  Widget _avatar(BumnModel bumn, double size, double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _avatarColor(bumn.id),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          bumn.initials,
          style: TextStyle(
            fontSize: size * 0.32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── Bottom sheet: BUMN detail (pipelines) ───────────────────────────────
  void _showBumnSheet(BumnView view) {
    final bumn = view.bumn;
    String pQuery = '';
    String pStatus = 'ALL';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, AppSpacing.xxl),
                    children: [
                      Row(
                        children: [
                          _avatar(bumn, 52, 16),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bumn.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  bumn.subtitle,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      StatefulBuilder(
                        builder: (context, setSheet) {
                          final filtered = view.links.where((l) {
                            final okStatus = pStatus == 'ALL' || l.stage == pStatus;
                            final okQuery = pQuery.isEmpty ||
                                l.customer.name.toLowerCase().contains(pQuery.toLowerCase());
                            return okStatus && okQuery;
                          }).toList();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PIPELINE TERKAIT (${filtered.length})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (view.hasConnections) ...[
                                TextField(
                                  style: AppInput.fieldText,
                                  onChanged: (v) => setSheet(() => pQuery = v),
                                  decoration: InputDecoration(
                                    hintText: 'Cari nasabah...',
                                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.grayStage),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: [
                                      for (final f in const ['ALL', 'P3', 'P2', 'P1', 'WON', 'DECLINE'])
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: ChoiceChip(
                                            label: Text(f == 'ALL' ? 'Semua' : f),
                                            selected: pStatus == f,
                                            onSelected: (_) => setSheet(() => pStatus = f),
                                            labelStyle: TextStyle(
                                              fontSize: 12,
                                              color: pStatus == f ? Colors.white : AppColors.textSecondary,
                                            ),
                                            selectedColor: AppColors.primaryNavy,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                              ],
                              if (filtered.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    'Tidak ada pipeline yang cocok',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: AppColors.grayStage,
                                    ),
                                  ),
                                )
                              else
                                ...filtered.map((link) => _pipelineRow(sheetContext, link)),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _pipelineRow(BuildContext sheetContext, BumnLink link) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusLg,
        child: InkWell(
          borderRadius: AppRadius.radiusLg,
          onTap: () => _openPipelineInCustomer(sheetContext, link),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _stageBadge(link.stage),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              link.customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Premi: ${link.premiShort}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryNavy,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.grayStage),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stageBadge(String stage) {
    Color color;
    switch (stage) {
      case 'P3':
        color = AppColors.grayStage;
        break;
      case 'P2':
        color = AppColors.secondaryOrange;
        break;
      case 'P1':
        color = AppColors.primaryNavy;
        break;
      case 'WON':
        color = AppColors.successGreen;
        break;
      default:
        color = AppColors.errorRed;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        stage,
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}


/// Baris hasil pencarian pohon BUMN — fungsi murni supaya bisa diuji tanpa
/// merender layar.
///
/// Sebuah node ditampilkan bila namanya cocok ATAU ada keturunannya yang cocok
/// (leluhur dipertahankan sebagai jalur induk → anak → cucu). Begitu sebuah node
/// COCOK, SELURUH keturunannya ikut ditampilkan walau namanya sendiri tidak
/// mengandung kata kunci.
///
/// Dulu tidak begitu: anak disaring dengan kata kunci yang sama, jadi mencari nama
/// sebuah Induk memunculkan Induk itu SENDIRIAN — lengkap dengan chevron yang
/// terlihat "terbuka" padahal tidak ada apa pun di bawahnya. Persis itu yang
/// dilaporkan setelah membuat Induk baru beserta Anak barunya (2026-08-20).
///
/// [collapsed] berisi node yang ditutup manual; keturunannya tidak diturunkan.
List<({BumnTreeCustomer node, int depth})> bumnSearchRows(
    List<BumnTreeCustomer> roots, String query, Set<String> collapsed) {
  final q = query.toLowerCase();
  bool matches(BumnTreeCustomer n) => n.name.toLowerCase().contains(q);
  bool keep(BumnTreeCustomer n) => matches(n) || n.children.any(keep);
  final out = <({BumnTreeCustomer node, int depth})>[];
  // underMatch: sudah berada DI DALAM cabang yang cocok, jadi semua isinya relevan.
  void walk(List<BumnTreeCustomer> nodes, int depth, bool underMatch) {
    for (final n in nodes) {
      if (!underMatch && !keep(n)) continue;
      out.add((node: n, depth: depth));
      if (collapsed.contains(n.id)) continue;
      walk(n.children, depth + 1, underMatch || matches(n));
    }
  }

  walk(roots, 0, false);
  return out;
}
