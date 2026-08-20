import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/rm_handover/rm_handover_repository.dart';
import '../providers/pindah_rm_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/search_picker_sheet.dart';
import '../widgets/max_width_body.dart';
import '../../src/network/api_error.dart';

/// S-130 — Pindah RM (RM handover). For supervisors (BM/RO/KUP) and admin to move
/// an RM's active portfolio to another RM when the RM is on leave or changes branch.
/// Tab 1 executes a handover; Tab 2 lists history and reverts temporary ones.
class PindahRmScreen extends ConsumerStatefulWidget {
  const PindahRmScreen({super.key});

  @override
  ConsumerState<PindahRmScreen> createState() => _PindahRmScreenState();
}

class _PindahRmScreenState extends ConsumerState<PindahRmScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      // Body diinset otomatis di bawah app bar + TabBar oleh Scaffold. (Tanpa ini,
      // konten dipadding manual sebesar tinggi app bar SEKALIGUS diinset Scaffold →
      // muncul celah kosong ~1 tinggi app bar di atas form.)
      appBar: GlassAppBar(
        title: 'Pindah RM',
        showBack: true,
        contentMaxWidth: MaxWidthBody.defaultMaxWidth,

        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryNavy,
          unselectedLabelColor: AppColors.grayStage,
          indicatorColor: AppColors.secondaryOrange,
          tabs: const [
            Tab(text: 'Pindahkan'),
            Tab(text: 'Riwayat'),
          ],
        ),
      ),
      body: MaxWidthBody(
        child: TabBarView(
        controller: _tabController,
        children: [
          _HandoverForm(onDone: () => _tabController.animateTo(1)),
          const _HistoryTab(),
        ],
      ),
      ),
    );
  }
}

// ── Tab 1: handover form ────────────────────────────────────────────────────

class _HandoverForm extends ConsumerStatefulWidget {
  final VoidCallback onDone;

  const _HandoverForm({required this.onDone});

  @override
  ConsumerState<_HandoverForm> createState() => _HandoverFormState();
}

class _HandoverFormState extends ConsumerState<_HandoverForm> {
  // Loader FutureBuilder (dipicu di initState) tetap di widget agar tak kedip.
  Future<List<RmCandidate>>? _candidatesFuture;

  // Pilihan form yang DIEDIT user tetap di widget.
  RmCandidate? _fromRm;
  RmCandidate? _toRm;
  String _type = 'PERMANENT';
  String _scope = 'ALL';
  final Set<String> _selectedCustomers = {};

  final _reasonCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // Data/loading/hasil async dikelola PindahRmNotifier; getter memproksinya agar
  // seluruh kode build di bawah tetap memakai nama lama tanpa diubah.
  PindahRmState get _st => ref.read(pindahRmProvider);
  PindahRmNotifier get _notifier => ref.read(pindahRmProvider.notifier);

  List<RmCandidate> get _candidates => _st.candidates;
  RmTransferPreview? get _preview => _st.preview;
  bool get _loadingPreview => _st.loadingPreview;
  bool get _submitting => _st.submitting;

