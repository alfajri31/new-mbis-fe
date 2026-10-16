import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/auth/roles.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/max_width_body.dart';

/// "Kelola" hub — the extra tab for ADMIN, BM, RO, and KUP (all keep the RM performance
/// list on tab 4). Surfaces the management consoles directly so they no longer
/// have to be opened one-by-one from the Profile screen. Each console is declared
/// under both /profil/* and /kelola/* (see `_konsolSubRoutes`), so these cards
/// link to the /kelola/* copy and back returns here rather than to the Profile
/// tab.
///
/// Cards are role-filtered by [_KelolaItem.roles]: BM sees only the consoles it
/// is actually permitted (Tools, Manajemen Agen, Pindah RM), matching the gating
/// already applied to the same entry points on the Profile screen. The backend
/// gates the data regardless — this filter is so we don't show a door that 403s.
class KelolaScreen extends StatelessWidget {
  const KelolaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    final roles = MbisApp.of(context)?.session?.user.roles ?? const [];
    const items = <_KelolaItem>[
      _KelolaItem(
        icon: Icons.construction_outlined,
        label: 'Tools',
        desc: 'Product knowledge, kalkulator premi, dan peta kunjungan tim',
        bg: AppColors.greenLight,
        route: '/kelola/tools',
        // RO & KUP ikut: mereka juga bekerja di lapangan (KUP pada dasarnya RM
        // yang merangkap ketua), dan tab ke-4 mereka dipakai daftar kinerja RM
        // sehingga tak ada ruang untuk tab Tools tersendiri.
        roles: {'ADMIN', 'BM', 'RO', 'KUP'},
      ),
      _KelolaItem(
        icon: Icons.location_on_outlined,
        label: 'Visit RM',
        desc:
            'Pantau kunjungan RM: foto, tanggal & stage pipeline, termasuk RM yang belum visit',
        bg: AppColors.navyBg,
        badge: 'Pinca · Pinwil · Admin',
        route: '/kelola/visit-rm',
        roles: {'ADMIN', 'BM', 'RO', 'KUP'},
      ),
      _KelolaItem(
        icon: Icons.manage_accounts_outlined,
        label: 'Kelola Akun',
        desc: 'Buat & kelola akun, peran, kantor, reset password, dan nonaktifkan',
        bg: AppColors.navyBg,
        route: '/kelola/akun',
      ),
      _KelolaItem(
        icon: Icons.tune,
        label: 'Kelola Master Data',
        desc: 'Atur nilai dropdown, produk, rate COB, dan daftar broker',
        bg: AppColors.greenLight,
        route: '/kelola/master-data',
        // Divisi kantor pusat masuk lewat sini ke bagian yang jadi miliknya saja
        // (produk, BUMN, broker, template agen) — layarnya menyaring sendiri per
        // peran. DIV_AUDIT & DIV_PROGRAM tidak ikut: mereka hanya melihat.
        roles: {'ADMIN', ...Roles.curatorDivisions},
      ),
      _KelolaItem(
        icon: Icons.settings_outlined,
        label: 'Pengaturan Tarif & Biaya',
        desc:
            'Atur biaya admin, rate PSAKDI & PA Xtra, batas UP /santunan dan diskon maksimal',
        bg: AppColors.navyBg,
        route: '/kelola/setting-rates-charges',
        badge: 'UW · Admin',
        roles: {'ADMIN', 'BM', 'RO', 'KUP', ...Roles.curatorDivisions},
      ),
      _KelolaItem(
        icon: Icons.smart_toy_outlined,
        label: 'Kelola Aktivitas AI',
        desc: 'Rakit aktivitas Asisten AI & pilih model AI yang dipakai RM',
        bg: AppColors.navyBg,
        route: '/kelola/aktivitas-ai',
      ),
      _KelolaItem(
        icon: Icons.campaign_outlined,
        label: 'Kelola Pengumuman',
        desc: 'Buat & atur pengumuman yang tampil di beranda pengguna',
        bg: AppColors.orangeLight,
        route: '/kelola/pengumuman',
      ),
      _KelolaItem(
        icon: Icons.badge_outlined,
        label: 'Manajemen Agen',
        desc: 'Worklist onboarding agen/TPM: persetujuan, lisensi, dan CIF',
        bg: AppColors.navyBg,
        route: '/kelola/manajemen-agen',
        // Persetujuan pengajuan agen dilakukan pimpinan kantor RM: BM, RO, KUP.
        // DIV_AGEN memegang sisi kantor pusatnya: lisensi, perpanjangan, dan CIF.
        roles: {'ADMIN', 'BM', 'RO', 'KUP', Roles.divAgen},
      ),
      _KelolaItem(
        icon: Icons.swap_horiz,
        label: 'Pindah RM',
        desc: 'Alihkan portofolio nasabah & pipeline ke RM lain saat cuti/berhenti '
            '(bukan pindah cabang)',
        bg: AppColors.greenLight,
        route: '/kelola/pindah-rm',
        // Semua pimpinan kantor memindahkan portofolio di kantornya.
        roles: {'ADMIN', 'BM', 'RO', 'KUP'},
      ),
      _KelolaItem(
        icon: Icons.moving_outlined,
        label: 'Pemindahan Cabang RM',
        desc: 'PJD tentukan cabang tujuan; Pinca cabang asal alokasikan portofolio',
        bg: AppColors.navyBg,
        route: '/kelola/pemindahan-cabang',
        // PJD (ADMIN) creates; the old branch's Pinca (BM/RO/KUP) allocates.
        roles: {'ADMIN', 'BM', 'RO', 'KUP'},
      ),
      _KelolaItem(
        icon: Icons.compare_arrows,
        label: 'Manajemen Referral',
        desc: 'Setujui/tolak referral pipeline lintas cabang & assign RM tujuan',
        bg: AppColors.navyBg,
        route: '/kelola/referral',
        // Antrean ini memang milik pimpinan kantor: ReferralService menyaringnya
        // per cabang dan hanya menandai `actionable` untuk BM yang mengampu
        // tahap berjalan. Tanpa baris ini kartunya jatuh ke default ADMIN-only,
        // sehingga BM cabang tujuan melihat statusnya "Menunggu BM Tujuan" tanpa
        // punya satu pun pintu untuk menyetujuinya.
        roles: {'ADMIN', 'BM', 'RO', 'KUP'},
      ),
      _KelolaItem(
        icon: Icons.payments_outlined,
        label: 'Kelola Premi & Komisi',
        desc: 'Catat pembayaran premi nasabah; tiap pembayaran melepas komisi agen',
        bg: AppColors.orangeLight,
        route: '/kelola/kelola-premi',
      ),
      _KelolaItem(
        icon: Icons.file_download_outlined,
        label: 'Ekspor Data',
        desc: 'Unduh report kinerja (customer, pipeline, kunjungan) sebagai Excel per rentang tanggal',
        bg: AppColors.greenLight,
        route: '/kelola/export-data',
      ),
      _KelolaItem(
        icon: Icons.file_upload_outlined,
        label: 'Impor Pipeline',
        desc: 'Impor pipeline WON dari RM yang belum diinput manual, via template Excel',
        bg: AppColors.orangeLight,
        route: '/kelola/import-pipeline',
      ),
      _KelolaItem(
        icon: Icons.fact_check_outlined,
        // Satu entri untuk keduanya: berkas rekap pusat memuat kolom Target dan
        // Realisasi berdampingan, jadi dua menu terpisah berarti mengunggah berkas
        // yang sama dua kali — dan kalau salah satu terlewat, dashboard
        // membandingkan realisasi bulan ini dengan target bulan lalu.
        label: 'Impor Target & Realisasi',
        desc: 'Unggah rekap bulanan dari pusat sekali untuk mengisi target dan '
            'realisasi; realisasi pipeline WON tetap utuh',
        bg: AppColors.greenLight,
        route: '/kelola/import-realisasi',
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'Kelola', contentMaxWidth: MaxWidthBody.defaultMaxWidth),
      body: MaxWidthBody(
        child: ListView(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.lg, topInset + AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        children: [
          const Text(
            'Konsol administrasi & pengaturan sistem',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final item in items.where((i) => roles.any(i.roles.contains))) ...[
            _buildCard(context, item),
            const SizedBox(height: 14),
          ],
        ],
      ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _KelolaItem item) {
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
          onTap: () => context.go(item.route),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: item.bg,
                    borderRadius: AppRadius.radius2Xl,
                  ),
                  alignment: Alignment.center,
                  child: Icon(item.icon, size: 26, color: AppColors.primaryNavy),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: item.label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          children: [
                            if (item.badge != null) ...[
                              const TextSpan(text: ' '),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.badgeP2Bg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.badge!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.alertTitle,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(item.desc,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.chevron_right, size: 20, color: AppColors.grayStage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KelolaItem {
  final IconData icon;
  final String label;
  final String desc;
  final Color bg;
  final String route;

  /// Roles allowed to see this card. Defaults to ADMIN-only: every console here
  /// is admin-gated on the backend unless stated otherwise, so a new entry stays
  /// invisible to BM until someone widens it deliberately.
  final Set<String> roles;
  final String? badge;

  const _KelolaItem({
    required this.icon,
    required this.label,
    required this.desc,
    required this.bg,
    required this.route,
    this.roles = const {'ADMIN'},
    this.badge,
  });
}
