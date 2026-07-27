import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/agent/agent_repository.dart';
import '../../core/providers/repository_providers.dart';
import '../providers/agent_profil_provider.dart';

/// Agent profile — agency-specific info (CIF, PKS, status, linked RMs), loaded
/// from GET /api/agents/me.
class AgentProfilScreen extends ConsumerStatefulWidget {
  const AgentProfilScreen({super.key});

  @override
  ConsumerState<AgentProfilScreen> createState() => _AgentProfilScreenState();
}

class _AgentProfilScreenState extends ConsumerState<AgentProfilScreen> {
  // State bisnis/async (repo + future load) dikelola AgentProfilNotifier.
  // Getter berikut memproksinya agar kode build/widget tetap memakai nama lama.
  AgentProfilNotifier get _notifier => ref.read(agentProfilProvider.notifier);
  AgentRepository get _repo => ref.read(agentRepoProvider);
  Future<AgentSelfModel>? get _future => ref.read(agentProfilProvider).future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Bootstrap load (pola `??=` lama) dipindah ke notifier.start().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(agentProfilProvider);
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: FutureBuilder<AgentSelfModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Gagal memuat profil'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _notifier.reload(),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            );
          }
          final agent = snapshot.data!;
          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _buildHeader(agent, topInset),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    _buildContactCard(agent),
                    const SizedBox(height: AppSpacing.lg),
                    _buildPksCard(agent),
                    const SizedBox(height: AppSpacing.lg),
                    if (agent.type == 'AGENT') ...[
                      _buildRenewalCard(agent),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    _buildLogoutButton(context),
                    const SizedBox(height: AppSpacing.sm),
                    const Text('M-BIS v2.1.0 • PT Askrindo (Persero)',
                        style: TextStyle(fontSize: 12, color: AppColors.grayStage)),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRenewalCard(AgentSelfModel agent) {
    final canRequest = agent.status == 'ACTIVE' || agent.status == 'EXPIRED';
    final pending = agent.status == 'WAITING_RENEWAL';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LISENSI',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.event_outlined, size: 18, color: AppColors.grayStage),
            const SizedBox(width: 8),
            Text('Berlaku s/d: ${agent.licenseEnd.isEmpty ? '-' : agent.licenseEnd}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ]),
          if (agent.status == 'EXPIRED') ...[
            const SizedBox(height: 6),
            const Text('Lisensi berakhir — akun dinonaktifkan hingga perpanjangan disetujui.',
                style: TextStyle(fontSize: 11, color: AppColors.errorRed)),
          ],
          const SizedBox(height: 12),
          if (pending)
            const Text('Permohonan perpanjangan sedang diproses admin.',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryOrange, fontWeight: FontWeight.w600))
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: canRequest ? _openRenewalSheet : null,
                icon: const Icon(Icons.autorenew, size: 18),
                label: const Text('Ajukan Perpanjangan'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryNavy,
                  side: const BorderSide(color: AppColors.primaryNavy, width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openRenewalSheet() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _RenewalSheet(repo: _repo),
    );
    if (ok == true && mounted) {
      _notifier.reload();
    }
  }

  Widget _buildHeader(AgentSelfModel agent, double topInset) {
    final roleLabel = agent.type == 'TPM' ? 'Tenaga Pemasaran Mikro' : 'Agen Asuransi';
    return Container(
      color: AppColors.primaryNavy,
      padding: EdgeInsets.fromLTRB(AppSpacing.xl, topInset + AppSpacing.xl,
          AppSpacing.xl, AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profil Agen',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.secondaryOrange,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 3),
                ),
                alignment: Alignment.center,
                child: Text(agent.initials,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent.name,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(roleLabel,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.7))),
                    const SizedBox(height: 2),
                    Text('CIF: ${agent.cif}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _headerInfo('Kanwil', agent.kanwil),
              const SizedBox(width: AppSpacing.sm),
              _headerInfo('Cabang', agent.cabang),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerInfo(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: AppRadius.radiusMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(AgentSelfModel agent) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('INFORMASI KONTAK'),
          const SizedBox(height: 12),
          _kv('Email', agent.email),
          const Divider(height: 20, color: AppColors.border),
          _kv('Telepon', agent.phone),
        ],
      ),
    );
  }

  Widget _buildPksCard(AgentSelfModel agent) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _cardTitle('PERJANJIAN KERJA SAMA (PKS)'),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: AppColors.greenLight,
                    borderRadius: BorderRadius.circular(50)),
                child: Text(agent.status,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.successGreen)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _kv('No. PKS', agent.pksNumber),
          const Divider(height: 20, color: AppColors.border),
          _kv('Masa Berlaku', agent.pksPeriod),
        ],
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () async {
          await MbisApp.of(context)?.handleLogout();
          if (!context.mounted) return;
          context.go('/login');
        },
        icon: const Icon(Icons.logout, size: 18, color: AppColors.errorRed),
        label: const Text('Keluar',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.errorRed)),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.redLight,
          side: const BorderSide(color: AppColors.errorRed, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
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
  }

  Widget _cardTitle(String text) => Text(text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: 0.5));
}

