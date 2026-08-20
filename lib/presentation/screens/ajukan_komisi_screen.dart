import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../src/agent/agent_repository.dart';
import '../providers/ajukan_komisi_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/state_views.dart';

/// Agent "Komisi" tab. Shows the commission that is ready to be disbursed —
/// released tranche by tranche as the customer's premi is paid (rate × paid
/// amount) — and links out to the external Fintrack portal where the actual
/// pencairan (pengajuan) happens. The submission itself does NOT run in this
/// app; from here the agent only sees what is claimable and opens Fintrack.
class AjukanKomisiScreen extends ConsumerStatefulWidget {
  const AjukanKomisiScreen({super.key});

  @override
  ConsumerState<AjukanKomisiScreen> createState() => _AjukanKomisiScreenState();
}

class _AjukanKomisiScreenState extends ConsumerState<AjukanKomisiScreen> {
  // Data async (komisi + URL Fintrack) dikelola AjukanKomisiNotifier. Getter
  // memproksinya agar kode build/widget di bawah tetap memakai nama lama.
  AjukanKomisiState get _aks => ref.read(ajukanKomisiProvider);
  AjukanKomisiNotifier get _notifier => ref.read(ajukanKomisiProvider.notifier);

  Future<List<CommissionModel>>? get _future => _aks.future;
  String get _fintrackUrl => _aks.fintrackUrl;

  // Trigger sekali. FutureBuilder+didChangeDependencies: mulai load DI SINI
  // (sebelum build pertama) agar tak ada kedip 1-frame. Dulu guard `_repo == null`.
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifier.start();
      });
    }
  }

  void _reload() => _notifier.reload();

  Future<void> _openFintrack() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      Uri.parse(_fintrackUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat membuka portal Fintrack'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }

  String _rupiah(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(ajukanKomisiProvider);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'Komisi', contentMaxWidth: double.infinity),
      body: FutureBuilder<List<CommissionModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Padding(
              padding: EdgeInsets.only(top: topInset),
              child: ErrorStateView(
                message: 'Gagal memuat komisi',
                onRetry: () async => _reload(),
              ),
            );
          }
          // Claimable = tranches released by premi payments and not yet disbursed.
          final ready = snapshot.data!.where((c) => !c.isSubmitted).toList();
          final total = ready.fold<double>(0, (sum, c) => sum + c.amount);
          return RefreshIndicator(
            color: AppColors.primaryNavy,
            displacement: topInset,
            onRefresh: () async => _reload(),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, topInset + AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              children: [
                _summaryCard(total),
                const SizedBox(height: AppSpacing.xl),
                _sectionTitle('Rincian Komisi Siap Dicairkan', ready.length),
                const SizedBox(height: AppSpacing.sm),
                if (ready.isEmpty)
                  const EmptyStateView(
                    inCard: true,
                    icon: Icons.payments_outlined,
                    title: 'Belum ada komisi siap dicairkan',
                    subtitle:
                        'Komisi muncul di sini setelah premi nasabah dibayar. Cicilan melepas komisi secara bertahap.',
                  )
                else
                  ...ready.map(_buildReadyCard),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Total claimable + the call-to-action that opens the external Fintrack portal.
  Widget _summaryCard(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryNavy, AppColors.primaryNavyDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.radiusLg,
        boxShadow: const [AppShadows.level2],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Total Komisi Siap Dicairkan',
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 6),
          Text(_rupiah(total),
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: total > 0 ? _openFintrack : null,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Cairkan via Fintrack',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondaryOrange,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.25),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Pengajuan pencairan dilakukan di portal Fintrack Askrindo. Aplikasi ini hanya menampilkan komisi yang sudah bisa dicairkan.',
            style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, int count) {
    return Row(
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
              color: AppColors.navyBg, borderRadius: BorderRadius.circular(50)),
          child: Text('$count',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryNavy)),
        ),
      ],
    );
  }

  Widget _buildReadyCard(CommissionModel c) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
          Text(c.policyNumber,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(c.customerName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          if (c.paidDate != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.payments_outlined,
                    size: 12, color: AppColors.grayStage),
                const SizedBox(width: 4),
                Text('Dari pembayaran premi ${c.paidDate}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.grayStage)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text('Nilai Komisi',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(_rupiah(c.amount),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.successGreen)),
        ],
      ),
    );
  }
}
