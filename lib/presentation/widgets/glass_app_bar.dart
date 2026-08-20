import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';

/// Frosted-glass app bar: only the title stays pinned while the content
/// scrolls underneath with a translucent blur (iOS-style).
///
/// Use together with `Scaffold(extendBodyBehindAppBar: true)` so the body is
/// painted behind the bar — that's what the [BackdropFilter] blurs. Pad the
/// scrollable content by `MediaQuery.padding.top + kToolbarHeight` so the first
/// item isn't hidden behind the bar.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;

  /// Optional leading widget (e.g. a back button when the screen is pushed
  /// rather than used as a root tab). When null, no leading is shown.
  final Widget? leading;

  /// Optional bar pinned beneath the title (e.g. a [TabBar]); its height is
  /// added to [preferredSize].
  final PreferredSizeWidget? bottom;

  /// Show a back button as the leading widget. Set this on screens that are
  /// PUSHED onto the stack (utility/admin sub-screens); leave false for the
  /// tab screens that live inside the bottom navigation.
  final bool showBack;

  /// Lebar maksimum kolom konten body layar ini — dipakai untuk menyejajarkan judul
  /// dengan tepi kiri isinya.
  ///
  /// Biarkan null bila body memakai cap responsif [Responsive.contentMaxWidthFor]
  /// (Dashboard, Customer, BUMN, Broker, …). Isi eksplisit bila body memakai cap lain:
  /// `MaxWidthBody.defaultMaxWidth` untuk konsol admin, angka sendiri untuk form
  /// ber-cap khusus, atau `double.infinity` bila body-nya full-bleed.
  ///
  /// Nilai yang salah TIDAK terlihat di ponsel — hanya di layar lebar, sebagai judul
  /// yang melayang jauh dari isinya.
  final double? contentMaxWidth;

  const GlassAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.bottom,
    this.showBack = false,
    this.contentMaxWidth,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    // Judul + actions disejajarkan dengan kolom konten body. Latar glass tetap
    // full-bleed lewat flexibleSpace.
    //
    // Perhitungannya memakai lebar LAYAR, bukan lebar slot title milik AppBar: slot itu
    // dimulai SETELAH leading, jadi menengahkan blok di dalamnya menggeser judul ke kanan
    // sebesar separuh lebar tombol back (terukur 28 px). Dan cap-nya kini datang dari
    // pemanggil, karena versi lama selalu memakai cap responsif 1200/1440/1800 padahal
    // konsol admin memakai MaxWidthBody 800 dan sebagian layar full-bleed — di layar
    // 1920 judulnya meleset 240–292 px dari isinya.
    final double screenWidth = Responsive.widthOf(context);
    final double cap = contentMaxWidth ??
        (Responsive.isWide(context)
            ? Responsive.contentMaxWidthFor(context)
            : screenWidth);
    final double contentWidth = math.min(cap, screenWidth);
    // Tepi kiri teks pertama di body: sisa ruang di luar cap dibagi dua + padding body.
    final double contentInset = (screenWidth - contentWidth) / 2 + AppSpacing.lg;
    final bool hasLeading = showBack || leading != null;
    // Judul tidak boleh menempel ke tombol back. Jarak minimal AppSpacing.lg ini pula yang
    // menjaga tampilan ponsel tetap sama persis dengan AppBar bawaan Material.
    final double titleInset = hasLeading
        ? math.max(contentInset - kToolbarHeight, AppSpacing.lg)
        : contentInset;
    final Widget titleRow = Padding(
      padding: EdgeInsets.only(left: titleInset, right: contentInset),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      // showBack wins (auto back button); otherwise fall back to an explicit
      // leading widget if one was provided.
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => Navigator.of(context).pop(),
            )
          : leading,
      centerTitle: false,
      titleSpacing: 0,
      // Title slot memuat title + actions sekaligus (actions dikosongkan di bawah)
      // supaya keduanya memakai perhitungan inset yang sama.
      title: titleRow,
      actions: const [],
      bottom: bottom,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite.withValues(alpha: 0.72),
              border: const Border(
                bottom: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
