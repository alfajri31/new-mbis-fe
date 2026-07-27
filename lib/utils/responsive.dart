import 'package:flutter/widgets.dart';

/// Single source of truth for M-BIS responsive breakpoints, aligned to
/// design.md §2.3 (Mobile 4-col / Tablet 8-col / Desktop 12-col).
///
/// Layout is driven by available WIDTH (via [MediaQuery]), NOT `kIsWeb`, so a
/// narrow browser window correctly gets the mobile layout and a wide tablet
/// gets the desktop chrome. Reserve `kIsWeb` for platform-capability branches
/// (camera/GPS), never for layout.
class Responsive {
  Responsive._();

  /// Below this width we use the mobile layout (single column, bottom nav).
  static const double mobileMaxWidth = 768;

  /// At/above this width we use the desktop layout (persistent side nav,
  /// multi-column). The band in between is treated as tablet.
  static const double desktopMinWidth = 1200;

  /// Max width for the main content column on wide layouts so text/cards don't
  /// run edge-to-edge on large monitors. This is the BASE cap (standard desktop);
  /// use [contentMaxWidthFor] to also grow it on 1600px+/4K screens.
  static const double contentMaxWidth = 1200;

  /// Ambang layar besar / 4K. Di atas ambang ini cap konten dinaikkan agar konten
  /// tidak menyusut jadi "pulau kecil" di tengah layar yang lebar.
  static const double largeDesktopMinWidth = 1600;
  static const double xlDesktopMinWidth = 2400;

  /// Cap lebar konten yang adaptif terhadap lebar layar:
  /// standar desktop/tablet → 1200; layar besar (≥1600) → 1440; ultra-wide/4K
  /// (≥2400) → 1800. Tetap dibatasi supaya teks/kartu tidak melebar edge-to-edge.
  static double contentMaxWidthFor(BuildContext context) {
    final w = widthOf(context);
    if (w >= xlDesktopMinWidth) return 1800;
    if (w >= largeDesktopMinWidth) return 1440;
    return contentMaxWidth;
  }

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isMobile(BuildContext context) =>
      widthOf(context) < mobileMaxWidth;

  static bool isTablet(BuildContext context) {
    final w = widthOf(context);
    return w >= mobileMaxWidth && w < desktopMinWidth;
  }

  static bool isDesktop(BuildContext context) =>
      widthOf(context) >= desktopMinWidth;

  /// True for tablet-and-wider — i.e. use the side-nav shell + multi-column
  /// reflow instead of the mobile bottom-nav, single-column layout.
  static bool isWide(BuildContext context) =>
      widthOf(context) >= mobileMaxWidth;

  /// Picks a value per breakpoint. `tablet` falls back to `desktop` then
  /// `mobile`; `desktop` falls back to `tablet` then `mobile`.
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (isTablet(context)) return tablet ?? desktop ?? mobile;
    return mobile;
  }

  /// Common grid column count: mobile 2 → tablet 3 → desktop 4. Pass overrides
  /// to [value] directly when a screen needs a different ramp.
  static int gridColumns(BuildContext context) =>
      value(context, mobile: 2, tablet: 3, desktop: 4);
}
