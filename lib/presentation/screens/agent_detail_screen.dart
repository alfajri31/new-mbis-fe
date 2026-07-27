import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/agent/agent_repository.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/agent_detail_provider.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/dispose_callback.dart';
import '../widgets/missing_fields_notice.dart';
import 'agent_management_screen.dart' show agentStatusLabel, agentStatusColor, agentTypeLabel;
import 'ajukan_agen_screen.dart';

/// S-151 — Agent detail + back-office actions. Buttons shown depend on the
/// caller's role and the agent's status in the onboarding workflow.
class AgentDetailScreen extends ConsumerStatefulWidget {
  final String agentId;
  const AgentDetailScreen({super.key, required this.agentId});

  @override
  ConsumerState<AgentDetailScreen> createState() => _AgentDetailScreenState();
}

class _AgentDetailScreenState extends ConsumerState<AgentDetailScreen> {
  // Repo dipakai write-actions (approve/reject/issue CIF/dll.) — via provider
  // bersama, bukan konstruksi ApiClient sendiri. Instansi sama (cached provider).
  AgentRepository get _repo => ref.read(agentRepoProvider);

  // State bisnis/async dikelola AgentDetailNotifier. Getter berikut memproksinya
  // agar seluruh kode build/aksi di bawah tetap memakai nama lama tanpa diubah.
  AgentDetailState get _ds => ref.read(agentDetailProvider);
  AgentDetailNotifier get _notifier => ref.read(agentDetailProvider.notifier);

  AgentModel? get _agent => _ds.agent;
  List<AgentDocumentModel> get _docs => _ds.docs;
  bool get _loading => _ds.loading;
  String? get _error => _ds.error;

  // UI-ephemeral (tetap di widget): overlay aksi tulis yang sedang berjalan.
  bool _busy = false; // an action is in flight

  List<String> get _roles => MbisApp.of(context)?.session?.user.roles ?? const [];