  @override
  void initState() {
    super.initState();
    _candidatesFuture = _loadCandidates();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<List<RmCandidate>> _loadCandidates() => _notifier.loadCandidates();

  Future<void> _onFromChanged(RmCandidate? rm) async {
    // Pilihan user (RM asal/pengganti, checkbox) di-reset di widget; kosongkan
    // preview lama + muat preview baru ditangani notifier.
    setState(() {
      _fromRm = rm;
      _selectedCustomers.clear();
      // RM pengganti wajib satu cabang dengan RM asal — buang pilihan lama yang
      // tak lagi memenuhi syarat (beda cabang atau sama dengan RM asal).
      if (_toRm != null &&
          (_toRm!.id == rm?.id || _toRm!.officeId != rm?.officeId)) {
        _toRm = null;
      }
    });
    try {
      await _notifier.onFromChanged(rm);
    } catch (e) {
      if (mounted) _snack(_err(e));
    }
  }

  /// RM pengganti yang boleh menampung: hanya RM di cabang yang sama dengan RM
  /// asal (di luar RM asal itu sendiri). Kosong sampai RM asal dipilih.
  List<RmCandidate> get _toCandidates {
    final from = _fromRm;
    if (from == null) return const [];
    return _candidates
        .where((c) => c.id != from.id && c.officeId != null && c.officeId == from.officeId)
        .toList();
  }

  bool get _canSubmit {
    if (_fromRm == null || _toRm == null || _submitting) return false;
    if (_fromRm!.id == _toRm!.id) return false;
    if (_toRm!.officeId != _fromRm!.officeId) return false;
    if (_scope == 'SELECTED' && _selectedCustomers.isEmpty) {
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    final from = _fromRm!, to = _toRm!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Konfirmasi Pindah RM'),
        content: Text(
          'Pindahkan portofolio ${_scope == 'ALL' ? 'lengkap' : 'terpilih'} '
          'dari ${from.name} ke ${to.name}?\n\n'
          'Tipe: ${_type == 'PERMANENT' ? 'Permanen' : 'Sementara'}.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pindahkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await _notifier.execute(
        fromRmId: from.id,
        toRmId: to.id,
        type: _type,
        scope: _scope,
        customerIds: _selectedCustomers.toList(),
        reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );
      if (!mounted) return;
      _snack(
        'Berhasil: ${result.customerCount} customer, ${result.pipelineCount} pipeline, '
        '${result.scheduleCount} jadwal dipindahkan.',
        success: true,
      );
      _reset();
      widget.onDone();
    } catch (e) {
      if (mounted) _snack(_err(e));
    }
  }

  void _reset() {
    setState(() {
      _fromRm = null;
      _toRm = null;
      _type = 'PERMANENT';
      _scope = 'ALL';
      _selectedCustomers.clear();
      _reasonCtrl.clear();
      _noteCtrl.clear();
    });
    _notifier.resetPreview();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pindahRmProvider);
    // Body sudah diinset di bawah app bar oleh Scaffold; cukup jarak kecil di atas.
    const topInset = AppSpacing.sm;
    return FutureBuilder<List<RmCandidate>>(
      future: _candidatesFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _retry(() => setState(() {
            _candidatesFuture = _loadCandidates();
          }));
        }
        return ListView(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, topInset + AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxl),
          children: [
            _label('RM Asal (digantikan)'),
            _rmDropdown(_fromRm, _candidates, _onFromChanged),
            if (_loadingPreview) ...[
              const SizedBox(height: AppSpacing.md),
              const Center(child: Padding(
                padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
            ],
            if (_preview != null) ...[
              const SizedBox(height: AppSpacing.md),
              _previewCard(_preview!),
            ],
            const SizedBox(height: AppSpacing.lg),
            _label('RM Pengganti'),
            _rmDropdown(
              _toRm,
              _toCandidates,
              (rm) => setState(() => _toRm = rm),
            ),
            if (_fromRm != null && _toCandidates.isEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tidak ada RM lain di cabang yang sama untuk menampung customer.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            if (_fromRm != null && _toCandidates.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Hanya RM di cabang yang sama dengan RM asal.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            _label('Tipe Pemindahan'),
            _choices(
              // Fitur ini untuk reassign portofolio saat RM cuti/berhenti — BUKAN pindah
              // cabang RM (itu di menu "Pemindahan Cabang RM"). Key PERMANENT/TEMPORARY
              // tetap (dikirim ke server); hanya labelnya yang diperjelas.
              {'PERMANENT': 'Permanen (RM berhenti)', 'TEMPORARY': 'Sementara (cuti)'},
              _type,
              (v) => setState(() => _type = v),
            ),
            const SizedBox(height: AppSpacing.lg),
            _label('Cakupan'),
            _choices(
              {'ALL': 'Semua portofolio', 'SELECTED': 'Pilih sebagian'},
              _scope,
              (v) => setState(() => _scope = v),
            ),
            if (_scope == 'SELECTED' && _preview != null) ...[
              const SizedBox(height: AppSpacing.md),
              _selectionLists(_preview!),
            ],
            const SizedBox(height: AppSpacing.lg),
            _label('Alasan (opsional)'),
            _textField(_reasonCtrl, 'mis. cuti melahirkan, RM resign'),
            const SizedBox(height: AppSpacing.lg),
            _label('Catatan (opsional)'),
            _textField(_noteCtrl, 'catatan tambahan', maxLines: 3),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canSubmit ? _submit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Pindahkan RM',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _previewCard(RmTransferPreview p) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PORTOFOLIO AKTIF',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _stat('${p.customerCount}', 'Customer'),
              _stat('${p.pipelineCount}', 'Pipeline aktif'),
              _stat('${p.scheduleCount}', 'Jadwal'),
            ],
          ),
          if (p.isEmpty) ...[
            const SizedBox(height: 8),
            const Text('RM ini tidak punya portofolio aktif untuk dipindah.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.bgScreen, borderRadius: AppRadius.radiusSm),
      child: Row(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _selectionLists(RmTransferPreview p) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (p.customers.isNotEmpty) ...[
            const Text('Customer', style: TextStyle(fontWeight: FontWeight.w600)),
            ...p.customers.map((c) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _selectedCustomers.contains(c.id),
                  title: Text(c.name, style: const TextStyle(fontSize: 14)),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selectedCustomers.add(c.id);
                    } else {
                      _selectedCustomers.remove(c.id);
                    }
                  }),
                )),
          ],
          if (p.customers.isEmpty)
            const Text('Tidak ada item yang bisa dipilih.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  /// Searchable RM picker (nama/NIP). Menggantikan dropdown polos supaya mudah
  /// mencari saat daftar RM panjang. Filter lokal atas [items] yang sudah dimuat.
  Widget _rmDropdown(
      RmCandidate? value, List<RmCandidate> items, ValueChanged<RmCandidate?> onChanged) {
    return InkWell(
      borderRadius: AppRadius.radiusMd,
      onTap: () async {
        final picked = await showSearchPicker<RmCandidate>(
          context,
          title: 'Pilih RM',
          initial: items,
          labelOf: (c) => c.label,
          onSearch: (q) async {
            if (q.isEmpty) return items;
            final lower = q.toLowerCase();
            return items.where((c) => c.label.toLowerCase().contains(lower)).toList();
          },
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: _inputDecoration('Pilih RM'),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value?.label ?? 'Pilih RM',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: value == null ? AppColors.grayStage : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: AppColors.grayStage),
          ],
        ),
      ),
    );
  }

  Widget _choices(Map<String, String> options, String selected, ValueChanged<String> onChanged) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.entries
          // Latar navy saat terpilih (dari chipTheme) + label putih agar kontras.
          .map((e) => ChoiceChip(
                label: Text(e.value),
                selected: selected == e.key,
                onSelected: (_) => onChanged(e.key),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      selected == e.key ? FontWeight.w600 : FontWeight.w500,
                  color: selected == e.key
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
              ))
          .toList(),
    );
  }

