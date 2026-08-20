import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../core/providers/repository_providers.dart';
import '../../src/app.dart';
import '../../src/broker/broker_repository.dart';
import '../../src/common/partner_kpi.dart';
import '../../utils/responsive.dart';
import '../providers/broker_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/kpi_drilldown_sheet.dart';
import '../widgets/state_views.dart';

/// S-201 — Broker.
///
/// Brokers are a *read-only* view over customer-owned pipelines: the data is
/// derived in [BrokerRepository], and every connected pipeline links back into
/// the Customer flow (Customer Detail → Pipeline Detail) so the pipeline is
/// always seen in the context of the customer that owns it.
class BrokerScreen extends ConsumerStatefulWidget {
  const BrokerScreen({super.key});

  @override
  ConsumerState<BrokerScreen> createState() => _BrokerScreenState();
}

class _BrokerScreenState extends ConsumerState<BrokerScreen> with RouteAware {
  // UI-ephemeral (tetap di widget): kolom cari.
  final TextEditingController _searchController = TextEditingController();

  // State DATA/LOADING/search dikelola BrokerNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  BrokerState get _bs => ref.read(brokerProvider);
  BrokerNotifier get _notifier => ref.read(brokerProvider.notifier);

  Future<List<BrokerView>>? get _future => _bs.future;
  PartnerKpi? get _kpi => _bs.kpi; // global broker KPIs (total 150, with-pipeline, won, premi, stages)
  String get _query => _bs.query;

  // Avatar background rotation per design.md §3.8 (avatar broker colors).
  static const List<Color> _avatarColors = [
    AppColors.primaryNavy,
    AppColors.secondaryOrange,
    AppColors.successGreen,
    AppColors.purpleAccent,
    Color(0xFF0891B2),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pemuatan data (load-once) + KPI dipindah ke BrokerNotifier.start(). Timing
    // tetap di didChangeDependencies agar frame pertama sudah punya future
    // (skeleton), sama seperti sebelumnya. Sesi dibaca notifier via provider
    // (brokerRepoProvider → apiClientProvider), jadi tak perlu context di sini.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
    final route = ModalRoute.of(context);
    if (route is PageRoute) MbisApp.routeObserver.subscribe(this, route);
  }

  /// Refresh when returning from a pushed screen (e.g. after adding a broker pipeline).
  @override
  void didPopNext() {
    if (_future != null) _refresh();
  }

  @override
  void dispose() {
    MbisApp.routeObserver.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  // Refresh (pull-to-refresh / retry) → delegasi ke BrokerNotifier (logika utuh).
  Future<void> _refresh() => _notifier.refresh();

  List<BrokerView> _applyQuery(List<BrokerView> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((v) =>
            v.broker.name.toLowerCase().contains(q) ||
            v.broker.code.toLowerCase().contains(q))
        .toList();
  }

  Color _avatarColor(String brokerId) =>
      _avatarColors[brokerId.hashCode.abs() % _avatarColors.length];

  // ─────────────────────────────────────────────────────────────────────
  // Navigation: open a connected pipeline inside its customer context.
  // Stack becomes Broker → Customer Detail → Pipeline Detail, so backing out
  // of the pipeline lands on the customer it belongs to.
  // ─────────────────────────────────────────────────────────────────────
  void _openPipelineInCustomer(BuildContext sheetContext, BrokerLink link) {
    Navigator.of(sheetContext).pop(); // close the bottom sheet first
    // Nested location: customer detail with the pipeline stacked on top, so the
    // URL survives a refresh and backing out of the pipeline lands on the
    // customer it belongs to.
    context.go('/customer/${link.customer.id}/pipeline/${link.pipelineId}');
  }

  void _openCustomer(String customerId) {
    context.go('/customer/$customerId');
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(brokerProvider);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'Broker'),
      body: FutureBuilder<List<BrokerView>>(
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
                message: 'Gagal memuat data broker', onRetry: _refresh);
          }

