import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../src/legal/policy_document.dart';
import '../../theme/app_theme.dart';
import 'glass_app_bar.dart';
import 'max_width_body.dart';

/// Merender dokumen kebijakan ([PolicySection]) jadi halaman utuh.
///
/// Dipakai dua halaman yang sama-sama wajib ada untuk Google Play — kebijakan
/// privasi dan permintaan penghapusan akun — supaya keduanya tampil sebagai satu
/// keluarga dan hanya ada satu tempat memperbaiki tata letak.
///
/// **Tidak menyentuh sesi sama sekali.** Itu syarat, bukan kebetulan: kedua
/// halaman dipasang juga sebagai rute publik yang dibuka tanpa login, jadi apa
/// pun yang membaca `AuthSession` di sini akan meledak di tangan reviewer Google.
class PolicyView extends StatelessWidget {
  /// Judul di app bar.
  final String appBarTitle;

  /// Judul besar di kartu kepala.
  final String documentTitle;

  /// Baris kedua kartu kepala (nama organisasi).
  final String subtitle;

  /// Baris meta opsional, mis. tanggal berlaku. Kosong = kartunya tidak muncul.
  final List<(String, String)> meta;

  /// Spanduk peringatan di atas dokumen, mis. status draf.
  final String? banner;

  final List<PolicySection> sections;

  /// Tombol kembali di app bar. `false` untuk rute publik, yang bisa dibuka
  /// sebagai tab pertama sehingga tidak punya halaman untuk dituju.
  final bool showBack;

