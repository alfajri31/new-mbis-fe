import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../src/config/app_config.dart';
import '../../src/legal/legal_routes.dart';
import '../../theme/app_theme.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/max_width_body.dart';

/// "Privasi & Akun" — memenuhi dua kewajiban kebijakan Google Play yang harus
/// ada **di dalam aplikasi**, bukan hanya di halaman store:
///
///  1. Tautan kebijakan privasi yang bisa dibuka dari dalam app.
///  2. Jalur penghapusan akun yang mudah ditemukan, plus URL web yang bisa
///     diakses tanpa memasang aplikasi (dilampirkan di Data safety form).
///
/// Catatan alur: akun M-BIS **tidak** dibuat sendiri oleh pengguna — admin yang
/// membuatnya (`POST /api/auth/admin/users`), dan akun Agen didaftarkan oleh RM.
/// Karena itu penghapusan berupa *permintaan* terverifikasi ke pengelola, bukan
/// tombol hapus instan: menghapus akun secara sepihak dari perangkat akan
/// memutus jejak pipeline/kunjungan yang masih dipakai unit kerja lain.
/// Sebagian data juga wajib ditahan karena ketentuan arsip perusahaan asuransi —
/// itu dinyatakan terbuka di layar ini, sesuai syarat Play.
///
/// Kebijakan privasinya sendiri **ada di dalam aplikasi** — layar
/// [KebijakanPrivasiScreen] di `$basePath/kebijakan`. Dulu tombolnya melempar ke
/// browser, yang berarti kebijakan tidak terbaca saat pengguna lapangan tanpa
/// sinyal, dan hilang sama sekali kalau `PRIVACY_POLICY_URL` lupa diisi. Tautan
/// web tetap ada, tapi kini di kaki layar kebijakan itu — sebagai salinan untuk
/// dibagikan, bukan satu-satunya jalan.
///
/// URL hapus akun tetap dibaca dari [AppConfig] (`--dart-define`), tidak
/// di-hardcode; `scripts/build-aab.*` menolak membangun rilis prod bila kosong.
class PrivasiAkunScreen extends StatelessWidget {
  /// Lokasi layar ini pada tabel rute — `/profil/privasi` atau
  /// `/agent/profil/privasi`. Dipakai untuk menyusun tautan ke sub-rute
  /// `kebijakan` supaya tombol Kembali pulang ke shell yang benar.
  final String basePath;

