import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/config/app_version.dart';
import '../providers/profil_provider.dart';
// Semua layar yang terbuka dari sini dirutekan — lihat sub-rute /profil/* di
// router.dart — supaya refresh di web tidak melemparkan pengguna kembali ke
// Profil. Termasuk "Ajukan Agen / TPM", yang kini membuka daftar pengajuan RM
// (/profil/pengajuan-agen), bukan langsung formulirnya.
import '../../src/auth/roles.dart';
import 'ganti_email_screen.dart';
import 'ganti_password_screen.dart';

/// S-112 — Profil RM. Reads profile from /api/auth/me and YTD performance from
/// /api/dashboard/summary + /api/visits/me. Fields the backend doesn't expose
/// yet (kanwil/cabang/phone) are omitted rather than faked.
class ProfilScreen extends ConsumerStatefulWidget {
  const ProfilScreen({super.key});

  @override
  ConsumerState<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends ConsumerState<ProfilScreen> {
  static const _labelKeamanan = 'Keamanan & Password';
  static const _labelEmail = 'Email Akun';

  static const List<({String label, IconData icon, String section})> _menu = [
    (label: _labelKeamanan, icon: Icons.key_outlined, section: 'Pengaturan'),
    (label: _labelEmail, icon: Icons.alternate_email, section: 'Pengaturan'),
  ];

  /// Entri yang boleh dilihat pemanggil. "Email Akun" hanya untuk peran yang
  /// memang dilayani `POST /api/auth/change-email` — cermin `hasRole('RM')` di
  /// server, yang lewat hierarki peran ikut meloloskan KUP & ADMIN. Akun agen
  /// sengaja di luar: email akunnya mengikuti data agennya, bukan sebaliknya.
  List<({String label, IconData icon, String section})> _visibleMenu(BuildContext context) {
    final roles = MbisApp.of(context)?.session?.user.roles ?? const <String>[];
    final canChangeEmail = roles.any(_emailChangers.contains);
    return _menu.where((m) => m.label != _labelEmail || canChangeEmail).toList();
  }

  static const _emailChangers = {Roles.rm, Roles.kup, Roles.admin};

  // State data/loading dipindah ke ProfilNotifier. Getter memproksi agar
  // FutureBuilder & build di bawah tetap memakai nama lama tanpa diubah.
  Future<ProfileData>? get _future => ref.read(profilProvider).future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Trigger load tetap di sini (bukan post-frame) agar frame pertama sudah
    // memegang future — menghindari kedip 1-frame layar "gagal" dari FutureBuilder.
    // start() hanya memuat bila future belum ada (mirror `_future ??= _load()`).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(profilProvider.notifier).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild saat future berganti (reload).
    ref.watch(profilProvider);
    final topInset = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: FutureBuilder<ProfileData>(
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
                    onPressed: () => ref.read(profilProvider.notifier).reload(),
                    child: const Text('Coba lagi'),
                  ),
                ],
              ),
            );
          }
          return _buildContent(snapshot.data!, topInset);
        },
      ),
    );
  }

  Widget _buildContent(ProfileData profile, double topInset) {
    final sections = <String>[];
    for (final m in _menu) {
      if (!sections.contains(m.section)) sections.add(m.section);
    }
    // Admin manages everything from the dedicated "Kelola" tab, so the profile page
    // shows no management shortcuts for them (avoids duplication). Non-admin supervisors
    // (BM/RO/KUP) and RMs have no Kelola tab, so they keep their role-gated shortcuts here.
    final roles = MbisApp.of(context)?.session?.user.roles ?? const [];
    final isAdmin = roles.contains('ADMIN');
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildHeader(profile, topInset),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: [
              _buildContactCard(profile),
              const SizedBox(height: AppSpacing.lg),
              if (!isAdmin) ...[
                _buildAjukanAgenButton(context),
                _buildReferralButton(context),
                _buildKelolaPengumumanButton(context),
                _buildSettingRatesChargesButton(context),
                // "Ekspor Kunjungan Saya" dihapus (CR-13): "Ekspor Data" di bawah
                // sudah mencakupnya. `/api/export/visits` ter-scope di server, dan
                // RM tanpa filter mendapat persis kunjungannya sendiri.
                _buildExportDataButton(context),
                const SizedBox(height: AppSpacing.lg),
              ],
              for (final s in sections) ...[
                _buildMenuSection(context, s),
                const SizedBox(height: AppSpacing.lg),
              ],
              _buildPrivasiButton(context, '/profil/privasi'),
              const SizedBox(height: AppSpacing.md),
              _buildLogoutButton(context),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                labelVersiAplikasi,
                style: TextStyle(fontSize: 12, color: AppColors.grayStage),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(ProfileData profile, double topInset) {
    return Container(
      color: AppColors.primaryNavy,
      padding: EdgeInsets.fromLTRB(
          AppSpacing.xl, topInset + AppSpacing.xl, AppSpacing.xl, AppSpacing.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profil',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.secondaryOrange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 3),
                ),
                alignment: Alignment.center,
                child: Text(profile.initials,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(profile.displayTitle,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7))),
                        ),
                        if (profile.isConnect) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: const Text('Connect',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('NIP: ${profile.nip}',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _headerInfo('Kantor', profile.office),
              const SizedBox(width: AppSpacing.sm),
              _headerInfo('Role', profile.role),
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
            Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
            const SizedBox(height: 2),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(ProfileData profile) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('INFORMASI KONTAK'),
          const SizedBox(height: 12),
          _contactItem('Email', profile.email),
          const Divider(height: 20, color: AppColors.border),
          _contactItem('Kantor', profile.office),
        ],
      ),
    );
  }

  Widget _contactItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
      ],
    );
  }

  Widget _buildMenuSection(BuildContext context, String section) {
    final items =
        _visibleMenu(context).where((m) => m.section == section).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(section.toUpperCase(),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5)),
        ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: AppColors.border),
            boxShadow: const [AppShadows.level1],
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++)
                _menuItem(context, items[i].label, items[i].icon, isLast: i == items.length - 1),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuItem(BuildContext context, String label, IconData icon, {required bool isLast}) {
    return InkWell(
      onTap: () {
        if (label == _labelKeamanan) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const GantiPasswordScreen()),
          );
        } else if (label == _labelEmail) {
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const GantiEmailScreen()))
              // Email tampil di header profil (dari klaim token yang baru ditukar),
              // jadi muat ulang begitu layarnya ditutup dengan perubahan.
              .then((changed) {
            if (changed == true && mounted) {
              ref.read(profilProvider.notifier).reload();
            }
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: AppColors.navyBg, borderRadius: AppRadius.radiusSm),
              child: Icon(icon, size: 18, color: AppColors.primaryNavy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.grayStage),
          ],
        ),
      ),
    );
  }

  /// "Ajukan Agen / TPM" — SATU-SATUNYA pintu RM ke urusan agen.
  ///
  /// Dulu ia membuka formulir pendaftaran, dan pintu kedua ("Manajemen Agen")
  /// membawa RM ke konsol pengelolaan agen sekantornya. Pintu kedua itu dihapus:
  /// tugas RM berhenti begitu agennya terdaftar, dan agen yang sudah berjalan
  /// diurus pengelola agen kantor pusat. Karena melengkapi dokumen tahap-2 masih
  /// pekerjaan RM, tombol ini kini membuka DAFTAR pengajuannya sendiri —
  /// formulirnya ada di "Ajukan Baru" pada daftar itu.
  Widget _buildAjukanAgenButton(BuildContext context) {
    // Supervisors (KUP/BM/RO/DPJ) can't propose agents/TPM — hide the action.
    final roles = MbisApp.of(context)?.session?.user.roles;
    final list = (roles as List?)?.map((e) => e.toString()).toList();
    if (MbisApp.isSupervisorRole(list)) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => context.go('/profil/pengajuan-agen'),
        icon: const Icon(Icons.person_add_alt_1,
            size: 18, color: AppColors.primaryNavy),
        label: const Text('Ajukan Agen / TPM',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryNavy)),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.navyBg,
          side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        ),
      ),
    );
  }

  /// "Ekspor Data" — semua pengguna bisa unduh Pipeline & Kunjungan sebagai Excel.
  /// Data digerbang scope di server (RM → miliknya, atasan → subtree cabang); atasan
  /// juga dapat filter wilayah/cabang/RM di layar ekspor.
  Widget _buildExportDataButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () => context.go('/profil/export'),
          icon: const Icon(Icons.file_download_outlined, size: 18, color: AppColors.primaryNavy),
          label: const Text('Ekspor Data',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryNavy)),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.navyBg,
            side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          ),
        ),
      ),
    );
  }

  /// "Manajemen Referral" — supervisors approve/reject cross-branch pipeline referrals.
  Widget _buildReferralButton(BuildContext context) {
    const allowed = {'ADMIN', 'BM', 'RO', 'KUP'};
    final roles = MbisApp.of(context)?.session?.user.roles ?? const [];
    if (!roles.any(allowed.contains)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () => context.go('/profil/referral'),
          icon: const Icon(Icons.compare_arrows, size: 18, color: AppColors.primaryNavy),
          label: const Text('Manajemen Referral',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryNavy)),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.navyBg,
            side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          ),
        ),
      ),
    );
  }

  /// "Kelola Pengumuman" — only for supervisors/admin who can author announcements.
  Widget _buildKelolaPengumumanButton(BuildContext context) {
    const allowed = {'ADMIN', 'RO', 'BM'};
    final roles = MbisApp.of(context)?.session?.user.roles ?? const [];
    if (!roles.any(allowed.contains)) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () => context.go('/profil/pengumuman'),
          icon: const Icon(Icons.campaign_outlined, size: 18, color: AppColors.primaryNavy),
          label: const Text('Kelola Pengumuman',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryNavy)),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.navyBg,
            side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          ),
        ),
      ),
    );
  }

  /// "Pengaturan Tarif & Biaya" — only for UW role.
  Widget _buildSettingRatesChargesButton(BuildContext context) {
    final roles = MbisApp.of(context)?.session?.user.roles ?? const [];
    if (!roles.contains('UW')) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: () => context.go('/profil/setting-rates-charges'),
          icon: const Icon(Icons.settings_outlined, size: 18, color: AppColors.primaryNavy),
          label: const Text('Pengaturan Tarif & Biaya',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryNavy)),
          style: OutlinedButton.styleFrom(
            backgroundColor: AppColors.navyBg,
            side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          ),
        ),
      ),
    );
  }

  /// Pintu masuk ke kebijakan privasi & permintaan hapus akun. Google Play
  /// mensyaratkan keduanya "mudah ditemukan" dari dalam aplikasi, jadi ia
  /// diletakkan tepat di atas tombol Keluar — bukan dikubur di menu konsol.
  Widget _buildPrivasiButton(BuildContext context, String route) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () => context.go(route),
        icon: const Icon(Icons.privacy_tip_outlined,
            size: 18, color: AppColors.primaryNavy),
        label: const Text('Privasi & Akun',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryNavy)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        ),
      ),
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
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.errorRed)),
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

  Widget _cardTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: 0.5,
        ),
      );
}