  const PolicyView({
    super.key,
    required this.appBarTitle,
    required this.documentTitle,
    required this.subtitle,
    required this.sections,
    this.meta = const [],
    this.banner,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    // Tabel 3 kolom tidak terbaca di ponsel; di bawah ambang ini tiap barisnya
    // dipecah jadi kartu berlabel (lihat [_table]).
    final wide = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: appBarTitle, showBack: showBack),
      body: MaxWidthBody(
        child: ListView(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, topInset + AppSpacing.sm,
              AppSpacing.lg, AppSpacing.xxxl),
          children: [
            if (banner != null) ...[
              _Banner(banner!),
              const SizedBox(height: AppSpacing.lg),
            ],
            _headerCard(),
            const SizedBox(height: AppSpacing.lg),
            for (final section in sections) ...[
              _sectionCard(context, section, wide),
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }

  Widget _headerCard() => _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              documentTitle,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
            if (meta.isNotEmpty) const SizedBox(height: AppSpacing.md),
            for (final (label, value) in meta)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '$label: $value',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.grayStage),
                ),
              ),
          ],
        ),
      );

  Widget _sectionCard(BuildContext context, PolicySection section, bool wide) {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryNavy),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final block in section.blocks) _block(context, block, wide),
        ],
      ),
    );
  }

  /// Satu blok naskah. `switch` atas tipe `sealed` — menambah jenis blok baru di
  /// `policy_document.dart` akan menggagalkan kompilasi di sini sampai ia
  /// ditangani, sehingga tidak mungkin ada blok yang diam-diam tidak tampil.
  Widget _block(BuildContext context, PolicyBlock block, bool wide) {
    switch (block) {
      case PolicyText(:final text):
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _rich(text),
        );

      case PolicySubheading(:final text):
        return Padding(
          padding:
              const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
          ),
        );

      case PolicyList(:final items, :final numbered):
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < items.length; i++)
                _listItem(items[i], numbered ? '${i + 1}.' : null),
            ],
          ),
        );

      case PolicyTable(:final headers, :final rows):
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _table(headers, rows, wide),
        );

      case PolicyCallout(:final text, :final warning):
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _calloutBox(text, warning),
        );

      case PolicyRouteLink(:final label, :final route):
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _button(
            label,
            Icons.description_outlined,
            AppColors.primaryNavy,
            // push, bukan go: halaman ini bisa dibuka dari dalam aplikasi, dan
            // tombol kembali harus memulangkan ke tempat asalnya.
            () => context.push(route),
          ),
        );

      case PolicyMailLink(:final label, :final email, :final subject):
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _button(
            label,
            Icons.mail_outline,
            AppColors.errorRed,
            () => _openMail(context, email, subject),
          ),
        );
    }
  }

  Widget _listItem(String text, String? marker) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            marker == null
                ? const Padding(
                    padding: EdgeInsets.only(top: 7, right: 10),
                    child:
                        Icon(Icons.circle, size: 5, color: AppColors.grayStage),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      marker,
                      style: const TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary),
                    ),
                  ),
            Expanded(child: _rich(text)),
          ],
        ),
      );

  /// Tabel yang bisa dibaca di ponsel.
  ///
  /// Di layar lebar dirender sebagai tabel biasa. Di ponsel, tabel tiga kolom
  /// akan memaksa lebar teks jadi beberapa karakter per baris — jadi tiap baris
  /// dipecah jadi kartu dengan label kolomnya di atas tiap nilai. Isinya sama,
  /// hanya tata letaknya yang menyesuaikan.
  Widget _table(List<String> headers, List<List<String>> rows, bool wide) {
    if (!wide) {
      return Column(
        children: [
          for (final row in rows)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.grayBg,
                borderRadius: AppRadius.radiusMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < row.length && i < headers.length; i++)
                    Padding(
                      padding: EdgeInsets.only(
                          bottom: i == row.length - 1 ? 0 : AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headers[i].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: .4,
                                color: AppColors.grayStage),
                          ),
                          const SizedBox(height: 2),
                          _rich(row[i]),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }

    return Table(
      border: TableBorder.all(color: AppColors.border, width: 1),
      defaultVerticalAlignment: TableCellVerticalAlignment.top,
      children: [
        TableRow(
          decoration: const BoxDecoration(color: AppColors.navyBg),
          children: [
            for (final header in headers)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Text(
                  header,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryNavy),
                ),
              ),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              for (final cell in row)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: _rich(cell, size: 12),
                ),
            ],
          ),
      ],
    );
  }

  Widget _calloutBox(String text, bool warning) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: warning ? AppColors.redLight : AppColors.navyBg,
          borderRadius: AppRadius.radiusMd,
          border: Border(
            left: BorderSide(
              color: warning ? AppColors.errorRed : AppColors.primaryNavy,
              width: 3,
            ),
          ),
        ),
        child: _rich(text),
      );

  Widget _button(
          String label, IconData icon, Color color, VoidCallback onPressed) =>
      SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18, color: color),
          label: Text(
            label,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: color),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          ),
        ),
      );

  Future<void> _openMail(
      BuildContext context, String email, String subject) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      // Perangkat tanpa aplikasi surel: alamatnya tetap tertulis sebagai teks di
      // halaman, jadi pengguna masih bisa menyalinnya.
      messenger.showSnackBar(SnackBar(
        content: Text('Tidak dapat membuka aplikasi surel. Kirim ke $email'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.errorRed,
      ));
    }
  }

  /// Merender penegasan `**...**` dari naskah. `\n` dipertahankan (dipakai blok
  /// alamat).
  Widget _rich(String source, {double size = 13}) => Text.rich(
        TextSpan(
          children: [
            for (final segment in parseInline(source))
              TextSpan(
                text: segment.text,
                style: segment.bold
                    ? const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)
                    : null,
              ),
          ],
        ),
        style: TextStyle(
            fontSize: size, height: 1.55, color: AppColors.textSecondary),
      );

  Widget _card(Widget child) => Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radius2Xl,
          border: Border.all(color: AppColors.border),
          boxShadow: const [AppShadows.level2],
        ),
        child: child,
      );
}

/// Spanduk peringatan di atas dokumen — dipakai untuk status draf.
///
/// Draf yang tampil persis seperti dokumen final adalah masalah yang lebih besar
/// daripada draf yang terlihat sebagai draf: tidak ada yang sadar naskahnya belum
/// ditinjau.
class _Banner extends StatelessWidget {
  final String text;
  const _Banner(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.orangeLight,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.secondaryOrange),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 18, color: AppColors.secondaryOrange),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, height: 1.5, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
