import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../utils/format.dart';
import '../../src/rm_handover/rm_handover_repository.dart' show RmCandidate;
import '../../src/rm_handover/rm_transfer_repository.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/rm_transfer_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/max_width_body.dart';
import '../widgets/search_picker_sheet.dart';
import '../widgets/state_views.dart';
import 'rm_transfer_allocation_screen.dart';
import '../../src/network/api_error.dart';

/// S-131 — Pemindahan Cabang RM (two-stage). PJD/Admin records "RM → branch";
/// the old branch's Pinca allocates the portfolio, which executes the move.
///
/// Separate from Pindah RM (S-130), which is a direct one-shot handover for leave
/// cover or a same-branch reassignment. This one moves an RM to another branch.
class RmTransferScreen extends ConsumerStatefulWidget {
  const RmTransferScreen({super.key});

  @override
  ConsumerState<RmTransferScreen> createState() => _RmTransferScreenState();
}

class _RmTransferScreenState extends ConsumerState<RmTransferScreen> {
  // Trigger sekali di didChangeDependencies (dulu guard `_repo == null`).
  bool _started = false;

  // State data/loading dikelola RmTransferNotifier; getter memproksinya agar
  // kode build/aksi di bawah tetap memakai nama lama tanpa diubah.
  RmTransferState get _st => ref.read(rmTransferProvider);
  RmTransferNotifier get _notifier => ref.read(rmTransferProvider.notifier);
  RmTransferRepository get _repo => ref.read(rmTransferRepoProvider);

  Future<List<RmTransfer>>? get _future => _st.future;

  bool get _isAdmin =>
      (MbisApp.of(context)?.session?.user.roles ?? const []).contains('ADMIN');

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // FutureBuilder loader: trigger tetap di sini agar tak ada flash empty-state
    // (future terisi sebelum build pertama).
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifier.reload();
      });
    }
  }

  void _reload() => _notifier.reload();

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(rmTransferProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
          title: 'Pemindahan Cabang RM', showBack: true, contentMaxWidth: MaxWidthBody.defaultMaxWidth),
      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primaryNavy,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Buat', style: TextStyle(color: Colors.white)),
              onPressed: _openCreate,
            )
          : null,
      body: MaxWidthBody(
        child: RefreshIndicator(
          onRefresh: () async {
            _reload();
          },
          child: FutureBuilder<List<RmTransfer>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const SkeletonList(itemCount: 5);
              }
              if (snap.hasError) {
                return ErrorStateView(
                  message: friendlyError(snap.error!, fallback: 'Gagal memuat daftar pemindahan.'),
                  onRetry: () async {
                    _reload();
                  },
                );
              }
              final rows = snap.data ?? const [];
              if (rows.isEmpty) {
                return ListView(children: const [
                  SizedBox(height: 120),
                  EmptyStateView(icon: Icons.swap_horiz, title: 'Belum ada pemindahan cabang'),
                ]);
              }
              return ListView.builder(
                // Body memanjang di BELAKANG app bar (extendBodyBehindAppBar),
                // jadi inset atas = tinggi status bar + toolbar. Tanpa
                // `padding.top` kartu pertama naik ± setinggi status bar dan
                // tertutup GlassAppBar — persis seperti layar lain di app ini.
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    MediaQuery.of(context).padding.top + kToolbarHeight + AppSpacing.lg,
                    AppSpacing.lg,
                    96),
                itemCount: rows.length,
                itemBuilder: (_, i) => _card(rows[i]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _card(RmTransfer t) {
    final (Color color, Color bg, String label) = switch (t.status) {
      'COMPLETED' => (AppColors.successGreen, AppColors.greenLight, 'Selesai'),
      'CANCELLED' => (AppColors.grayStage, AppColors.grayBg, 'Dibatalkan'),
      _ => (AppColors.secondaryOrange, AppColors.orangeLight, 'Menunggu alokasi'),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            children: [
              Expanded(
                child: Text(t.rmName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
                child: Text(label,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _officeChip(t.fromOfficeName ?? t.fromOfficeId, 'Asal')),
              const Icon(Icons.arrow_forward, size: 16, color: AppColors.grayStage),
              Expanded(child: _officeChip(t.toOfficeName ?? t.toOfficeId, 'Tujuan')),
            ],
          ),
          if ((t.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(t.reason!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 6),
          Text(
            t.isCompleted && t.allocatedAt != null
                ? 'Dialokasikan ${AppFormat.dateOnly(t.allocatedAt)}'
                : 'Dibuat ${AppFormat.dateOnly(t.createdAt)}',
            style: const TextStyle(fontSize: 11, color: AppColors.grayStage),
          ),
          if (t.isPending && (t.actionable || _isAdmin)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (t.actionable)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _openAllocation(t),
                      icon: const Icon(Icons.assignment_ind_outlined, size: 16),
                      label: const Text('Alokasi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryNavy,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                if (t.actionable && _isAdmin) const SizedBox(width: 10),
                if (_isAdmin)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _cancel(t),
                      child: const Text('Batalkan'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _officeChip(String name, String role) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(role, style: const TextStyle(fontSize: 10, color: AppColors.grayStage)),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      ],
    );
  }

  Future<void> _openAllocation(RmTransfer t) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RmTransferAllocationScreen(repo: _repo, transfer: t)),
    );
    if (done == true) _reload();
  }

  Future<void> _openCreate() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _CreateTransferSheet(),
    );
    if (created == true) _reload();
  }

  Future<void> _cancel(RmTransfer t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Batalkan pemindahan?'),
        content: Text('Pemindahan ${t.rmName} ke ${t.toOfficeName ?? t.toOfficeId} akan dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tidak')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya, batalkan')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Backend cancel + reload dipindah ke notifier; dialog + snackbar tetap di sini.
      await _notifier.cancel(t.id);
      messenger.showSnackBar(const SnackBar(content: Text('Pemindahan dibatalkan')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text(friendlyError(e, operationMayHaveSucceeded: true))));
    }
  }
}