  @override
  void initState() {
    super.initState();
    // Bootstrap notifier setelah frame pertama. Layar sudah menampilkan spinner
    // (_loading default true), jadi tak ada flash. Repo dibaca notifier dari
    // provider — tak perlu context (dulu di didChangeDependencies).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start(widget.agentId);
    });
  }

  /// Muat ulang detail (delegasi ke notifier) — dipakai setelah aksi tulis agar
  /// tampilan sinkron. Logika load dipindah utuh ke AgentDetailNotifier.load().
  Future<void> _load() => _notifier.load();

  /// Runs an action, showing a snackbar on success/failure and reloading.
  Future<void> _run(Future<void> Function() action, String successMsg) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(successMsg), backgroundColor: AppColors.successGreen));
      await _load();
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('$e'.replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.errorRed,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(agentDetailProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: const BackAppBar(title: 'Detail Agen'),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              : _content(_agent!),
    );
  }

  Widget _content(AgentModel a) {
    return Stack(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
          children: [
            _header(a),
            if (a.status == 'REJECTED' && a.rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              _rejectionBanner(a.rejectionReason),
            ],
            const SizedBox(height: 16),
            _infoCard('Kontak', [
              _row('Email', a.email),
              _row('Telepon', a.phone),
              _row('NPWP', a.npwp),
              _row('No. KTP', a.ktpNumber),
              _row('Tanggal Lahir', a.birthDate),
              _row('Jenis Kelamin', a.gender),
            ]),
            const SizedBox(height: 12),
            _infoCard('Rekening', [
              _row('Bank', a.bankName),
              _row('No. Rekening', a.accountNumber),
            ]),
            const SizedBox(height: 12),
            _infoCard('Keagenan', [
              _row('CIF', a.cif),
              _row('No. Lisensi', a.licenseNumber),
              _row('Masa Lisensi',
                  a.licenseStart.isEmpty && a.licenseEnd.isEmpty ? '-' : '${a.licenseStart} s/d ${a.licenseEnd}'),
              // PKS ditampilkan di sini — di layar yang SAMA dengan tombol
              // "Atur PKS", supaya nilai yang baru disimpan langsung terlihat.
              _row('No. PKS', a.pksNumber),
              _row('Masa PKS',
                  a.pksStart.isEmpty && a.pksEnd.isEmpty ? '' : '${a.pksStart} s/d ${a.pksEnd}'),
              _row('Terdaftar', a.createdAt),
            ]),
            const SizedBox(height: 12),
            _infoCard('Alamat KTP', [
              _row('Alamat', a.ktpAddress),
              _row('Provinsi', a.ktpProvince),
              _row('Kota/Kab', a.ktpCity),
              _row('Kecamatan', a.ktpDistrict),
              _row('Kelurahan', a.ktpSubdistrict),
              _row('RT/RW', _rtRw(a.ktpRt, a.ktpRw)),
            ]),
            const SizedBox(height: 12),
            _infoCard('Alamat Domisili', [
              _row('Alamat', a.domicileAddress),
              _row('Provinsi', a.domicileProvince),
              _row('Kota/Kab', a.domicileCity),
              _row('Kecamatan', a.domicileDistrict),
              _row('Kelurahan', a.domicileSubdistrict),
              _row('RT/RW', _rtRw(a.domicileRt, a.domicileRw)),
            ]),
            const SizedBox(height: 12),
            _documentsCard(a),
          ],
        ),
          ),
        ),
        if (_busy) const Positioned.fill(child: ColoredBox(color: Color(0x22000000), child: Center(child: CircularProgressIndicator()))),
        Positioned(left: 0, right: 0, bottom: 0, child: _actionBar(a)),
      ],
    );
  }

  Widget _header(AgentModel a) {
    final color = agentStatusColor(a.status);
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.navyBg, borderRadius: AppRadius.radiusLg),
          child: Text(
            a.name.isNotEmpty ? a.name[0].toUpperCase() : '?',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                Text(agentTypeLabel(a.type), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(50)),
                  child: Text(agentStatusLabel(a.status),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rejectionBanner(String reason) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorRed.withValues(alpha: 0.08),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.cancel_outlined, size: 18, color: AppColors.errorRed),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Alasan penolakan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.errorRed)),
            const SizedBox(height: 2),
            Text(reason, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
          ]),
        ),
      ]),
    );
  }

  Widget _infoCard(String title, List<Widget> rows) {
    final visible = rows.whereType<_InfoRow>().where((r) => r.value.trim().isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
        const SizedBox(height: 10),
        ...visible,
      ]),
    );
  }

  _InfoRow _row(String label, String value) => _InfoRow(label: label, value: value);

  /// "RT/RW" combined; empty (so the row is hidden) when both are blank.
  String _rtRw(String rt, String rw) {
    if (rt.trim().isEmpty && rw.trim().isEmpty) return '';
    return '${rt.trim().isEmpty ? '-' : rt.trim()} / ${rw.trim().isEmpty ? '-' : rw.trim()}';
  }

  Widget _documentsCard(AgentModel a) {
    final canUpload = _roles.contains('RM');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Text('Dokumen', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryNavy)),
          ),
          if (canUpload)
            TextButton.icon(
              onPressed: _busy ? null : () => _uploadDocument(a),
              icon: const Icon(Icons.upload_file, size: 16),
              label: const Text('Unggah'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primaryNavy),
            ),
        ]),
        if (_docs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Belum ada dokumen.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          )
        else
          ..._docs.map((d) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Icon(Icons.description_outlined, size: 18, color: AppColors.grayStage),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d.docType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      if (d.fileName.isNotEmpty)
                        Text(d.fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ]),
                  ),
                ]),
              )),
      ]),
    );
  }

  // ── Action bar ────────────────────────────────────────────────────────────

  Widget _actionBar(AgentModel a) {
    final buttons = <Widget>[];
    final isRm = _roles.contains('RM');
    final isSupervisor = _roles.any((r) => r == 'BM' || r == 'RO' || r == 'KUP');
    final isAdmin = _roles.contains('ADMIN');

    if (isSupervisor && a.status == 'WAITING_APPROVAL') {
      buttons.add(_btn('Tolak', Icons.close, AppColors.errorRed, _rejectFlow, outlined: true));
      buttons.add(_btn('Setujui', Icons.check, AppColors.successGreen,
          () => _run(() => _repo.approve(a.id).then((_) {}), 'Pengajuan disetujui.')));
    }
    if (isAdmin && a.status == 'WAITING_LICENSE') {
      buttons.add(_btn('Input Lisensi', Icons.badge_outlined, AppColors.primaryNavy, () => _licenseFlow(a)));
    }
    if (isRm && (a.status == 'DRAFT' || a.status == 'REJECTED')) {
      buttons.add(_btn('Edit Data', Icons.edit_outlined, AppColors.primaryNavy, () => _editFlow(a), outlined: true));
      buttons.add(_btn('Ajukan Persetujuan', Icons.send, AppColors.primaryNavy,
          () => _run(() => _repo.submitForApproval(a.id).then((_) {}), 'Pengajuan dikirim.')));
    }
    if (isRm && a.status == 'WAITING_RM_DOCS') {
      buttons.add(_btn('Kirim Dokumen', Icons.send, AppColors.primaryNavy,
          () => _run(() => _repo.submitDocuments(a.id).then((_) {}), 'Dokumen dikirim untuk penerbitan CIF.')));
    }
    if (isRm) {
      buttons.add(_btn('Atur PKS', Icons.assignment_outlined, AppColors.primaryNavy, () => _pksFlow(a), outlined: true));
    }
    if (isRm && (a.status == 'DRAFT' || a.status == 'WAITING_APPROVAL' || a.status == 'REJECTED')) {
      buttons.add(_btn('Hapus', Icons.delete_outline, AppColors.errorRed, () => _deleteFlow(a), outlined: true));
    }
    if (isAdmin && a.status == 'WAITING_CIF') {
      buttons.add(_btn('Terbitkan CIF', Icons.key_outlined, AppColors.secondaryOrange, () => _issueCifFlow(a)));
    }
    if (isAdmin && a.status == 'WAITING_RENEWAL') {
      buttons.add(_btn('Setujui Perpanjangan', Icons.autorenew, AppColors.successGreen, () => _licenseFlow(a, renewal: true)));
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 10, AppSpacing.lg, 16),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Wrap(spacing: 10, runSpacing: 10, children: buttons),
      ),
    );
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap, {bool outlined = false}) {
    final child = SizedBox(
      height: 46,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: _busy ? null : onTap,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color, width: 1.4),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              ),
            )
          : ElevatedButton.icon(
              onPressed: _busy ? null : onTap,
              icon: Icon(icon, size: 18),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              ),
            ),
    );
    return ConstrainedBox(constraints: const BoxConstraints(minWidth: 150), child: child);
  }

  // ── Flows (dialogs) ─────────────────────────────────────────────────────

  Future<void> _editFlow(AgentModel a) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AjukanAgenScreen(existing: a)),
    );
    if (changed == true) await _load();
  }

  Future<void> _deleteFlow(AgentModel a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Hapus Pengajuan'),
        content: Text('Hapus pengajuan ${a.name}? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await _repo.deleteAgent(a.id);
      messenger.showSnackBar(const SnackBar(
          content: Text('Pengajuan dihapus.'), backgroundColor: AppColors.successGreen));
      navigator.pop(true); // back to the list
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(
        content: Text('$e'.replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.errorRed,
      ));
    }
  }

  Future<void> _rejectFlow() async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Tolak Agen'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Alasan penolakan (opsional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.errorRed, foregroundColor: Colors.white),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    if (reason == null) return; // cancelled
    await _run(() => _repo.reject(widget.agentId, reason: reason.isEmpty ? null : reason).then((_) {}), 'Agen ditolak.');
  }

  Future<void> _licenseFlow(AgentModel a, {bool renewal = false}) async {
    final ctrl = TextEditingController(text: a.licenseNumber);
    DateTime? start = a.licenseStart.isEmpty ? null : DateTime.tryParse(a.licenseStart);
    DateTime? end = a.licenseEnd.isEmpty ? null : DateTime.tryParse(a.licenseEnd);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          String fmt(DateTime? d) => d == null
              ? 'Pilih tanggal'
              : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          Future<void> pick(bool isStart) async {
            final picked = await showDatePicker(
              context: ctx,
              initialDate: (isStart ? start : end) ?? DateTime(2026, 6, 26),
              firstDate: DateTime(2015),
              lastDate: DateTime(2040),
            );
            if (picked != null) setLocal(() => isStart ? start = picked : end = picked);
          }

          return AlertDialog(
            // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
            // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
            scrollable: true,
            title: Text(renewal ? 'Setujui Perpanjangan' : 'Input Lisensi'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Nomor lisensi / izin keagenan')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => pick(true), child: Text('Mulai: ${fmt(start)}', style: const TextStyle(fontSize: 12)))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => pick(false), child: Text('Selesai: ${fmt(end)}', style: const TextStyle(fontSize: 12)))),
              ]),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
            ],
          );
        },
      ),
    );
    if (saved != true || ctrl.text.trim().isEmpty) return;
    String? iso(DateTime? d) => d == null
        ? null
        : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final future = renewal
        ? _repo.approveRenewal(a.id, ctrl.text.trim(), licenseStart: iso(start), licenseEnd: iso(end))
        : _repo.setLicense(a.id, ctrl.text.trim(), licenseStart: iso(start), licenseEnd: iso(end));
    await _run(() => future.then((_) {}), renewal ? 'Perpanjangan disetujui.' : 'Lisensi disimpan.');
  }

  Future<void> _pksFlow(AgentModel a) async {
    // Prefill dari data tersimpan: membuka "Atur PKS" pada agen yang PKS-nya
    // sudah diisi dulu selalu tampil kosong, seolah belum pernah disimpan.
    final numberCtrl = TextEditingController(text: a.pksNumber);
    DateTime? start = DateTime.tryParse(a.pksStart);
    DateTime? end = DateTime.tryParse(a.pksEnd);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      // Controller dibuang saat dialog benar-benar lepas dari tree, bukan tepat
      // setelah await — lihat dispose_callback.dart.
      builder: (ctx) => DisposeCallback(
        onDispose: numberCtrl.dispose,
        child: StatefulBuilder(
        builder: (ctx, setLocal) {
          String fmt(DateTime? d) => d == null ? 'Pilih tanggal' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
          Future<void> pick(bool isStart) async {
            // Dulu di-hardcode DateTime(2026, 6, 26) — kalender selalu terbuka
            // di tanggal itu, bukan di hari ini.
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: ctx,
              initialDate: (isStart ? start : end) ?? now,
              firstDate: DateTime(2015),
              lastDate: DateTime(2035),
            );
            if (picked != null) setLocal(() => isStart ? start = picked : end = picked);
          }

          return AlertDialog(
            // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
            // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
            scrollable: true,
            title: const Text('Atur PKS'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: numberCtrl, decoration: const InputDecoration(labelText: 'Nomor PKS')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => pick(true), child: Text('Mulai: ${fmt(start)}', style: const TextStyle(fontSize: 12)))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => pick(false), child: Text('Selesai: ${fmt(end)}', style: const TextStyle(fontSize: 12)))),
              ]),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
            ],
          );
        },
        ),
      ),
    );
    if (saved != true) return;
    if (numberCtrl.text.trim().isEmpty) {
      // Dulu diam-diam batal — user mengira PKS tersimpan.
      showMissingFieldsNotice(messenger, const ['Nomor PKS']);
      return;
    }
    String? iso(DateTime? d) => d == null ? null : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await _run(
      () => _repo.setPks(a.id, pksNumber: numberCtrl.text.trim(), pksStart: iso(start), pksEnd: iso(end)).then((_) {}),
      'PKS disimpan.',
    );
  }

  Future<void> _uploadDocument(AgentModel a) async {
    const types = ['PAKTA_INTEGRITAS', 'PKS', 'KTP', 'NPWP'];
    final docType = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Jenis Dokumen'),
        children: [
          for (final t in types)
            SimpleDialogOption(onPressed: () => Navigator.pop(ctx, t), child: Text(t)),
        ],
      ),
    );
    if (docType == null) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || result.files.first.bytes == null) return;
    final file = result.files.first;
    await _run(
      () => _repo.uploadDocument(a.id, docType: docType, fileBytes: file.bytes!, fileName: file.name).then((_) {}),
      'Dokumen $docType diunggah.',
    );
  }

  Future<void> _issueCifFlow(AgentModel a) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: const Text('Terbitkan CIF & Akun'),
        content: const Text('Terbitkan CIF dan buat akun login untuk agen ini? Kata sandi sementara akan ditampilkan sekali.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Terbitkan')),
        ],
      ),
    );
    if (confirm != true || _busy) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final cred = await _repo.issueCif(a.id);
      await _load();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
          // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
          scrollable: true,
          title: const Text('Akun Diterbitkan'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _credRow('CIF', cred.cif),
            _credRow('Login (NIP)', cred.loginNip),
            _credRow('Kata sandi sementara', cred.tempPassword),
            const SizedBox(height: 8),
            const Text('Bagikan kredensial ini ke agen. Kata sandi tidak ditampilkan lagi.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('$e'.replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.errorRed,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _credRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          SelectableText(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
      );
}

/// Internal marker widget so [_infoCard] can filter empty rows before rendering.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
      ]),
    );
  }
}
