import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/admin/account_repository.dart';
import '../providers/kelola_sso_provider.dart';
import '../../core/providers/repository_providers.dart';
import '../widgets/state_views.dart';
import '../widgets/max_width_body.dart';

/// Permintaan SSO — admin review queue for first-time Microsoft sign-ins whose
/// account isn't mapped to an MBIS user yet. Per request the admin can: link it to
/// an existing account, create a new (SSO-only) account, or deny it. Backed by
/// /api/auth/admin/entra/pending; every write is ADMIN-gated server-side.
class KelolaSsoScreen extends ConsumerStatefulWidget {
  const KelolaSsoScreen({super.key, required this.offices});

  final List<OfficeOption> offices;

  @override
  ConsumerState<KelolaSsoScreen> createState() => _KelolaSsoScreenState();
}

class _KelolaSsoScreenState extends ConsumerState<KelolaSsoScreen> {
  // State bisnis/async (loading/error/daftar pending) dikelola KelolaSsoNotifier.
  // Getter berikut memproksinya agar seluruh kode build/aksi di bawah tetap
  // memakai nama lama tanpa diubah.
  KelolaSsoState get _ss => ref.read(kelolaSsoProvider);
  KelolaSsoNotifier get _notifier => ref.read(kelolaSsoProvider.notifier);

  bool get _loading => _ss.loading;
  String? get _error => _ss.error;
  List<EntraPendingModel> get _pending => _ss.pending;