          final all = snapshot.data ?? const <BrokerView>[];
          final visible = _applyQuery(all);

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.isWide(context)
                    ? Responsive.contentMaxWidthFor(context)
                    : double.infinity,
              ),
              // KPI header is sticky (outside the scroll view); only the list scrolls.
              child: Column(
                children: [
                  _buildHeader(topInset, all),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.primaryNavy,
                      onRefresh: _refresh,
                      child: CustomScrollView(
                        slivers: [
                          if (visible.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: EmptyStateView(
                                icon: _query.isNotEmpty
                                    ? Icons.search_off
                                    : Icons.handshake_outlined,
                                title: _query.isNotEmpty
                                    ? 'Broker tidak ditemukan'
                                    : 'Tidak ada pipeline yang berasal dari Broker',
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              // Desktop/tablet: two columns so more brokers fit per screen.
                              sliver: Responsive.isWide(context)
                                  ? SliverList.separated(
                                      itemCount: (visible.length + 1) ~/ 2,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: AppSpacing.md),
                                      itemBuilder: (_, rowIndex) {
                                        final left = rowIndex * 2;
                                        final right = left + 1;
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                                child: _buildBrokerCard(
                                                    visible[left])),
                                            const SizedBox(width: AppSpacing.md),
                                            Expanded(
                                              child: right < visible.length
                                                  ? _buildBrokerCard(
                                                      visible[right])
                                                  : const SizedBox.shrink(),
                                            ),
                                          ],
                                        );
                                      },
                                    )
                                  : SliverList.separated(
                                      itemCount: visible.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: AppSpacing.md),
                                      itemBuilder: (_, i) =>
                                          _buildBrokerCard(visible[i]),
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

  // ── Header: summary chips + search ──────────────────────────────────────
  Widget _buildHeader(double topInset, List<BrokerView> all) {
    final k = _kpi;
    String n(int? v) => v?.toString() ?? '–';
    // Row 1 — the broker universe (global): total in the 150-broker master list,
    // how many already have a pipeline / have ever WON, and total realisasi premi.
    //
    // Tiap kartu dibuka jadi daftar (CR-06). Daftarnya dirakit dari `all` — data
    // yang SUDAH dimuat, bukan `visible` yang tersaring kolom cari — supaya jumlah
    // barisnya cocok dengan angka pada kartunya; kartu KPI datang dari server dan
    // memang tidak mengikuti kata kunci pencarian.
    final summary = <Widget>[
      _kpiTile('Total Broker', n(k?.total), AppColors.primaryNavy,
          onTap: _openAllBrokersSheet),
      _kpiTile('Broker ber-Pipeline', n(k?.withPipeline), AppColors.secondaryOrange,
          onTap: () => _openBrokerListSheet(
                'Broker ber-Pipeline',
                all.where((v) => v.links.isNotEmpty).toList(),
                'Belum ada broker dengan pipeline di cakupan Anda.',
              )),
      _kpiTile('Broker Pernah Won', n(k?.everWon), AppColors.successGreen,
          onTap: () => _openBrokerListSheet(
                'Broker Pernah Won',
                all
                    .where((v) => v.links.any((l) => l.stage == 'WON'))
                    .toList(),
                'Belum ada broker dengan pipeline WON di cakupan Anda.',
              )),
      _kpiTile('Realisasi Premi', k?.totalRealisasiPremiShort ?? '–',
          AppColors.primaryNavy,
          onTap: () => _openPipelineSheet(
                'Realisasi Premi',
                all,
                (l) => l.stage == 'WON',
                'Belum ada pipeline WON di cakupan Anda.',
              )),
    ];
    // Row 2 — pipeline stage breakdown across all broker-sourced pipelines.
    final stages = <Widget>[
      _kpiTile('Pipeline P3', n(k?.p3), AppColors.grayStage,
          onTap: () => _openStageSheet(all, 'P3')),
      _kpiTile('Pipeline P2', n(k?.p2), AppColors.secondaryOrange,
          onTap: () => _openStageSheet(all, 'P2')),
      _kpiTile('Pipeline P1', n(k?.p1), AppColors.primaryNavy,
          onTap: () => _openStageSheet(all, 'P1')),
      _kpiTile('Pipeline Won', n(k?.won), AppColors.successGreen,
          onTap: () => _openStageSheet(all, 'WON')),
      _kpiTile('Pipeline Declined', n(k?.decline), AppColors.errorRed,
          onTap: () => _openStageSheet(all, 'DECLINE')),
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
          const SizedBox(height: AppSpacing.md),
          // Search bar
          SizedBox(
            height: 44,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => _notifier.onSearchChanged(v),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Cari broker atau PIC...',
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
                          _searchController.clear();
                          _notifier.clearQuery();
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
    // a 2-line label (e.g. "Broker dengan Pipeline") doesn't make its card taller.
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
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
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
                      fontSize: 10, color: AppColors.textSecondary),
                ),
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

  /// Daftar broker → detail brokernya.
  void _openBrokerListSheet(String title, List<BrokerView> views, String empty) {
    showKpiDrilldownSheet(
      context,
      title: title,
      subtitle: 'Tekan satu baris untuk membuka detail brokernya',
      emptyMessage: empty,
      rows: [
        for (final v in views)
          KpiDrilldownRow(
            title: v.broker.name,
            subtitle: '${v.broker.code} · ${v.links.length} pipeline',
            onTap: () => _showBrokerSheet(v),
          ),
      ],
    );
  }

  /// Daftar pipeline → pipeline itu di dalam konteks customer-nya.
  ///
  /// Judul baris SELALU nama customer, bukan nama broker: daftar pipeline tanpa
  /// nama customer tidak bisa dipakai siapa pun. Nama broker & tahapnya jadi
  /// keterangan di bawahnya.
  void _openPipelineSheet(String title, List<BrokerView> views,
      bool Function(BrokerLink) where, String empty) {
    final rows = <KpiDrilldownRow>[];
    for (final v in views) {
      for (final l in v.links.where(where)) {
        rows.add(KpiDrilldownRow(
          title: l.customer.name,
          subtitle: '${v.broker.name} · ${l.stage}',
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

  void _openStageSheet(List<BrokerView> views, String stage) {
    _openPipelineSheet(
      'Pipeline $stage',
      views,
      (l) => l.stage == stage,
      'Belum ada pipeline broker pada tahap $stage di cakupan Anda.',
    );
  }

  /// "Total Broker" adalah ukuran daftar master, dan daftar itu TIDAK ikut
  /// termuat layar ini — `/api/brokers` hanya mengembalikan broker yang punya
  /// pipeline dalam cakupan. Jadi isinya diambil saat ditekan dari
  /// `/api/brokers/options` (master, tanpa filter).
  ///
  /// Broker yang belum punya pipeline di cakupan pemakai tetap ditampilkan tapi
  /// tidak bisa ditekan: tidak ada detail yang jujur untuk dibuka, dan justru
  /// baris-baris inilah yang menjawab "broker mana yang belum kita sentuh".
  Future<void> _openAllBrokersSheet() async {
    final loaded = await _future;
    List<BrokerModel> options;
    try {
      options = await ref.read(brokerRepoProvider).getBrokerOptions();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memuat daftar broker'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!mounted) return;
    final viewById = {
      for (final v in (loaded ?? const <BrokerView>[])) v.broker.id: v,
    };
    showKpiDrilldownSheet(
      context,
      title: 'Total Broker',
      subtitle: 'Seluruh broker pada daftar master',
      emptyMessage: 'Daftar broker master masih kosong.',
      rows: [
        for (final b in options)
          KpiDrilldownRow(
            title: b.name,
            subtitle: viewById.containsKey(b.id)
                ? '${b.code} · ${viewById[b.id]!.links.length} pipeline'
                : '${b.code} · belum ada pipeline di cakupan Anda',
            onTap: viewById.containsKey(b.id)
                ? () => _showBrokerSheet(viewById[b.id]!)
                : null,
          ),
      ],
    );
  }

  // ── Broker card (design.md §3.8) ────────────────────────────────────────
  Widget _buildBrokerCard(BrokerView view) {
    final broker = view.broker;
    return Container(
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
          onTap: () => _showBrokerSheet(view),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: avatar + name + PIC + chevron
                Row(
                  children: [
                    _avatar(broker, 46, 18),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            broker.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kode: ${broker.code}',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 20, color: AppColors.grayStage),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Stats row (3 columns)
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
                      _statColumn('Pipeline Aktif',
                          '${view.activePipelineCount}', AppColors.primaryNavy),
                      _statDivider(),
                      _statColumn('Total Premi', view.totalPremiShort,
                          AppColors.secondaryOrange),
                      _statDivider(),
                      _statColumn(
                          'Won', '${view.wonCount}', AppColors.successGreen),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Connected customers
                const Text(
                  'TERHUBUNG KE NASABAH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (!view.hasConnections)
                  const Text(
                    'Belum ada pipeline terkait',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.grayStage,
                    ),
                  )
                else
                  Builder(builder: (_) {
                    final customers = view.connectedCustomers; // deduped by id
                    const maxShown = 6;
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        ...customers.take(maxShown).map((c) => _customerChip(c)),
                        if (customers.length > maxShown) _seeAllCustomersChip(view),
                      ],
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 28, color: AppColors.border);

  Widget _customerChip(BrokerCustomer c) {
    return Material(
      color: AppColors.navyBg,
      borderRadius: AppRadius.radiusFull,
      child: InkWell(
        borderRadius: AppRadius.radiusFull,
        onTap: () => _openCustomer(c.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            c.name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryNavy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _seeAllCustomersChip(BrokerView view) {
    return Material(
      color: AppColors.secondaryOrange.withValues(alpha: 0.12),
      borderRadius: AppRadius.radiusFull,
      child: InkWell(
        borderRadius: AppRadius.radiusFull,
        onTap: () => _showAllCustomers(view),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            'Lihat semua (${view.connectedCustomers.length})',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.secondaryOrange),
          ),
        ),
      ),
    );
  }

  void _showAllCustomers(BrokerView view) {
    final customers = view.connectedCustomers; // already deduped by id
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nasabah ${view.broker.name} (${customers.length})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: customers.length,
                  separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (_, i) {
                    final c = customers[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                      trailing: const Icon(Icons.chevron_right, size: 18, color: AppColors.grayStage),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _openCustomer(c.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(BrokerModel broker, double size, double radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _avatarColor(broker.id),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: Text(
          broker.initials,
          style: TextStyle(
            fontSize: size * 0.32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── Bottom sheet: broker detail ─────────────────────────────────────────
  void _showBrokerSheet(BrokerView view) {
    final broker = view.broker;
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
                // Handle bar
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
                      // Identity
                      Row(
                        children: [
                          _avatar(broker, 52, 16),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  broker.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Kode Broker: ${broker.code}',
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

                      // Connected pipelines — with search + status filter
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

  Widget _pipelineRow(BuildContext sheetContext, BrokerLink link) {
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