  Widget _textField(TextEditingController ctrl, String hint, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      style: AppInput.fieldText,
      maxLines: maxLines,
      decoration: _inputDecoration(hint),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      );

  void _snack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: success ? AppColors.successGreen : null,
    ));
  }
}

// ── Tab 2: history ──────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerStatefulWidget {
  const _HistoryTab();

  @override
  ConsumerState<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends ConsumerState<_HistoryTab> {
  // Loader FutureBuilder (dipicu di initState/refresh) tetap di widget.
  Future<List<RmHandover>>? _future;

  PindahRmNotifier get _notifier => ref.read(pindahRmProvider.notifier);
  String? get _reverting => ref.read(pindahRmProvider).reverting;

  @override
  void initState() {
    super.initState();
    _future = _notifier.listHistory();
  }

  // Blok (bukan arrow): `() => _future = ...` mengembalikan Future ke setState,
  // dan Flutter menolaknya dengan assertion "setState() callback argument
  // returned a Future" — itu yang muncul di layar saat memuat ulang riwayat.
  void _refresh() => setState(() {
    _future = _notifier.listHistory();
  });

  Future<void> _revert(RmHandover h) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Kembalikan Pemindahan'),
        content: Text(
            'Kembalikan portofolio dari ${h.toRmName} ke ${h.fromRmName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kembalikan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _notifier.revert(h.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pemindahan dikembalikan'), behavior: SnackBarBehavior.floating));
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyError(e, operationMayHaveSucceeded: true)),
          behavior: SnackBarBehavior.floating));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pindahRmProvider);
    // Body sudah diinset di bawah app bar oleh Scaffold; cukup jarak kecil di atas.
    const topInset = AppSpacing.sm;
    return FutureBuilder<List<RmHandover>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Gagal memuat riwayat'),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _refresh, child: const Text('Coba lagi')),
            ]),
          );
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return ListView(
            padding: EdgeInsets.only(top: topInset + 40),
            children: const [
              Center(child: Text('Belum ada riwayat pemindahan',
                  style: TextStyle(color: AppColors.textSecondary))),
            ],
          );
        }
        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, topInset + AppSpacing.sm, AppSpacing.lg, AppSpacing.xxxl),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _historyCard(items[i]),
        );
      },
    );
  }

  Widget _historyCard(RmHandover h) {
    final reverted = h.status == 'REVERTED';
    return Container(
      padding: const EdgeInsets.all(16),
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
                child: Text('${h.fromRmName}  →  ${h.toRmName}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ),
              _badge(reverted ? 'Dikembalikan' : 'Aktif',
                  reverted ? AppColors.grayStage : AppColors.successGreen),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${h.type == 'PERMANENT' ? 'Permanen' : 'Sementara'} • '
            '${h.scope == 'ALL' ? 'Semua' : 'Sebagian'} • '
            '${h.customerCount} customer, ${h.pipelineCount} pipeline, '
            '${h.scheduleCount} jadwal',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          if (h.reason != null && h.reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Alasan: ${h.reason}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ],
          if (h.createdAt != null) ...[
            const SizedBox(height: 4),
            Text(_formatDate(h.createdAt!),
                style: const TextStyle(fontSize: 11, color: AppColors.grayStage)),
          ],
          if (h.isActive) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _reverting == h.id ? null : () => _revert(h),
                icon: _reverting == h.id
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.undo, size: 16, color: AppColors.primaryNavy),
                label: const Text('Kembalikan',
                    style: TextStyle(color: AppColors.primaryNavy, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryNavy),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadius.radiusSm,
        ),
        child: Text(text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  /// Trims an ISO timestamp to "yyyy-MM-dd HH:mm".
  String _formatDate(String iso) {
    if (iso.length >= 16) return iso.substring(0, 16).replaceFirst('T', ' ');
    return iso;
  }
}

// ── Shared helpers ──────────────────────────────────────────────────────────

Widget _card({required Widget child}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: child,
    );

Widget _retry(VoidCallback onRetry) => Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('Gagal memuat data'),
        const SizedBox(height: 8),
        ElevatedButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ]),
    );

String _err(Object e) => friendlyError(e, operationMayHaveSucceeded: true);