/// Bottom sheet where an agent uploads the renewal documents (updated Surat
/// Pernyataan + Dokumen Pipeline) and submits the request. Pops `true` on success.
class _RenewalSheet extends StatefulWidget {
  final AgentRepository repo;
  const _RenewalSheet({required this.repo});

  @override
  State<_RenewalSheet> createState() => _RenewalSheetState();
}

class _RenewalSheetState extends State<_RenewalSheet> {
  static const _labels = {
    'SURAT_PERNYATAAN': 'Surat Pernyataan (terbaru)',
    'PIPELINE': 'Dokumen Pipeline',
  };
  final Map<String, PlatformFile?> _files = {'SURAT_PERNYATAAN': null, 'PIPELINE': null};
  bool _busy = false;

  Future<void> _pick(String code) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res == null || res.files.isEmpty || res.files.first.bytes == null) return;
    if (!mounted) return;
    setState(() => _files[code] = res.files.first);
  }

  Future<void> _submit() async {
    final missing = _files.entries.where((e) => e.value?.bytes == null).map((e) => _labels[e.key]).toList();
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lengkapi: ${missing.join(', ')}'),
        backgroundColor: AppColors.errorRed,
      ));
      return;
    }
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      for (final e in _files.entries) {
        final f = e.value!;
        await widget.repo.uploadRenewalDocument(docType: e.key, fileBytes: f.bytes!, fileName: f.name);
      }
      await widget.repo.requestRenewal();
      if (!mounted) return;
      navigator.pop(true);
      messenger.showSnackBar(const SnackBar(
        content: Text('Permohonan perpanjangan terkirim.'),
        backgroundColor: AppColors.successGreen,
      ));
    } catch (err) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(
        content: Text('$err'.replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.errorRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      // Isi sheet bisa lebih tinggi dari layar (mis. daftar chip kategori,
      // atau keyboard terbuka di layar pendek) -> harus bisa di-scroll,
      // kalau tidak muncul garis kuning 'BOTTOM OVERFLOWED BY ... PIXELS'.
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ajukan Perpanjangan Lisensi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Unggah dokumen yang perlu diperbarui, lalu kirim untuk disetujui admin.',
              style: TextStyle(fontSize: 12, color: AppColors.grayStage)),
          const SizedBox(height: 16),
          for (final code in _files.keys) ...[
            _docRow(code),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              ),
              child: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Kirim Permohonan', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _docRow(String code) {
    final f = _files[code];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_labels[code]!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(f != null ? f.name : 'Belum dipilih',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: f != null ? AppColors.successGreen : AppColors.grayStage)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: _busy ? null : () => _pick(code),
            icon: const Icon(Icons.attach_file, size: 16),
            label: Text(f != null ? 'Ganti' : 'Pilih'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryNavy),
          ),
        ],
      ),
    );
  }
}
