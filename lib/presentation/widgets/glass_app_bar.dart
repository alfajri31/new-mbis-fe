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

  const GlassAppBar({
    super.key,
    required this.title,
    this.actions = const [],
    this.leading,
    this.bottom,
    this.showBack = false,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    // Judul + actions di-cap + center ke lebar konten agar SEJAJAR dengan body
    // (yang juga di-cap). Latar glass tetap full-bleed lewat flexibleSpace.
    final bool wide = Responsive.isWide(context);
    final Widget titleRow = Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
      // supaya keduanya ikut satu ConstrainedBox yang ter-center.
      title: SizedBox(
        width: double.infinity,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: wide ? Responsive.contentMaxWidthFor(context) : double.infinity,
            ),
            child: titleRow,
          ),
        ),
      ),
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
