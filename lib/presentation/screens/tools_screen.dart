import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../widgets/glass_app_bar.dart';
import '../providers/assistant_provider.dart' show canUseAssistant;

/// S-301 — Tools Hub. Entry point to the field tools.
class ToolsScreen extends StatelessWidget {
  /// Route prefix the tool cards link under. RM opens this as tab 4 ('/tools');
  /// BM/ADMIN reach it from the Kelola hub ('/kelola/tools'), whose tab 4 is the
  /// RM performance list. The tool sub-routes are declared under both prefixes,
  /// so linking under the one we were opened from keeps back going to that hub.
  final String basePath;

  const ToolsScreen({super.key, this.basePath = '/tools'});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final roles = MbisApp.of(context)?.session?.user.roles ?? const [];
    final list = roles.map((e) => e.toString()).toList();
    final supervisor = MbisApp.isSupervisorRole(list);

    final tools = <_Tool>[
      _Tool(
        icon: '📚',
        label: 'Product Knowledge',
        desc:
            'Panduan produk Askrindo per lini usaha untuk bahan presentasi ke nasabah',
        bg: AppColors.navyBg,
        route: '$basePath/product-knowledge',
      ),
      // SATU peta untuk semua peran. Dulu ada dua layar terpisah karena layar RM
      // memakai `/api/visits/me` yang hanya berisi kunjungan pemanggil — penyelia
      // membukanya dan mendapat peta kosong. Peta ini memakai endpoint ber-cakupan
      // (`/api/dashboard/visit-locations`) yang sejak awal sudah menangani RM
      // sebagai DataScope OWNER, jadi dua layar itu tidak pernah benar-benar
      // dibutuhkan — dan dua peta bernama mirip justru sudah terbukti membuat
      // orang (termasuk penulis backlog) salah menunjuk layar.
      _Tool(
        icon: '📍',
        label: 'Peta Kunjungan',
        desc: supervisor
            ? 'Peta lokasi kunjungan RM dalam cakupan kantor Anda, bisa difilter per kantor'
            : 'Peta lokasi & riwayat kunjungan lapangan Anda, verifikasi visit nasabah',
        bg: AppColors.orangeLight,
        route: '$basePath/visit-map',
      ),
      _Tool(
        icon: '🧮',
        label: 'Kalkulator Premi',
        desc:
            'Hitung premi kotor & bersih secara real-time berdasarkan rate & TSI',
        bg: AppColors.greenLight,
        route: '$basePath/kalkulator-premi',
      ),
    ];

    // AI Assistant — RM, BM, pimpinan Kanwil, dan KUP (CR-17). ADMIN mengatur
    // aktivitasnya lewat Profil → Kelola Aktivitas AI, bukan dari sini.
    if (canUseAssistant(roles)) {
      tools.add(
        _Tool(
          icon: '🤖',
          asset: 'assets/images/maskot.png',
          label: 'Tanya Dubi',
          desc: 'Kenali customer, rekomendasi produk, briefing, dll.',
          bg: AppColors.navyBg,
          route: '$basePath/assistant',
        ),
      );
    }

    // Admin/PJD only: record premium payments that release agent commissions.
    if (roles.contains('ADMIN')) {
      tools.add(
        _Tool(
          icon: '💰',
          label: 'Kelola Premi & Komisi',
          desc:
              'Catat pembayaran premi nasabah; tiap pembayaran melepas komisi agen',
          bg: AppColors.navyBg,
          route: '$basePath/kelola-premi',
        ),
      );
    }

    // Saat dibuka RM sebagai tab bottom-nav ('/tools') tak perlu back. Saat BM/ADMIN
    // membukanya dari hub Kelola ('/kelola/tools') ini rute yang di-push, jadi beri
    // tombol back yang kembali ke hub Kelola (pakai context.pop go_router, bukan
    // Navigator.pop, agar URL ikut mundur; fallback ke hub bila tak ada yang bisa di-pop).
    final bool pushed = basePath != '/tools';
    final String hubPath = basePath.substring(0, basePath.lastIndexOf('/'));

    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: 'Tools',
        // Body layar ini full-bleed (ListView tanpa MaxWidthBody).
        contentMaxWidth: double.infinity,
        leading: pushed
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go(hubPath),
              )
            : null,
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          topInset + AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Text(
            supervisor
                ? 'Alat bantu lapangan & pemantauan tim'
                : 'Alat bantu lapangan untuk RM',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final t in tools) ...[
            _buildToolCard(context, t),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, _Tool tool) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radius2Xl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level2],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radius2Xl,
        child: InkWell(
          borderRadius: AppRadius.radius2Xl,
          // Routed (URL-based) so a refresh while the tool is open restores it.
          // The deferred GPS chunk is loaded by the route's loader widget.
          onTap: () => context.go(tool.route),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: tool.bg,
                    borderRadius: AppRadius.radius2Xl,
                  ),
                  alignment: Alignment.center,
                  child: tool.asset != null
                      ? Image.asset(
                          tool.asset!,
                          width: 36,
                          height: 36,
                          errorBuilder: (_, _, _) => Text(
                            tool.icon,
                            style: const TextStyle(fontSize: 28),
                          ),
                        )
                      : Text(tool.icon, style: const TextStyle(fontSize: 28)),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tool.label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tool.desc,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.grayStage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tool {
  final String icon;

  /// Optional image asset shown instead of the emoji [icon] (e.g. the mascot).
  final String? asset;
  final String label;
  final String desc;
  final Color bg;

  /// URL the tool card navigates to (a sub-route of /tools), so the tool is
  /// addressable and survives a web refresh.
  final String route;

  const _Tool({
    required this.icon,
    this.asset,
    required this.label,
    required this.desc,
    required this.bg,
    required this.route,
  });
}