// ── Create sheet (PJD/Admin) ────────────────────────────────────────────────

class _CreateTransferSheet extends ConsumerStatefulWidget {
  const _CreateTransferSheet();

  @override
  ConsumerState<_CreateTransferSheet> createState() =>
      _CreateTransferSheetState();
}

class _CreateTransferSheetState extends ConsumerState<_CreateTransferSheet> {
  // User selections + controller tetap lokal (UI-ephemeral).
  RmCandidate? _rm;
  OfficeRef? _toBranch;
  final _reasonCtrl = TextEditingController();

  // Data/loading/saving dikelola RmTransferNotifier; getter memproksinya.
  RmTransferState get _st => ref.read(rmTransferProvider);
  RmTransferNotifier get _notifier => ref.read(rmTransferProvider.notifier);
  List<RmCandidate> get _rms => _st.createRms;
  List<OfficeRef> get _branches => _st.createBranches;
  bool get _loading => _st.createLoading;
  bool get _submitting => _st.createSubmitting;
  String? get _error => _st.createError;

  @override
  void initState() {
    super.initState();
    // Loader berbendera loading → start() setelah frame pertama (samakan timing;
    // spinner tampil lebih dulu karena createLoading default true).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.startCreate();
    });
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(rmTransferProvider);
    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Buat Pemindahan Cabang',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('RM yang dipindah beserta cabang tujuannya. Portofolio dialokasikan '
              'oleh Pinca cabang asal.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.errorRed, fontSize: 13))
          else ...[
            _pickerField(
              label: 'RM yang dipindah',
              value: _rm?.label,
              onTap: () async {
                final picked = await showSearchPicker<RmCandidate>(
                  context,
                  title: 'Pilih RM',
                  initial: _rms,
                  labelOf: (c) => '${c.label} — ${c.officeName ?? '-'}',
                  onSearch: (q) async {
                    if (q.isEmpty) return _rms;
                    final l = q.toLowerCase();
                    return _rms.where((c) =>
                        c.label.toLowerCase().contains(l) ||
                        (c.officeName ?? '').toLowerCase().contains(l)).toList();
                  },
                );
                if (picked != null) setState(() => _rm = picked);
              },
            ),
            const SizedBox(height: 12),
            _pickerField(
              label: 'Cabang tujuan',
              value: _toBranch?.name,
              onTap: () async {
                // A branch move to the RM's own branch is pointless; the backend
                // rejects it too, but keep it out of the picker.
                final options = _branches
                    .where((b) => b.id != _rm?.officeId)
                    .toList();
                final picked = await showSearchPicker<OfficeRef>(
                  context,
                  title: 'Pilih cabang tujuan',
                  initial: options,
                  labelOf: (o) => o.name,
                  onSearch: (q) async {
                    if (q.isEmpty) return options;
                    final l = q.toLowerCase();
                    return options.where((o) => o.name.toLowerCase().contains(l)).toList();
                  },
                );
                if (picked != null) setState(() => _toBranch = picked);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              style: AppInput.fieldText,
              maxLength: 255,
              decoration: InputDecoration(
                labelText: 'Alasan (opsional)',
                border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_rm != null && _toBranch != null && !_submitting) ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Buat Pemindahan'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pickerField({required String label, String? value, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: AppRadius.radiusMd,
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(value ?? 'Pilih',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14, color: value == null ? AppColors.grayStage : AppColors.textPrimary)),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.grayStage),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Backend create + flag submitting dipindah ke notifier; navigasi + snackbar
      // tetap di sini.
      await _notifier.submitCreate(
        rmId: _rm!.id,
        toOfficeId: _toBranch!.id,
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(const SnackBar(content: Text('Pemindahan dibuat — menunggu alokasi Pinca')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text(friendlyError(e, operationMayHaveSucceeded: true))));
    }
  }
}