  const PrivasiAkunScreen({super.key, this.basePath = '/profil/privasi'});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'Privasi & Akun', showBack: true),
      body: MaxWidthBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, topInset + AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          children: [
            const Text(
              'Bagaimana M-BIS memakai data Anda, dan cara mengajukan '
              'penghapusan akun.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            _kebijakanCard(context),
            const SizedBox(height: AppSpacing.lg),
            _hapusAkunCard(context),
            const SizedBox(height: AppSpacing.lg),
            _kontakCard(context),
          ],
        ),
      ),
    );
  }

  // ── Kartu 1: kebijakan privasi ─────────────────────────────────────────────

  Widget _kebijakanCard(BuildContext context) {
    return _card(
      icon: Icons.privacy_tip_outlined,
      iconBg: AppColors.navyBg,
      iconColor: AppColors.primaryNavy,
      title: 'Kebijakan Privasi',
      body: const Text(
        'Menjelaskan data apa yang dikumpulkan M-BIS (identitas pegawai, lokasi '
        'kunjungan, dan data nasabah yang Anda input), untuk apa dipakai, dan '
        'berapa lama disimpan.',
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
      ),
      // Naskah lengkapnya terbundel di aplikasi, jadi tombol ini membuka layar
      // — bukan browser. Tidak butuh jaringan dan tidak bisa "hilang" karena
      // konfigurasi build yang lupa diisi.
      action: _navButton(
        context,
        label: 'Buka Kebijakan Privasi',
        route: '$basePath/kebijakan',
      ),
    );
  }

  // ── Kartu 2: penghapusan akun ──────────────────────────────────────────────

  Widget _hapusAkunCard(BuildContext context) {
    return _card(
      icon: Icons.person_remove_outlined,
      iconBg: AppColors.redLight,
      iconColor: AppColors.errorRed,
      title: 'Hapus Akun',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Akun M-BIS dibuat dan dikelola oleh admin perusahaan, sehingga '
            'penghapusan diproses lewat permintaan terverifikasi.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Yang dihapus:',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          ..._bullets(const [
            'Akun & kredensial login Anda',
            'Profil pengguna dan tautan SSO',
            'Token perangkat untuk notifikasi',
          ]),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Yang tetap disimpan:',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          ..._bullets(const [
            'Catatan pipeline, kunjungan, dan transaksi yang sudah tercatat — '
                'wajib diarsipkan sesuai ketentuan penyimpanan dokumen '
                'perusahaan asuransi, dan dilepas dari identitas Anda',
          ]),
        ],
      ),
      // Halaman hapus akun kini rute publik di dalam aplikasi, bukan tautan
      // keluar — sama seperti kebijakan privasi. Tidak butuh jaringan, dan tidak
      // bisa hilang gara-gara ACCOUNT_DELETION_URL lupa diisi saat build.
      action: _navButton(
        context,
        label: 'Ajukan Penghapusan Akun',
        route: rutePublikHapusAkun,
        danger: true,
      ),
    );
  }

  // ── Kartu 3: kontak ────────────────────────────────────────────────────────

  Widget _kontakCard(BuildContext context) {
    final email = AppConfig.privacyContactEmail;
    return _card(
      icon: Icons.mail_outline,
      iconBg: AppColors.greenLight,
      iconColor: AppColors.successGreen,
      title: 'Pertanyaan Privasi',
      body: Text(
        email.isEmpty
            ? 'Hubungi admin M-BIS unit Anda untuk pertanyaan seputar data pribadi.'
            : 'Kirim pertanyaan seputar data pribadi Anda ke $email.',
        style: const TextStyle(
            fontSize: 13, color: AppColors.textSecondary, height: 1.5),
      ),
      action: email.isEmpty
          ? null
          : _linkButton(
              context,
              label: 'Kirim Email',
              icon: Icons.send_outlined,
              url: 'mailto:$email?subject=Pertanyaan%20Privasi%20M-BIS',
              kosongPesan: '',
            ),
    );
  }

  // ── Bagian umum ────────────────────────────────────────────────────────────

  List<Widget> _bullets(List<String> items) => [
        for (final t in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 8),
                  child: Icon(Icons.circle, size: 5, color: AppColors.grayStage),
                ),
                Expanded(
                  child: Text(
                    t,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
      ];

  /// Tombol ke layar lain di dalam aplikasi (bukan tautan keluar), jadi tidak
  /// ada URL yang bisa kosong dan tidak ada jaringan yang perlu hidup.
  Widget _navButton(
    BuildContext context, {
    required String label,
    required String route,
    bool danger = false,
  }) {
    final color = danger ? AppColors.errorRed : AppColors.primaryNavy;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        // push, bukan go: tombol kembali harus memulangkan ke Privasi & Akun.
        onPressed: () => context.push(route),
        icon: Icon(
            danger ? Icons.person_remove_outlined : Icons.description_outlined,
            size: 18,
            color: color),
        label: Text(label,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        ),
      ),
    );
  }

  Widget _linkButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required String url,
    required String kosongPesan,
    bool danger = false,
  }) {
    final color = danger ? AppColors.errorRed : AppColors.primaryNavy;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => _open(context, url, kosongPesan),
        icon: Icon(icon, size: 18, color: color),
        label: Text(label,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        ),
      ),
    );
  }

  /// Membuka [url] di browser/aplikasi eksternal. URL kosong hanya mungkin pada
  /// build non-prod (build rilis diblokir oleh script), jadi cukup ditandai lewat
  /// snackbar alih-alih menyembunyikan tombolnya — supaya kelalaian konfigurasi
  /// terlihat saat uji, bukan hilang diam-diam.
  Future<void> _open(BuildContext context, String url, String kosongPesan) async {
    final messenger = ScaffoldMessenger.of(context);
    if (url.isEmpty) {
      messenger.showSnackBar(SnackBar(
        content: Text(kosongPesan),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.errorRed,
      ));
      return;
    }
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Tidak dapat membuka tautan'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.errorRed,
      ));
    }
  }

  Widget _card({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required Widget body,
    Widget? action,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radius2Xl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level2],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(color: iconBg, borderRadius: AppRadius.radiusLg),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          body,
          if (action != null) ...[
            const SizedBox(height: AppSpacing.lg),
            action,
          ],
        ],
      ),
    );
  }
}
