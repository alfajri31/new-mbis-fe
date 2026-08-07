import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../core/providers/repository_providers.dart';
import '../../src/admin/account_repository.dart';
import '../providers/kelola_akun_provider.dart';
import '../widgets/state_views.dart';
import '../widgets/max_width_body.dart';
import 'kelola_sso_screen.dart';

/// Kelola Akun — admin-only management of user/login accounts: create accounts
/// of any role, edit details/roles/office, reset password, and deactivate
/// (soft-delete) agents/RMs/etc. Backed by /api/auth/admin/users; every write is
/// ADMIN-gated server-side.
class KelolaAkunScreen extends ConsumerStatefulWidget {
  const KelolaAkunScreen({super.key});

  @override
  ConsumerState<KelolaAkunScreen> createState() => _KelolaAkunScreenState();
}

class _KelolaAkunScreenState extends ConsumerState<KelolaAkunScreen> {
  // UI-ephemeral (tetap di widget): filter pencarian client-side.
  String _query = '';

  // State bisnis/async dikelola KelolaAkunNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  KelolaAkunState get _ks => ref.read(kelolaAkunProvider);
  KelolaAkunNotifier get _notifier => ref.read(kelolaAkunProvider.notifier);

  // Repo untuk aksi tulis (toggle aktif) + membangun form sheet. Sama instance
  // dgn yang dipakai notifier (keduanya baca accountRepoProvider).
  AccountRepository get _repo => ref.read(accountRepoProvider);

  bool get _loading => _ks.loading;
  String? get _error => _ks.error;
  List<AccountModel> get _accounts => _ks.accounts;
  List<OfficeOption> get _offices => _ks.offices;
  String? get _currentUserId => _ks.currentUserId;

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama (initialLoading-flag loader).
    // Sesi (id user aktif) dibaca notifier dari sessionProvider — tak perlu context.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  Future<void> _fetch() => _notifier.fetch();

