import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/rm_handover/rm_handover_repository.dart' show RmCandidate;
import '../../src/rm_handover/rm_transfer_repository.dart';
import '../providers/rm_transfer_allocation_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/max_width_body.dart';
import '../widgets/search_picker_sheet.dart';
import '../widgets/state_views.dart';
import '../../src/network/api_error.dart';

/// Stage 2 of a branch transfer: the old branch's Pinca allocates the RM's
/// customers to RMs staying behind, then executes the move.
///
/// One default RM receives everything; any customer can be overridden to another
/// RM (this is where customer A's book can be split across RM B and RM C). Every
/// customer is covered by construction — an un-allocated one would follow the RM
/// to the new branch, which is what this flow exists to prevent.
class RmTransferAllocationScreen extends ConsumerStatefulWidget {
  final RmTransferRepository repo;
  final RmTransfer transfer;

  const RmTransferAllocationScreen({super.key, required this.repo, required this.transfer});

  @override
  ConsumerState<RmTransferAllocationScreen> createState() => _RmTransferAllocationScreenState();
}

class _RmTransferAllocationScreenState extends ConsumerState<RmTransferAllocationScreen> {
  // Pilihan alokasi (di-edit user) TETAP di widget.
  RmCandidate? _defaultRm;
  final Map<String, RmCandidate> _overrides = {}; // customerId -> RM

  // State DATA/LOADING (future, submitting) dikelola RmTransferAllocationNotifier.
  // Getter berikut memproksinya agar kode build/widget di bawah tetap memakai
  // nama lama tanpa diubah.
  RmTransferAllocationState get _st => ref.read(rmTransferAllocationProvider);
  RmTransferAllocationNotifier get _notifier =>
      ref.read(rmTransferAllocationProvider.notifier);

  Future<TransferAllocationView>? get _future => _st.future;
  bool get _submitting => _st.submitting;

  // Load-once per instance layar (start me-reset state untuk transfer baru).
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pemuatan awal dipindah ke notifier.start(). Timing tetap sinkron di
    // didChangeDependencies agar frame pertama sudah punya future (tanpa flash),
    // sama seperti `initState` lama. Repo & transfer di-inject dari widget.
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifier.start(repo: widget.repo, transferId: widget.transfer.id);
      });
    }
  }

  RmCandidate? _destFor(String customerId) => _overrides[customerId] ?? _defaultRm;

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(rmTransferAllocationProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(
          title: 'Alokasi Portofolio', showBack: true, contentMaxWidth: MaxWidthBody.defaultMaxWidth),
      body: MaxWidthBody(
        child: FutureBuilder<TransferAllocationView>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SkeletonList(itemCount: 6);
            }
            if (snap.hasError) {
              return ErrorStateView(
                message: friendlyError(snap.error!, fallback: 'Gagal memuat data alokasi.'),
                onRetry: () async {
                  _notifier.reload();
                },
              );
            }
            final v = snap.data!;
            return _content(context, v);
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, TransferAllocationView v) {
    return ListView(
      // Sama seperti rm_transfer_screen: body di belakang app bar, jadi inset
      // atas harus memuat tinggi status bar juga.
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          MediaQuery.of(context).padding.top + kToolbarHeight + AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.navyBg,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: AppColors.primaryNavy.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${v.rmName} → ${v.toOfficeName}',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
              const SizedBox(height: 4),
              Text('${v.customers.length} nasabah harus dialokasikan ke RM yang tinggal di cabang '
                  'asal sebelum ${v.rmName} pindah.',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (v.destinationRms.isEmpty)
          const EmptyStateView(
            icon: Icons.person_off_outlined,
            title: 'Tidak ada RM lain di cabang asal',
          )
        else ...[
          const Text('RM penampung default',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _rmPicker(
            value: _defaultRm,
            hint: 'Pilih RM penampung',
            candidates: v.destinationRms,
            onPicked: (rm) => setState(() => _defaultRm = rm),
          ),
          const SizedBox(height: 6),
          const Text('Semua nasabah masuk ke RM ini kecuali di-atur sendiri di bawah.',
              style: TextStyle(fontSize: 11, color: AppColors.grayStage)),
          const SizedBox(height: 16),

          if (v.customers.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('RM ini tidak memegang nasabah. Menyelesaikan hanya memindahkan cabangnya.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            )
          else ...[
            Text('Nasabah (${v.customers.length})',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            for (final c in v.customers) _customerRow(c, v.destinationRms),
          ],

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_defaultRm != null && !_submitting) ? () => _submit(v) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(v.customers.isEmpty ? 'Pindahkan Cabang' : 'Alokasikan & Pindahkan'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _customerRow(TransferCustomer c, List<RmCandidate> candidates) {
    final dest = _destFor(c.id);
    final overridden = _overrides.containsKey(c.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: overridden ? AppColors.secondaryOrange : AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${c.activePipelines} pipeline aktif · '
                  '${dest != null ? dest.name : "belum ada RM"}${overridden ? " (diatur)" : ""}',
                  style: TextStyle(
                      fontSize: 11,
                      color: dest == null ? AppColors.errorRed : AppColors.textSecondary),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final picked = await _pickRm(candidates, allowReset: overridden);
              if (picked == null) return;
              setState(() {
                if (picked == _resetSentinel) {
                  _overrides.remove(c.id);
                } else {
                  _overrides[c.id] = picked;
                }
              });
            },
            child: Text(overridden ? 'Ubah' : 'Atur'),
          ),
        ],
      ),
    );
  }

  Widget _rmPicker({
    required RmCandidate? value,
    required String hint,
    required List<RmCandidate> candidates,
    required ValueChanged<RmCandidate> onPicked,
  }) {
    return InkWell(
      borderRadius: AppRadius.radiusMd,
      onTap: () async {
        final picked = await _pickRm(candidates, allowReset: false);
        if (picked != null && picked != _resetSentinel) onPicked(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: AppRadius.radiusMd),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(value?.label ?? hint,
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

  /// Sentinel returned by the picker to mean "clear the override (use default)".
  static final RmCandidate _resetSentinel =
      RmCandidate(id: '__reset__', nip: '', name: '');

  Future<RmCandidate?> _pickRm(List<RmCandidate> candidates, {required bool allowReset}) {
    final options = <RmCandidate>[
      if (allowReset) _resetSentinel,
      ...candidates,
    ];
    return showSearchPicker<RmCandidate>(
      context,
      title: 'Pilih RM tujuan',
      initial: options,
      labelOf: (c) => c == _resetSentinel ? '↺ Ikuti RM default' : c.label,
      onSearch: (q) async {
        if (q.isEmpty) return options;
        final l = q.toLowerCase();
        return options
            .where((c) => c == _resetSentinel || c.label.toLowerCase().contains(l))
            .toList();
      },
    );
  }

  Future<void> _submit(TransferAllocationView v) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    // Flag `submitting` + panggilan repo dipindah ke notifier; snackbar & navigasi
    // TETAP di widget. Notifier membereskan `submitting` lalu melempar ulang error.
    try {
      await _notifier.submit(
        transferId: v.transferId,
        defaultRmId: _defaultRm!.id,
        overrides: {for (final e in _overrides.entries) e.key: e.value.id},
      );
      messenger.showSnackBar(const SnackBar(content: Text('Portofolio dialokasikan & RM dipindah')));
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text(friendlyError(e, operationMayHaveSucceeded: true))));
    }
  }
}
