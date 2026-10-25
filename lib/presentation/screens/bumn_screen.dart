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
import 'bumn_detail_screen.dart';
import 'bumn_tree_screen.dart';
import 'tender_report_screen.dart';
import '../../features/visit_rm/visit_rm_models.dart'
    show kDefaultKanwils, kDefaultRms;

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
  BumnFilter get _filter => _bs.filter;

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

  static String _bumnCategory(BumnTreeCustomer node) {
    final lvl = (node.level ?? '').toLowerCase();
    if (lvl.contains('induk')) return 'Induk';
    if (lvl.contains('anak') || lvl.contains('anper')) return 'Anper';
    if (lvl.contains('usaha') || lvl.contains('uper')) return 'Uper';
    if (lvl.contains('cucu') || lvl.contains('ciper') || lvl.contains('cicit')) return 'Ciper';
    return node.hasChildren ? 'Induk' : 'Anper';
  }

  static String _categoryLabel(String kat) {
    switch (kat) {
      case 'Induk':
        return 'Induk';
      case 'Anper':
        return 'Anak Perusahaan (Anper)';
      case 'Uper':
        return 'Usaha Perusahaan (Uper)';
      case 'Ciper':
        return 'Cucu Perusahaan (Ciper)';
      default:
        return kat;
    }
  }

  static (String kanwil, String kc, String rm) _resolveLinkPeng(BumnLink link) {
    if (link.kanwil != null && link.kc != null && link.rm != null) {
      return (link.kanwil!, link.kc!, link.rm!);
    }
    switch (link.pipelineId) {
      case 'bp1':
      case 'bp2':
      case 'bp6':
        return ('Kantor Wilayah 2', 'Jakarta Selatan', 'Siti Rahmawati');
      case 'bp3':
        return ('Kantor Wilayah 2', 'Jakarta Selatan', 'Andi Pratama');
      case 'bp4':
        return ('Kantor Wilayah 2', 'Bandung', 'Rina Kartika');
      case 'bp5':
        return ('Kantor Wilayah 1', 'Padang', 'Mohammad Ridwan Majid');
      case 'bp7':
        return ('Kantor Wilayah 1', 'Medan', 'Dedi Kurniawan');
      case 'bp8':
        return ('Kantor Wilayah 2', 'Pontianak', 'Yusuf Hidayat');
      default:
        final hash = (link.pipelineId.hashCode ^ link.customer.id.hashCode).abs();
        final rm = kDefaultRms[hash % kDefaultRms.length];
        String kanwil = 'Kantor Wilayah 1';
        for (final kw in kDefaultKanwils) {
          if (kw.cab.contains(rm.cab)) {
            kanwil = kw.name;
            break;
          }
        }
        return (link.kanwil ?? kanwil, link.kc ?? rm.cab, link.rm ?? rm.nama);
    }
  }

  bool _linkMatchesFilter(BumnLink link, BumnFilter filter) {
    if (filter.stage.isNotEmpty &&
        link.stage.toUpperCase() != filter.stage.toUpperCase()) {
      return false;
    }
    final (kanwil, kc, rm) = _resolveLinkPeng(link);
    if (filter.wil.isNotEmpty && kanwil != filter.wil) return false;
    if (filter.cab.isNotEmpty && kc != filter.cab) return false;
    if (filter.rm.isNotEmpty && rm != filter.rm) return false;
    return true;
  }

  bool _nodeOrKidsHasMatchingPipe(BumnTreeCustomer node, BumnFilter filter) {
    final pipeOn = filter.wil.isNotEmpty ||
        filter.cab.isNotEmpty ||
        filter.rm.isNotEmpty ||
        filter.stage.isNotEmpty;
    if (!pipeOn) return true;
    if (node.links.any((l) => _linkMatchesFilter(l, filter))) return true;
    return node.children.any((c) => _nodeOrKidsHasMatchingPipe(c, filter));
  }

  bool _nodeMatchesCategory(BumnTreeCustomer node, BumnFilter filter) {
    if (filter.kat.isEmpty) return true;
    return _bumnCategory(node) == filter.kat;
  }

  int _matchingBumnCount(List<BumnTreeCustomer> roots, BumnFilter filter) {
    final allNodes = _flattenNodes(roots);
    return allNodes
        .where((n) =>
            _nodeMatchesCategory(n, filter) &&
            _nodeOrKidsHasMatchingPipe(n, filter))
        .length;
  }

  List<({BumnTreeCustomer node, int depth})> _buildRows(
      List<BumnTreeCustomer> roots, String query, BumnFilter filter) {
    if (query.isNotEmpty) {
      final searched = bumnSearchRows(roots, query, _searchCollapsed);
      if (!filter.isActive) return searched;
      return searched.where((r) {
        return _nodeMatchesCategory(r.node, filter) &&
            _nodeOrKidsHasMatchingPipe(r.node, filter);
      }).toList();
    }

    if (filter.isActive) {
      if (filter.kat.isNotEmpty) {
        final all = _flattenNodes(roots);
        final filtered = all
            .where((n) =>
                _nodeMatchesCategory(n, filter) &&
                _nodeOrKidsHasMatchingPipe(n, filter))
            .toList();
        filtered.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return filtered.map((n) => (node: n, depth: 0)).toList();
      }

      return _visibleFilteredRows(roots, filter);
    }

    return _visibleRows(roots);
  }

  List<({BumnTreeCustomer node, int depth})> _visibleFilteredRows(
      List<BumnTreeCustomer> roots, BumnFilter filter) {
    final out = <({BumnTreeCustomer node, int depth})>[];
    void walk(List<BumnTreeCustomer> nodes, int depth) {
      for (final n in nodes) {
        if (!_nodeOrKidsHasMatchingPipe(n, filter)) continue;
        out.add((node: n, depth: depth));
        if (n.hasChildren && _expanded.contains(n.id)) {
          walk(n.children, depth + 1);
        }
      }
    }

    walk(roots, 0);
    return out;
  }

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
          final searching = _query.isNotEmpty;
          final isFilterActive = _filter.isActive;
          final rows = _buildRows(roots, _query, _filter);

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
                                icon: (searching || isFilterActive)
                                    ? Icons.search_off
                                    : Icons.account_balance_outlined,
                                title: (searching || isFilterActive)
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
                                  final isFlat = searching || _filter.kat.isNotEmpty;
                                  return _treeRow(row.node, row.depth,
                                      expanded: searching
                                          ? !_searchCollapsed.contains(id)
                                          : _expanded.contains(id),
                                      onToggle: isFlat
                                          ? (searching
                                              ? () => _notifier.toggleSearchCollapse(id)
                                              : null)
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
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE3E7EF)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: Color(0xFF5A6475)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) {
                            _searchDebounce?.cancel();
                            _searchDebounce =
                                Timer(const Duration(milliseconds: 400), () {
                              if (!mounted) return;
                              _notifier.setQuery(v);
                            });
                          },
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF15223B),
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Cari BUMN…',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF5A6475),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (_query.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchDebounce?.cancel();
                            _searchController.clear();
                            _notifier.setQuery('');
                          },
                          child: const Icon(Icons.close,
                              size: 18, color: Color(0xFF5A6475)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openFilterSheet(roots),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _filter.isActive
                          ? const Color(0xFFE9EEF6)
                          : const Color(0xFFF4F6FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _filter.isActive
                            ? const Color(0xFF0E2B53)
                            : const Color(0xFFE3E7EF),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune,
                          size: 18,
                          color: _filter.isActive
                              ? const Color(0xFF0E2B53)
                              : const Color(0xFF3A4557),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Filter',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: _filter.isActive
                                ? const Color(0xFF0E2B53)
                                : const Color(0xFF3A4557),
                          ),
                        ),
                        if (_filter.count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            height: 20,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0E2B53),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '${_filter.count}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_filter.isActive) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_filter.wil.isNotEmpty)
                    _filterChip(
                      _filter.wil,
                      () => _notifier.setFilter(_filter.copyWith(
                        wil: '',
                        cab: '',
                        rm: '',
                      )),
                    ),
                  if (_filter.cab.isNotEmpty)
                    _filterChip(
                      'KC ${_filter.cab}',
                      () => _notifier.setFilter(_filter.copyWith(
                        cab: '',
                        rm: '',
                      )),
                    ),
                  if (_filter.rm.isNotEmpty)
                    _filterChip(
                      _filter.rm,
                      () => _notifier.setFilter(_filter.copyWith(rm: '')),
                    ),
                  if (_filter.stage.isNotEmpty)
                    _filterChip(
                      'Stage ${_filter.stage}',
                      () => _notifier.setFilter(_filter.copyWith(stage: '')),
                    ),
                  if (_filter.kat.isNotEmpty)
                    _filterChip(
                      _categoryLabel(_filter.kat),
                      () => _notifier.setFilter(_filter.copyWith(kat: '')),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onRemove) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF0E2B53)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0E2B53),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 15, color: Color(0xFF0E2B53)),
          ),
        ],
      ),
    );
  }

  void _openFilterSheet(List<BumnTreeCustomer> roots) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final current = _filter;

            // Pilihan kanwil: dari kDefaultKanwils + data links
            final wilOptions = <String>['', 'Kantor Wilayah 1', 'Kantor Wilayah 2'];
            for (final n in _flattenNodes(roots)) {
              for (final l in n.links) {
                final (kw, _, _) = _resolveLinkPeng(l);
                if (kw.isNotEmpty && !wilOptions.contains(kw)) {
                  wilOptions.add(kw);
                }
              }
            }

            // Pilihan cabang (disaring berdasarkan kanwil terpilih jika ada)
            List<String> cabList = [];
            if (current.wil.isEmpty) {
              cabList = [
                'Padang',
                'Pekanbaru',
                'Medan',
                'Jakarta Selatan',
                'Bandung',
                'Pontianak',
              ];
            } else {
              for (final kw in kDefaultKanwils) {
                if (kw.name == current.wil) {
                  cabList = kw.cab;
                  break;
                }
              }
            }
            final cabOptions = <String>['', ...cabList];

            // Pilihan RM (disaring berdasarkan cabang terpilih jika ada)
            List<String> rmList = [];
            if (current.cab.isEmpty) {
              rmList = kDefaultRms.map((r) => r.nama).toSet().toList();
            } else {
              rmList = kDefaultRms
                  .where((r) => r.cab == current.cab)
                  .map((r) => r.nama)
                  .toList();
            }
            final rmOptions = <String>['', ...rmList];

            final countResult = _matchingBumnCount(roots, current);

            final rmHint = current.cab.isNotEmpty
                ? 'Menampilkan ${rmList.length} RM di KC ${current.cab}.'
                : 'Pilih kantor cabang untuk mempersempit daftar RM.';

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                      child: Column(
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFD5DCE7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(Icons.tune,
                                  size: 22, color: Color(0xFF15223B)),
                              const SizedBox(width: 10),
                              const Text(
                                'Filter BUMN',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF15223B),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  _notifier.resetFilter();
                                  setModalState(() {});
                                },
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFC25A17),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE3E7EF)),
                    // Body scrollable
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Kantor Wilayah
                            _buildDropdownField<String>(
                              label: 'Kantor Wilayah',
                              subtitle:
                                  'Menampilkan BUMN yang punya pipeline di kanwil ini.',
                              value: current.wil,
                              items: wilOptions.map((w) {
                                return DropdownMenuItem<String>(
                                  value: w,
                                  child: Text(
                                      w.isEmpty ? 'Semua kantor wilayah' : w),
                                );
                              }).toList(),
                              onChanged: (val) {
                                _notifier.setFilter(current.copyWith(
                                  wil: val ?? '',
                                  cab: '',
                                  rm: '',
                                ));
                                setModalState(() {});
                              },
                            ),
                            const SizedBox(height: 20),

                            // 2. Kantor Cabang
                            _buildDropdownField<String>(
                              label: 'Kantor Cabang',
                              subtitle:
                                  'Menampilkan BUMN yang punya pipeline di cabang ini.',
                              value: cabOptions.contains(current.cab)
                                  ? current.cab
                                  : '',
                              items: cabOptions.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c.isEmpty
                                      ? 'Semua kantor cabang'
                                      : 'KC $c'),
                                );
                              }).toList(),
                              onChanged: (val) {
                                final newCab = val ?? '';
                                final keepRm = current.rm.isNotEmpty &&
                                    kDefaultRms.any((r) =>
                                        r.nama == current.rm &&
                                        (newCab.isEmpty || r.cab == newCab));
                                _notifier.setFilter(current.copyWith(
                                  cab: newCab,
                                  rm: keepRm ? current.rm : '',
                                ));
                                setModalState(() {});
                              },
                            ),
                            const SizedBox(height: 20),

                            // 3. Nama RM
                            _buildDropdownField<String>(
                              label: 'Nama RM',
                              subtitle: rmHint,
                              value: rmOptions.contains(current.rm)
                                  ? current.rm
                                  : '',
                              items: rmOptions.map((r) {
                                final label = r.isEmpty
                                    ? (current.cab.isNotEmpty
                                        ? 'Semua RM di KC ${current.cab}'
                                        : 'Semua RM')
                                    : r;
                                return DropdownMenuItem<String>(
                                  value: r,
                                  child: Text(label),
                                );
                              }).toList(),
                              onChanged: (val) {
                                _notifier.setFilter(
                                    current.copyWith(rm: val ?? ''));
                                setModalState(() {});
                              },
                            ),
                            const SizedBox(height: 20),

                            // 4. Stage Pipeline
                            _buildDropdownField<String>(
                              label: 'Stage Pipeline',
                              subtitle:
                                  'Menampilkan BUMN yang punya pipeline pada stage ini.',
                              value: current.stage,
                              items: const [
                                DropdownMenuItem(
                                    value: '', child: Text('Semua stage')),
                                DropdownMenuItem(
                                    value: 'P3', child: Text('P3 · Prospek')),
                                DropdownMenuItem(
                                    value: 'P2', child: Text('P2 · Proses')),
                                DropdownMenuItem(
                                    value: 'P1', child: Text('P1 · Penerbitan')),
                                DropdownMenuItem(
                                    value: 'WON', child: Text('Won')),
                                DropdownMenuItem(
                                    value: 'DECLINE', child: Text('Decline')),
                              ],
                              onChanged: (val) {
                                _notifier.setFilter(
                                    current.copyWith(stage: val ?? ''));
                                setModalState(() {});
                              },
                            ),
                            const SizedBox(height: 20),

                            // 5. Kategori BUMN
                            _buildDropdownField<String>(
                              label: 'Kategori BUMN',
                              subtitle:
                                  'Induk, Anak Perusahaan, Usaha Perusahaan, atau Cucu Perusahaan.',
                              value: current.kat,
                              items: const [
                                DropdownMenuItem(
                                    value: '', child: Text('Semua kategori')),
                                DropdownMenuItem(
                                    value: 'Induk', child: Text('Induk')),
                                DropdownMenuItem(
                                    value: 'Anper',
                                    child: Text('Anak Perusahaan (Anper)')),
                                DropdownMenuItem(
                                    value: 'Uper',
                                    child: Text('Usaha Perusahaan (Uper)')),
                                DropdownMenuItem(
                                    value: 'Ciper',
                                    child: Text('Cucu Perusahaan (Ciper)')),
                              ],
                              onChanged: (val) {
                                _notifier.setFilter(
                                    current.copyWith(kat: val ?? ''));
                                setModalState(() {});
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Footer
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                      decoration: const BoxDecoration(
                        border:
                            Border(top: BorderSide(color: Color(0xFFE3E7EF))),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(sheetCtx).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0E2B53),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            'Tampilkan $countResult BUMN',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required String subtitle,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF3A4557),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF5A6475),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6FA),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDCE2EC)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Color(0xFF5A6475)),
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF15223B),
              ),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
              onTap: () {
                _selectNode(n);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BumnDetailScreen(node: n),
                  ),
                );
              },
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