  List<AccountModel> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _accounts;
    return _accounts.where((a) {
      return a.name.toLowerCase().contains(q) ||
          a.nip.toLowerCase().contains(q) ||
          a.email.toLowerCase().contains(q) ||
          a.roles.any((r) => r.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(kelolaAkunProvider);
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
          'Kelola Akun',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Permintaan SSO',
            icon: const Icon(Icons.verified_user_outlined, color: Colors.white),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => KelolaSsoScreen(offices: _offices),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Tambah'),
      ),
      body: MaxWidthBody(
        child: _loading
          ? const SkeletonList(itemCount: 6)
          : _error != null
              ? ListView(children: [
                  const SizedBox(height: 60),
                  ErrorStateView(message: _error!, onRetry: _fetch),
                ])
              : Column(
                  children: [
                    _buildSearch(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _fetch,
                        child: _visible.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 100),
                                EmptyStateView(
                                  icon: Icons.people_outline,
                                  title: 'Tidak ada akun',
                                  subtitle: 'Tambah akun baru atau ubah pencarian.',
                                ),
                              ])
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 88),
                                itemCount: _visible.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (_, i) => _row(_visible[i]),
                              ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: TextField(
        onChanged: (v) => setState(() => _query = v),
        style: AppInput.fieldText,
        decoration: InputDecoration(
          hintText: 'Cari nama, NIP, email, atau role',
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceWhite,
          border: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.radiusLg,
            borderSide: const BorderSide(color: AppColors.border),
          ),
        ),
      ),
    );
  }

  Widget _row(AccountModel a) {
    final isSelf = a.id == _currentUserId;
    return Opacity(
      opacity: a.active ? 1 : 0.6,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
          boxShadow: const [AppShadows.level1],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.navyBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _initials(a.name),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          a.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (!a.active) ...[
                        const SizedBox(width: 6),
                        _tag('Nonaktif', AppColors.errorRed),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${a.nip} • ${a.email}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  if (a.officeName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      a.officeName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.grayStage),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final r in a.roles) _tag(r, AppColors.primaryNavy),
                      if (a.authMethod == 'ENTRA')
                        _tag('Microsoft', AppColors.purpleAccent),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _openForm(item: a);
                if (v == 'toggle') _toggleActive(a);
                if (v == 'delete') _deleteAccount(a);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (a.active)
                  PopupMenuItem(
                    value: 'toggle',
                    enabled: !isSelf,
                    child: Text(
                      isSelf ? 'Nonaktifkan (akun Anda)' : 'Nonaktifkan',
                      style: TextStyle(
                          color: isSelf ? AppColors.grayStage : AppColors.errorRed),
                    ),
                  )
                else
                  const PopupMenuItem(
                    value: 'toggle',
                    child: Text('Aktifkan',
                        style: TextStyle(color: AppColors.successGreen)),
                  ),
                // Hapus sengaja hanya muncul untuk akun yang SUDAH nonaktif —
                // server pun menolak menghapus akun aktif. Penghapusan jadi
                // tindakan sengaja dua langkah, bukan salah klik pada akun yang
                // sedang dipakai orang.
                if (!a.active)
                  PopupMenuItem(
                    value: 'delete',
                    enabled: !isSelf,
                    child: Text(
                      isSelf ? 'Hapus (akun Anda)' : 'Hapus akun',
                      style: TextStyle(
                          color: isSelf ? AppColors.grayStage : AppColors.errorRed,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(50),
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: color),
        ),
      );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Future<void> _toggleActive(AccountModel a) async {
    final turnOff = a.active;
    if (turnOff) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
          // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
          scrollable: true,
          title: const Text('Nonaktifkan akun?'),
          content: Text(
              '"${a.name}" tidak akan bisa login. Data historisnya tetap utuh dan akun bisa diaktifkan lagi kapan saja.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal')),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Nonaktifkan',
                  style: TextStyle(color: AppColors.errorRed)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      await _repo.setActive(a.id, !a.active);
      if (!mounted) return;
      _snack(turnOff ? 'Akun dinonaktifkan' : 'Akun diaktifkan');
      _fetch();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  /// Penghapusan akun permanen — pelaksana permintaan hapus akun (kewajiban
  /// Google Play). Hanya tersedia untuk akun yang sudah nonaktif.
  ///
  /// Konfirmasinya menuntut pengetikan nama akun, bukan sekadar tombol "Ya":
  /// tindakan ini tidak bisa dibatalkan, dan daftar akun kerap berisi nama-nama
  /// yang mirip. Hasil server ditampilkan apa adanya agar admin tahu apakah baris
  /// benar-benar dibuang atau data pribadinya dimusnahkan sambil menyisakan
  /// catatan wajib arsip.
  Future<void> _deleteAccount(AccountModel a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _KonfirmasiHapusAkunDialog(nama: a.name, nip: a.nip),
    );
    if (confirmed != true) return;
    try {
      final result = await _repo.deleteAccount(a.id);
      if (!mounted) return;
      _snack(result.message);
      _fetch();
    } catch (e) {
      if (!mounted) return;
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    }
  }

  Future<void> _openForm({AccountModel? item}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AccountForm(
        repo: _repo,
        item: item,
        offices: _offices,
      ),
    );
    if (saved == true) _fetch();
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.errorRed : AppColors.successGreen,
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// CREATE / EDIT FORM
// ════════════════════════════════════════════════════════════════════════════

class _AccountForm extends StatefulWidget {
  final AccountRepository repo;
  final AccountModel? item;
  final List<OfficeOption> offices;

  const _AccountForm({required this.repo, this.item, required this.offices});

  @override
  State<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<_AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nip;
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late String _officeId; // '' = no office
  late Set<String> _roles;
  bool _active = true;
  bool _connect = false;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _nip = TextEditingController(text: it?.nip ?? '');
    _name = TextEditingController(text: it?.name ?? '');
    _email = TextEditingController(text: it?.email ?? '');
    _password = TextEditingController();
    _officeId = it?.officeId ?? '';
    _roles = {...?it?.roles};
    _active = it?.active ?? true;
    _connect = it?.isConnect ?? false;
  }

  @override
  void dispose() {
    _nip.dispose();
    _name.dispose();
    _email.dispose();
    _password.dispose();
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
    // Only offer offices that exist; '' is the "no office" sentinel.
    final officeIds = {'', ...widget.offices.map((o) => o.id)};
    final officeValue = officeIds.contains(_officeId) ? _officeId : '';

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
              Text(_isEdit ? 'Edit Akun' : 'Tambah Akun',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // NIP boleh diubah saat edit: ia identitas login, dan NIP yang
              // salah ketik dulu hanya bisa dibetulkan lewat migrasi basis data.
              // Menggantinya memindahkan pintu masuk pemiliknya, jadi bantuannya
              // ditulis di bawah field supaya admin tidak melakukannya tanpa sadar.
              TextFormField(
                controller: _nip,
                style: AppInput.fieldText,
                decoration: _dec('NIP / ID Login',
                    hint: _isEdit ? null : 'mis. 199001012015031001'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              if (_isEdit) ...[
                const SizedBox(height: 6),
                Text(
                  'NIP dipakai untuk login. Bila diubah, beri tahu pemiliknya — '
                  'sesi yang sedang berjalan tetap aktif, tetapi login berikutnya '
                  'memakai NIP baru.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                style: AppInput.fieldText,
                decoration: _dec('Nama Lengkap'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                style: AppInput.fieldText,
                keyboardType: TextInputType.emailAddress,
                decoration: _dec('Email'),
                validator: (v) {
                  final s = v?.trim() ?? '';
                  if (s.isEmpty) return 'Wajib diisi';
                  if (!s.contains('@')) return 'Email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                style: AppInput.fieldText,
                obscureText: true,
                decoration: _dec(
                  _isEdit ? 'Password baru (opsional)' : 'Password',
                  hint: _isEdit
                      ? 'Kosongkan jika tidak diubah'
                      : 'Minimal 8 karakter',
                ),
                // Batas 8 mengikuti server (AdminCreateUserRequest @Size(min = 8)).
                // Sebelumnya di sini 6, jadi password 6-7 karakter lolos form lalu
                // ditolak backend dengan 400 — form harus menolaknya lebih dulu.
                validator: (v) {
                  if (_isEdit && (v == null || v.isEmpty)) {
                    return null; // reset opsional: kosong = password tidak diubah
                  }
                  if (v == null || v.isEmpty) return 'Wajib diisi';
                  if (v.length < 8) return 'Minimal 8 karakter';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: officeValue,
                isExpanded: true,
                style: AppInput.fieldText,
                decoration: _dec('Kantor'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('— Tanpa kantor —')),
                  for (final o in widget.offices)
                    DropdownMenuItem(value: o.id, child: Text(o.label)),
                ],
                onChanged: (v) => setState(() => _officeId = v ?? ''),
              ),
              const SizedBox(height: 16),
              const Text('Role',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final entry in kRoleLabels.entries)
                    FilterChip(
                      label: Text(entry.value),
                      selected: _roles.contains(entry.key),
                      // Teks putih saat terpilih agar kontras di atas latar navy.
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _roles.contains(entry.key)
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
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
                subtitle: const Text('Akun nonaktif tidak bisa login',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                value: _active,
                activeThumbColor: AppColors.successGreen,
                onChanged: (v) => setState(() => _active = v),
              ),
              // Tag "Connect" — RM-only, set by admin (post-piloting feedback);
              // shown as a badge on the RM's own dashboard/profil once tagged.
              // Only settable on an existing account, since a new account starts
              // untagged by default.
              if (_isEdit && _roles.contains('RM'))
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tag Connect', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('Ditampilkan sebagai badge di dashboard & profil RM',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  value: _connect,
                  activeThumbColor: AppColors.primaryNavy,
                  onChanged: (v) => setState(() => _connect = v),
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
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Simpan',
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
      if (_isEdit) {
        await widget.repo.updateAccount(
          widget.item!.id,
          nip: _nip.text.trim(),
          name: _name.text.trim(),
          email: _email.text.trim(),
          officeId: _officeId, // '' detaches
          password: _password.text, // ignored if empty
          roles: _roles.toList(),
          active: _active,
          isConnect: _roles.contains('RM') ? _connect : null,
        );
      } else {
        await widget.repo.createAccount(
          nip: _nip.text.trim(),
          name: _name.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          officeId: _officeId,
          roles: _roles.toList(),
          active: _active,
        );
      }
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

/// Konfirmasi penghapusan akun. Tombol "Hapus" baru hidup setelah admin mengetik
/// ulang nama akun persis — pagar yang sengaja merepotkan, karena penghapusan
/// tidak bisa dibatalkan dan daftar akun kerap memuat nama yang mirip.
class _KonfirmasiHapusAkunDialog extends StatefulWidget {
  const _KonfirmasiHapusAkunDialog({required this.nama, required this.nip});

  final String nama;
  final String nip;

  @override
  State<_KonfirmasiHapusAkunDialog> createState() =>
      _KonfirmasiHapusAkunDialogState();
}

class _KonfirmasiHapusAkunDialogState
    extends State<_KonfirmasiHapusAkunDialog> {
  final _controller = TextEditingController();
  bool _cocok = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final cocok = _controller.text.trim() == widget.nama.trim();
      if (cocok != _cocok) setState(() => _cocok = cocok);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Layar landscape sangat pendek: tanpa ini isi dialog meluber alih-alih
      // bisa digulung (pola yang sama dipakai dialog nonaktifkan di atas).
      scrollable: true,
      title: const Text('Hapus akun permanen?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.nama} • ${widget.nip}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          const Text(
            'Data pribadi akun ini dihapus permanen dan tidak dapat dipulihkan: '
            'NIP, nama, surel, jabatan, kata sandi, perangkat notifikasi, dan '
            'seluruh riwayat notifikasinya.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          const Text(
            'Catatan pipeline, kunjungan, dan serah terima yang wajib diarsipkan '
            'tetap disimpan, tetapi tidak lagi menunjuk ke identitas siapa pun.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text('Ketik "${widget.nama}" untuk mengonfirmasi:',
              style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal')),
        TextButton(
          onPressed: _cocok ? () => Navigator.of(context).pop(true) : null,
          child: Text('Hapus permanen',
              style: TextStyle(
                  color: _cocok ? AppColors.errorRed : AppColors.grayStage,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