  /// Repo untuk aksi tulis (link/deny/create) & pengambilan daftar akun di
  /// dialog — tetap di widget. Sesi terbaru dibawa `apiClientProvider`, jadi
  /// tak perlu context/`MbisApp.of`.
  AccountRepository get _repo => ref.read(accountRepoProvider);

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (samakan timing lama yang dulu
    // memuat sekali di didChangeDependencies saat `_repo == null`).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  /// Delegasi ke notifier (logika fetch dipindah utuh). Dipakai retry/refresh
  /// dan setelah aksi tulis berhasil.
  Future<void> _fetch() => _notifier.fetch();

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(kelolaSsoProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.primaryNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Permintaan SSO',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: MaxWidthBody(
        child: _loading
            ? const SkeletonList(itemCount: 5)
            : _error != null
                ? ListView(children: [
                    const SizedBox(height: 60),
                    ErrorStateView(message: _error!, onRetry: _fetch),
                  ])
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: _pending.isEmpty
                        ? ListView(children: const [
                            SizedBox(height: 100),
                            EmptyStateView(
                              icon: Icons.verified_user_outlined,
                              title: 'Tidak ada permintaan',
                              subtitle:
                                  'Permintaan login Microsoft yang belum terdaftar akan muncul di sini.',
                            ),
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 24),
                            itemCount: _pending.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _row(_pending[i]),
                          ),
                  ),
      ),
    );
  }

  Widget _row(EntraPendingModel p) {
    return Container(
      padding: const EdgeInsets.all(14),
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
              const Icon(Icons.window, size: 18, color: AppColors.purpleAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  p.name.isEmpty ? p.email : p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            p.email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () => _linkExisting(p),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primaryNavy),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Hubungkan'),
              ),
              OutlinedButton.icon(
                onPressed: () => _createNew(p),
                icon: const Icon(Icons.person_add_alt_1, size: 18),
                label: const Text('Buat akun'),
              ),
              TextButton.icon(
                onPressed: () => _deny(p),
                style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Tolak'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _linkExisting(EntraPendingModel p) async {
    final accounts = await _guard(() => _repo.getAccounts());
    if (accounts == null || !mounted) return;
    // SSO-linkable = local accounts not already tied to a Microsoft identity.
    final linkable = accounts.where((a) => a.authMethod != 'ENTRA').toList();
    final picked = await showModalBottomSheet<AccountModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AccountPicker(accounts: linkable, email: p.email),
    );
    if (picked == null) return;
    if (!await _run(() => _repo.linkEntraPending(p.id, picked.nip))) return;
    _snack('Akun "${picked.name}" terhubung ke Microsoft');
    _fetch();
  }

  Future<void> _createNew(EntraPendingModel p) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SsoCreateForm(repo: _repo, pending: p, offices: widget.offices),
    );
    if (created == true) {
      _snack('Akun baru dibuat');
      _fetch();
    }
  }

  Future<void> _deny(EntraPendingModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Tolak permintaan?'),
        content: Text(
            '${p.email} tidak akan bisa login lewat Microsoft. Anda bisa tetap membuatkan akun untuknya nanti secara manual.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Tolak', style: TextStyle(color: AppColors.errorRed)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!await _run(() => _repo.denyEntraPending(p.id))) return;
    _snack('Permintaan ditolak');
    _fetch();
  }

  /// Runs a value-returning repo call, surfacing any error as a snackbar. Returns the
  /// result, or null on failure / when the widget was disposed.
  Future<T?> _guard<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return mounted ? result : null;
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
      return null;
    }
  }

  /// Runs a void repo call, surfacing any error as a snackbar. Returns true on success.
  Future<bool> _run(Future<void> Function() action) async {
    try {
      await action();
      return mounted;
    } catch (e) {
      if (mounted) _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
      return false;
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// EXISTING-ACCOUNT PICKER (for "Hubungkan")
// ════════════════════════════════════════════════════════════════════════════

class _AccountPicker extends StatefulWidget {
  const _AccountPicker({required this.accounts, required this.email});

  final List<AccountModel> accounts;
  final String email;

  @override
  State<_AccountPicker> createState() => _AccountPickerState();
}

class _AccountPickerState extends State<_AccountPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final visible = q.isEmpty
        ? widget.accounts
        : widget.accounts
            .where((a) =>
                a.name.toLowerCase().contains(q) ||
                a.nip.toLowerCase().contains(q) ||
                a.email.toLowerCase().contains(q))
            .toList();
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Hubungkan ke akun',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Untuk ${widget.email}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Cari nama, NIP, atau email',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: AppRadius.radiusSm),
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            // Cap against the area above the keyboard so the sheet never gets
            // pushed to the very top of the screen while searching.
            constraints: BoxConstraints(
                maxHeight: (MediaQuery.of(context).size.height -
                        MediaQuery.of(context).viewInsets.bottom) *
                    0.5),
            child: visible.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Tidak ada akun cocok.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    itemBuilder: (_, i) {
                      final a = visible[i];
                      return ListTile(
                        dense: true,
                        title: Text(a.name),
                        subtitle: Text('${a.nip} • ${a.email}',
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).pop(a),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CREATE-NEW FORM (for "Buat akun")
// ════════════════════════════════════════════════════════════════════════════

class _SsoCreateForm extends StatefulWidget {
  const _SsoCreateForm({required this.repo, required this.pending, required this.offices});

  final AccountRepository repo;
  final EntraPendingModel pending;
  final List<OfficeOption> offices;

  @override
  State<_SsoCreateForm> createState() => _SsoCreateFormState();
}

class _SsoCreateFormState extends State<_SsoCreateForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nip;
  late final TextEditingController _name;
  String _officeId = '';
  final Set<String> _roles = {};
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nip = TextEditingController();
    _name = TextEditingController(text: widget.pending.name);
  }

  @override
  void dispose() {
    _nip.dispose();
    _name.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: AppRadius.radiusSm),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Buat akun dari SSO',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Email ${widget.pending.email} akan dipakai untuk login Microsoft (tanpa password).',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nip,
                decoration: _dec('NIP / ID Login', hint: 'mis. 199001012015031001'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                decoration: _dec('Nama Lengkap'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _officeId,
                isExpanded: true,
                decoration: _dec('Kantor'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('— Tanpa kantor —')),
                  for (final o in widget.offices)
                    DropdownMenuItem(value: o.id, child: Text(o.label)),
                ],
                onChanged: (v) => setState(() => _officeId = v ?? ''),
              ),
              const SizedBox(height: 16),
              const Text('Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final entry in kRoleLabels.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: _roles.contains(entry.key),
                      onSelected: (sel) => setState(() {
                        if (sel) {
                          _roles.add(entry.key);
                        } else {
                          _roles.remove(entry.key);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Akun aktif', style: TextStyle(fontSize: 14)),
                value: _active,
                activeThumbColor: AppColors.successGreen,
                onChanged: (v) => setState(() => _active = v),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Buat & Setujui',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_roles.isEmpty) {
      _snack('Pilih minimal satu role', isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repo.createFromEntraPending(
        widget.pending.id,
        nip: _nip.text.trim(),
        name: _name.text.trim(),
        officeId: _officeId,
        roles: _roles.toList(),
        active: _active,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
    ));
  }
}
