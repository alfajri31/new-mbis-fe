import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/nav.dart';
import '../../src/admin/account_repository.dart';
import '../../src/assistant/ai_usage_admin_repository.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/kelola_kuota_ai_provider.dart';
import '../widgets/dispose_callback.dart';

/// ADMIN — Kelola Kuota AI. Atur batas run AI harian dan reset pemakaian per pengguna.
class KelolaKuotaAiScreen extends ConsumerStatefulWidget {
  const KelolaKuotaAiScreen({super.key});

  @override
  ConsumerState<KelolaKuotaAiScreen> createState() => _KelolaKuotaAiScreenState();
}

class _KelolaKuotaAiScreenState extends ConsumerState<KelolaKuotaAiScreen> {
  // State data/loading/list dikelola KelolaKuotaAiNotifier. Getter berikut
  // memproksinya agar kode build/widget tetap memakai nama lama tanpa diubah.
  KelolaKuotaAiState get _ks => ref.read(kelolaKuotaAiProvider);
  KelolaKuotaAiNotifier get _notifier => ref.read(kelolaKuotaAiProvider.notifier);

  // Repo untuk aksi tulis (ubah batas) & bottom sheet pemakaian (dulu field
  // `_usage`); kini selalu segar dari provider.
  AiUsageAdminRepository get _usage => ref.read(aiUsageAdminRepoProvider);

  bool get _ready => _ks.ready;
  bool get _loading => _ks.loading;
  String? get _error => _ks.error;
  AiLimit? get _limit => _ks.limit;
  List<AccountModel> get _filtered => _ks.filtered;

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (samakan timing lama). Repo kini
    // dibaca notifier dari provider — tak perlu context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  /// Delegasi ke notifier (logika load dipindah utuh). Dipakai retry + refresh.
  Future<void> _load() => _notifier.reload();

  void _openUsage(AccountModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _UsageSheet(user: user, repo: _usage),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(kelolaKuotaAiProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => safePop(context)),
        title: const Text('Kelola Kuota AI',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: !_ready || _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                      child: _limitCard(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.md),
                      child: _searchField(),
                    ),
                    Expanded(child: _userList()),
                  ],
                ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.grayStage),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: _load, child: const Text('Coba lagi')),
        ]),
      ),
    );
  }

  // ── Batas harian (hero) ──────────────────────────────────────────────────
  Widget _limitCard() {
    final l = _limit;
    final adminSet = l?.isAdminSet ?? false;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radius2Xl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.navyBg, shape: BoxShape.circle),
            child: const Icon(Icons.speed_rounded, size: 22, color: AppColors.primaryNavy),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BATAS RUN HARIAN',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.grayStage)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(l == null ? '—' : '${l.dailyLimit}',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.primaryNavy)),
                    const SizedBox(width: 6),
                    const Text('run / pengguna · hari',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 8),
                _pill(
                  adminSet ? 'Diatur admin' : 'Default server',
                  fg: adminSet ? AppColors.primaryNavy : AppColors.grayStage,
                  bg: adminSet ? AppColors.navyBg : AppColors.grayBg,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          OutlinedButton(
            onPressed: l == null ? null : _editLimit,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryNavy,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
            ),
            child: const Text('Ubah', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return TextField(
      onChanged: (v) => _notifier.onQueryChanged(v),
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Cari nama, NIP, atau email',
        hintStyle: const TextStyle(fontSize: 14, color: AppColors.grayStage),
        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.grayStage),
        filled: true,
        fillColor: AppColors.surfaceWhite,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg, borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.4)),
        border: OutlineInputBorder(borderRadius: AppRadius.radiusLg),
      ),
    );
  }

  // ── Daftar pengguna (grouped) ────────────────────────────────────────────
  Widget _userList() {
    final items = _filtered;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
            child: Text('PENGGUNA · ${items.length}',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.grayStage)),
          ),
          if (items.isEmpty)
            _emptyState()
          else
            Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: AppRadius.radius2Xl,
                border: Border.all(color: AppColors.border),
                boxShadow: const [AppShadows.level1],
              ),
              child: Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0)
                      const Divider(
                          height: 1, thickness: 1, indent: 64, color: AppColors.border),
                    _accountTile(items[i]),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48),
      alignment: Alignment.center,
      child: const Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.person_search_outlined, size: 36, color: AppColors.grayStage),
        SizedBox(height: 10),
        Text('Tidak ada pengguna cocok', style: TextStyle(color: AppColors.textSecondary)),
      ]),
    );
  }

  Widget _accountTile(AccountModel u) {
    final isRm = u.roles.contains('RM');
    final roleLabel = u.roles.isEmpty ? '' : (kRoleLabels[u.roles.first] ?? u.roles.first);
    final subtitle = [roleLabel, u.nip].where((s) => s.isNotEmpty).join('  ·  ');
    return InkWell(
      onTap: () => _openUsage(u),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isRm ? AppColors.navyBg : AppColors.grayBg,
                shape: BoxShape.circle,
              ),
              child: Text(_initials(u.name),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isRm ? AppColors.primaryNavy : AppColors.grayStage)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
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
      ),
    );
  }

  // ── Ubah batas ───────────────────────────────────────────────────────────
  Future<void> _editLimit() async {
    final l = _limit;
    if (l == null) return;
    final ctrl = TextEditingController(text: l.dailyLimit.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (dialogCtx) => DisposeCallback(
        onDispose: ctrl.dispose,
        child: AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radius2Xl),
        title: const Text('Batas run AI harian', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Berlaku untuk semua pengguna. Pemakaian per pengguna tetap bisa direset kapan saja.',
                style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Run per pengguna per hari',
                helperText: 'Rentang 1–1000',
                isDense: true,
                enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd, borderSide: const BorderSide(color: AppColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.4)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primaryNavy),
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v == null || v < 1 || v > 1000) {
                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                  const SnackBar(content: Text('Masukkan angka 1–1000.'), behavior: SnackBarBehavior.floating),
                );
                return;
              }
              Navigator.of(dialogCtx).pop(v);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
      ),
    );
    if (result == null) return;
    try {
      final updated = await _usage.setLimit(result);
      if (!mounted) return;
      _notifier.applyLimit(updated);
      _snack('Batas harian disimpan: ${updated.dailyLimit} run / pengguna / hari.');
    } catch (e) {
      if (!mounted) return;
      _snack('$e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? AppColors.errorRed : null,
    ));
  }
}

