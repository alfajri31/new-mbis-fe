import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/agent/agent_repository.dart';
import '../../src/announcement/announcement_banner.dart';
import '../../utils/format.dart';
import '../../core/providers/app_providers.dart';
import '../providers/agent_dashboard_provider.dart';
import '../widgets/home_top_bar.dart';

/// Agent dashboard — agent identity + performance, loaded from the API
/// (GET /api/agents/me and /api/agents/me/dashboard).
class AgentDashboardScreen extends ConsumerStatefulWidget {
  final void Function(int)? onTabChange;
  const AgentDashboardScreen({super.key, this.onTabChange});

  @override
  ConsumerState<AgentDashboardScreen> createState() =>
      _AgentDashboardScreenState();
}

/// Full-bleed banner height and how far the main card rides up over it.
const double _bannerHeight = 158;
const double _cardOverlap = 24;

class _AgentDashboardScreenState extends ConsumerState<AgentDashboardScreen> {
  // State bisnis/async (future data) dikelola AgentDashboardNotifier. Getter
  // berikut memproksinya agar build/widget di bawah tetap memakai nama lama.
  AgentDashboardNotifier get _notifier =>
      ref.read(agentDashboardProvider.notifier);
  Future<AgentDashboardData>? get _future =>
      ref.read(agentDashboardProvider).future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Trigger load sebelum build pertama (samakan timing lama, hindari flash
    // 1-frame kosong/error dari FutureBuilder). Guard sekali ada di notifier.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat future berubah.
    ref.watch(agentDashboardProvider);
    final session = MbisApp.of(context)?.session;
    final name = session?.user.name ?? 'Agen';
    // The navy top bar now reaches up under the status bar, so use light icons.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bgScreen,
        body: Column(
          children: [
            HomeTopBar(
              name: name,
              initials: HomeTopBar.initialsOf(name),
              profileRoute: '/agent/profil',
            ),
            Expanded(
              child: FutureBuilder<AgentDashboardData>(
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
                          const Text('Gagal memuat dashboard'),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _notifier.reload(),
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    );
                  }
                  return _buildContent(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AgentDashboardData data) {
    // `_apiClient` lama selalu non-null setelah didChangeDependencies, jadi
    // cek `_apiClient != null` selalu benar — kini cukup cek ada pengumuman.
    final apiClient = ref.read(apiClientProvider);
    final hasBanner = data.announcements.isNotEmpty;
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasBanner)
            AnnouncementBanner(
              apiClient: apiClient,
              announcements: data.announcements,
              height: _bannerHeight,
              dotsBottomInset: _cardOverlap + 10,
            ),
          Transform.translate(
            // Pull the main card up so it slightly overlaps the banner; when
            // there's no banner, keep normal top spacing instead.
            offset: Offset(0, hasBanner ? -_cardOverlap : 0),
            child: Padding(
              padding: EdgeInsets.fromLTRB(AppSpacing.lg,
                  hasBanner ? 0 : AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAgentSummaryCard(data.agent, data.perf),
                  const SizedBox(height: AppSpacing.xl),
                  _sectionTitle('Kartu Kinerja'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildPerfGrid(data.perf),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The white "main card" that rides over the banner — agent identity badges,
  /// office line, and the three quick stats moved out of the old navy header.
  Widget _buildAgentSummaryCard(AgentSelfModel agent, AgentDashboardModel perf) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level2],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (agent.cif.isNotEmpty)
                _summaryBadge(
                  'CIF ${agent.cif}',
                  AppColors.primaryNavy.withValues(alpha: 0.08),
                  AppColors.primaryNavy,
                ),
              if (agent.cif.isNotEmpty) const SizedBox(width: 8),
              _summaryBadge(
                agent.status,
                AppColors.greenLight,
                AppColors.successGreen,
              ),
            ],
          ),
          if (agent.cabang.isNotEmpty || agent.kanwil.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              [agent.cabang, agent.kanwil].where((e) => e.isNotEmpty).join(' • '),
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _statCell(Icons.people_alt_outlined, '${perf.totalCustomers}',
                  'Customer'),
              _statDivider(),
              _statCell(Icons.account_tree_outlined, '${perf.pipelineAktif}',
                  'Pipeline Aktif'),
              _statDivider(),
              _statCell(Icons.payments_outlined,
                  AppFormat.currencyShort(perf.komisiSiapCair), 'Komisi'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  Widget _statCell(IconData icon, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.secondaryOrange),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryNavy)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _statDivider() =>
      Container(width: 1, height: 32, color: AppColors.border);

  Widget _buildPerfGrid(AgentDashboardModel perf) {
    final items =
        <({String label, String value, String? suffix, IconData icon, Color color})>[
      (label: 'Target YTD', value: AppFormat.currencyShort(perf.targetYtd), suffix: null, icon: Icons.track_changes_outlined, color: AppColors.primaryNavy),
      (label: 'Realisasi YTD', value: AppFormat.currencyShort(perf.produksiPremiYtd), suffix: null, icon: Icons.trending_up, color: AppColors.successGreen),
      (label: 'Komisi YTD', value: AppFormat.currencyShort(perf.komisiYtd), suffix: null, icon: Icons.payments_outlined, color: AppColors.secondaryOrange),
      (label: 'Pipeline Aktif', value: '${perf.pipelineAktif}', suffix: ' pipeline', icon: Icons.account_tree_outlined, color: AppColors.primaryNavyLight),
      (label: 'Nilai Pipeline', value: AppFormat.currencyShort(perf.nilaiPipeline), suffix: null, icon: Icons.show_chart, color: AppColors.purpleAccent),
      (label: 'Success Rate', value: '${perf.successRatePercent}', suffix: '%', icon: Icons.percent, color: AppColors.successGreen),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final i = items[index];
        return _statCard(i.label, i.value, i.suffix, i.icon, i.color);
      },
    );
  }

  Widget _statCard(
      String label, String value, String? suffix, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800, color: color)),
              ),
              if (suffix != null) ...[
                const SizedBox(width: 2),
                Text(suffix.trim(),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary),
      );
}
