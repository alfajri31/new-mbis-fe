import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/referral/referral_repository.dart';
import '../../utils/responsive.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/referral_management_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/state_views.dart';
import '../widgets/dispose_callback.dart';

/// Branch-Manager referral queue with history. Three tabs — menunggu approval,
/// disetujui, ditolak. Source-stage approve forwards to the destination BM;
/// destination-stage approve requires picking a receiving RM and hands the
/// pipeline (and its customer) over to that RM.
class ReferralManagementScreen extends ConsumerStatefulWidget {
  const ReferralManagementScreen({super.key});

  @override
  ConsumerState<ReferralManagementScreen> createState() => _ReferralManagementScreenState();
}

class _ReferralManagementScreenState extends ConsumerState<ReferralManagementScreen> with RouteAware {
  // State async (data/loading) dikelola ReferralManagementNotifier. Getter di
  // bawah memproksinya agar seluruh kode build tetap memakai nama lama.
  ReferralManagementNotifier get _notifier =>
      ref.read(referralManagementProvider.notifier);

  // Repo dipakai langsung oleh write-action (approve/reject); reload lewat notifier.
  ReferralRepository get _repo => ref.read(referralRepoProvider);

  Future<List<ReferralPending>>? get _future =>
      ref.read(referralManagementProvider).future;

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (samakan pola customer_list). Sesi
    // dibaca notifier lewat apiClientProvider — tak perlu context di sini.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) MbisApp.routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    MbisApp.routeObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _refresh() => _notifier.refresh();

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(referralManagementProvider);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.bgScreen,
        extendBodyBehindAppBar: true,
        appBar: const GlassAppBar(title: 'Manajemen Referral', showBack: true),
        body: FutureBuilder<List<ReferralPending>>(
          future: _future,
          builder: (context, snap) {
            final loading = snap.connectionState == ConnectionState.waiting;
            final items = snap.data ?? const <ReferralPending>[];
            final waiting = items.where((r) => r.isPending).toList();
            final approved = items.where((r) => r.isApproved).toList();
            final rejected = items.where((r) => r.isRejected).toList();
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.isWide(context)
                      ? Responsive.contentMaxWidthFor(context)
                      : double.infinity,
                ),
                child: Column(
                  children: [
                    SizedBox(height: topInset),
                    Material(
                      color: AppColors.surfaceWhite,
                      child: TabBar(
                        labelColor: AppColors.primaryNavy,
                        unselectedLabelColor: AppColors.textSecondary,
                        indicatorColor: AppColors.primaryNavy,
                        labelStyle: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.bold),
                        unselectedLabelStyle: const TextStyle(fontSize: 12.5),
                        tabs: [
                          Tab(text: 'Menunggu (${waiting.length})'),
                          Tab(text: 'Disetujui (${approved.length})'),
                          Tab(text: 'Ditolak (${rejected.length})'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: snap.hasError
                          ? ErrorStateView(
                              message: 'Gagal memuat referral', onRetry: _refresh)
                          : TabBarView(
                              children: [
                                _tab(waiting, loading,
                                    empty: 'Tidak ada referral menunggu approval'),
                                _tab(approved, loading,
                                    empty: 'Belum ada referral disetujui'),
                                _tab(rejected, loading,
                                    empty: 'Belum ada referral ditolak'),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _tab(List<ReferralPending> items, bool loading, {required String empty}) {
    if (loading) {
      return const SkeletonList(padding: EdgeInsets.all(AppSpacing.lg));
    }
    return RefreshIndicator(
      color: AppColors.primaryNavy,
      onRefresh: _refresh,
      child: items.isEmpty
          ? ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 40, AppSpacing.lg, AppSpacing.lg),
              children: [
                EmptyStateView(icon: Icons.inbox_outlined, title: empty),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                  AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
              itemCount: items.length,
              itemBuilder: (_, i) => _card(items[i]),
            ),
    );
  }

  Widget _card(ReferralPending r) {
    final destStage = r.isDestStage;
    // Status chip colour + label.
    final (Color chipColor, String chipLabel) = switch (r.status) {
      'PENDING_SOURCE' => (AppColors.secondaryOrange, 'Menunggu BM Asal'),
      'PENDING_DEST' => (AppColors.primaryNavy, 'Menunggu BM Tujuan'),
      'APPROVED' => (AppColors.successGreen, 'Disetujui'),
      'REJECTED' => (AppColors.errorRed, 'Ditolak'),
      _ => (AppColors.grayStage, r.status),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(r.title ?? 'Pipeline',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(chipLabel,
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: chipColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (r.customerName != null)
            Text('Customer: ${r.customerName}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.route_outlined, size: 14, color: AppColors.grayStage),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${r.fromOfficeName ?? '-'}  →  ${r.toOfficeName ?? '-'}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
              ),
            ],
          ),
          if (r.fromRmName != null) ...[
            const SizedBox(height: 2),
            Text('RM pembuat: ${r.fromRmName}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          // Approved: show who received the pipeline.
          if (r.isApproved && r.assignedRmName != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_pin_circle_outlined,
                    size: 15, color: AppColors.successGreen),
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Diassign ke: ${r.assignedRmName}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.successGreen)),
                ),
              ],
            ),
          ],
          // Rejected: show the reason (if any).
          if (r.isRejected) ...[
            const SizedBox(height: 6),
            Text(
                (r.rejectReason == null || r.rejectReason!.isEmpty)
                    ? 'Alasan: -'
                    : 'Alasan: ${r.rejectReason}',
                style: const TextStyle(fontSize: 12, color: AppColors.errorRed)),
          ],
          // Action buttons only when this BM can act on the current stage.
          if (r.isPending && r.actionable) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _reject(r),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.errorRed),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                    ),
                    child: const Text('Tolak',
                        style: TextStyle(fontSize: 13, color: AppColors.errorRed)),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => destStage ? _approveDest(r) : _approveSource(r),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                    ),
                    child: Text(destStage ? 'Setujui & Pilih RM' : 'Setujui',
                        style: const TextStyle(fontSize: 13, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ] else if (r.isPending && !r.actionable) ...[
            const SizedBox(height: 8),
            Text(
                destStage
                    ? 'Menunggu approval BM cabang tujuan'
                    : 'Menunggu approval BM cabang asal',
                style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Future<void> _approveSource(ReferralPending r) async {
    final ok = await _confirm(
      title: 'Setujui Referral',
      body: 'Setujui referral "${r.title ?? 'Pipeline'}"? '
          'Referral akan diteruskan ke BM cabang tujuan (${r.toOfficeName ?? '-'}).',
      confirmLabel: 'Setujui',
      confirmColor: AppColors.primaryNavy,
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.approve(r.pipelineId);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
          content: Text('Referral disetujui, diteruskan ke BM cabang tujuan')));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _approveDest(ReferralPending r) async {
    if (r.toOfficeId == null) return;
    List<BranchRm> rms = [];
    try {
      rms = await _repo.branchRms(r.toOfficeId!);
    } catch (_) {}
    if (!mounted) return;
    if (rms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada RM aktif di cabang tujuan')));
      return;
    }
    String? selected = rms.first.id;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
          // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
          scrollable: true,
          title: const Text('Setujui & Pilih RM Tujuan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  'Pipeline "${r.title ?? ''}" beserta nasabahnya akan diserahkan '
                  'ke RM yang dipilih di cabang ${r.toOfficeName ?? 'tujuan'}.',
                  style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                items: rms
                    .map((rm) => DropdownMenuItem(
                        value: rm.id,
                        child: Text(
                            rm.nip != null ? '${rm.name} (${rm.nip})' : rm.name,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (v) => setD(() => selected = v),
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Setujui & Serahkan'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || selected == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.approve(r.pipelineId, rmId: selected);
      if (!mounted) return;
      messenger.showSnackBar(
          const SnackBar(content: Text('Referral disetujui & diserahkan ke RM tujuan')));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _reject(ReferralPending r) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => DisposeCallback(
        onDispose: ctrl.dispose,
        child: AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Tolak Referral'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tolak referral "${r.title ?? 'Pipeline'}"? Pipeline tetap milik RM pembuat.',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Alasan penolakan (opsional)',
                isDense: true,
                border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed),
            child: const Text('Tolak Referral', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      ),
    );
    if (reason == null || !mounted) return; // dismissed
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _repo.reject(r.pipelineId, reason);
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Referral ditolak')));
      _refresh();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: Text(title),
        content: Text(body, style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