// ── Shared bits ──────────────────────────────────────────────────────────────

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final second = parts.length > 1 ? parts.last[0] : (parts.first.length > 1 ? parts.first[1] : '');
  return (first + second).toUpperCase();
}

Widget _pill(String text, {required Color fg, required Color bg}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: AppRadius.radiusFull),
    child: Text(text,
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: fg)),
  );
}

/// Bottom sheet: a user's usage today + reset.
class _UsageSheet extends StatefulWidget {
  final AccountModel user;
  final AiUsageAdminRepository repo;
  const _UsageSheet({required this.user, required this.repo});

  @override
  State<_UsageSheet> createState() => _UsageSheetState();
}

class _UsageSheetState extends State<_UsageSheet> {
  AiUsage? _usage;
  bool _loading = true;
  bool _resetting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final u = await widget.repo.get(widget.user.id);
      if (mounted) setState(() { _usage = u; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _reset() async {
    setState(() => _resetting = true);
    try {
      final u = await widget.repo.reset(widget.user.id);
      if (!mounted) return;
      setState(() { _usage = u; _resetting = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kuota AI berhasil direset.'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _resetting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: AppColors.errorRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tanpa catatan pemakaian, perlakukan sebagai nol — bukan "tidak ada data".
    final u =
        _usage ??
        AiUsage(
          userId: widget.user.id,
          date: '',
          runCount: 0,
          dailyLimit: 0,
          promptTokens: 0,
          outputTokens: 0,
        );
    final isRm = widget.user.roles.contains('RM');
    final roleLabel =
        widget.user.roles.isEmpty ? '' : (kRoleLabels[widget.user.roles.first] ?? widget.user.roles.first);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      // Isi sheet bisa lebih tinggi dari layar (mis. daftar chip kategori,
      // atau keyboard terbuka di layar pendek) -> harus bisa di-scroll,
      // kalau tidak muncul garis kuning 'BOTTOM OVERFLOWED BY ... PIXELS'.
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isRm ? AppColors.navyBg : AppColors.grayBg,
                  shape: BoxShape.circle,
                ),
                child: Text(_initials(widget.user.name),
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isRm ? AppColors.primaryNavy : AppColors.grayStage)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text([roleLabel, widget.user.nip].where((s) => s.isNotEmpty).join('  ·  '),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: const TextStyle(color: AppColors.errorRed)),
            )
          else ...[
            // Belum pernah pakai AI = tetap tampilkan bar dalam keadaan KOSONG
            // (0 dari batas), bukan dibiarkan tanpa apa-apa.
            _usageBlock(u),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _tokenTile('Token masuk', u.promptTokens)),
              const SizedBox(width: 12),
              Expanded(child: _tokenTile('Token keluar', u.outputTokens)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                ),
                onPressed: (_resetting || u.runCount == 0) ? null : _reset,
                icon: _resetting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.restart_alt, size: 18),
                label: Text(u.runCount == 0 ? 'Belum ada pemakaian' : 'Reset kuota hari ini',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _usageBlock(AiUsage u) {
    final ratio = u.dailyLimit > 0 ? (u.runCount / u.dailyLimit).clamp(0.0, 1.0) : 0.0;
    final barColor = u.reached ? AppColors.secondaryOrange : AppColors.primaryNavy;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Pemakaian hari ini',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const Spacer(),
              Text('${u.runCount}',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: barColor, height: 1)),
              Padding(
                padding: const EdgeInsets.only(bottom: 2, left: 2),
                child: Text(' / ${u.dailyLimit} run',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              // `null` = mode indeterminate: barnya beranimasi bolak-balik tanpa
              // henti. Itu yang terlihat saat user BELUM memakai kuota (ratio 0)
              // — seolah masih memuat. Nilai 0 justru berarti "bar kosong".
              value: ratio,
              minHeight: 6,
              backgroundColor: AppColors.grayBg,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            u.reached ? 'Kuota harian habis — reset agar bisa menjalankan lagi.' : 'Diperbarui otomatis setiap tengah malam (WIB).',
            style: TextStyle(
                fontSize: 11.5,
                color: u.reached ? AppColors.secondaryOrange : AppColors.grayStage),
          ),
        ],
      ),
    );
  }

  Widget _tokenTile(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          Text(_compact(value),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }

  static String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}
