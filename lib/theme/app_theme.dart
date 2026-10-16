import 'dart:ui';
import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryNavy = Color(0xFF0D2C54);
  static const Color primaryNavyDark = Color(0xFF081E3A);
  static const Color primaryNavyLight = Color(0xFF1A4A7A);
  static const Color navyBg = Color(0xFFE8EEF5);
  static const Color secondaryOrange = Color(0xFFF2843A);
  static const Color orangeLight = Color(0xFFFFF3EC);
  static const Color orangeBg = Color(0xFFFEE9D4);
  static const Color bgScreen = Color(0xFFF4F6F9);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color successGreen = Color(0xFF1E8E5A);
  static const Color greenLight = Color(0xFFE8F5EE);
  static const Color errorRed = Color(0xFFD64545);
  static const Color redLight = Color(0xFFFEF0F0);
  static const Color grayStage = Color(0xFF8C97A6);
  static const Color grayBg = Color(0xFFEEF1F4);
  static const Color textPrimary = Color(0xFF1C2833);
  static const Color textSecondary = Color(0xFF717D7E);
  static const Color border = Color(0xFFE2E8F0);
  static const Color purpleAccent = Color(0xFF7C3AED);
  static const Color navyMbis = Color(0xFF0E2B53);
  static const Color textDark = Color(0xFF15223B);
  static const Color textLabel = Color(0xFF3A4557);
  static const Color textMuted = Color(0xFF5A6475);
  static const Color hintText = Color(0xFF8A93A3);
  static const Color textDisabled = Color(0xFF9AA3B2);
  static const Color borderInactive = Color(0xFFB7C1D1);
  static const Color borderDefault = Color(0xFFD5DCE7);
  static const Color borderDivider = Color(0xFFE3E7EF);
  static const Color blueLightBg = Color(0xFFE9EEF6);
  static const Color bgDisabled = Color(0xFFEEF1F6);
  static const Color bgInfoBanner = Color(0xFFEEF4FB);
  static const Color bgSelectedCard = Color(0xFFF3F6FB);
  static const Color bgLightGray = Color(0xFFF4F6FA);
  static const Color bgDisabledCard = Color(0xFFF7F8FA);
  static const Color blueInputText = Color(0xFF0070C0);
  static const Color orangeMbis = Color(0xFFE8732A);
  static const Color orangeDark = Color(0xFFC25A17);
  static const Color alertBorder = Color(0xFFF3C9A8);
  static const Color alertBg = Color(0xFFFFF6EF);
  static const Color alertTitle = Color(0xFF9A4712);
  static const Color alertText = Color(0xFF7A3A0E);
  static const Color greenTotal = Color(0xFF1D7A4E);
  static const Color redRequired = Color(0xFFC8322F);
  static const Color textPlaceholder = Color(0xFF9FB0C8);
  static const Color iconDropdown = Color(0xFF6B7485);
  static const Color borderDisabled = Color(0xFFDCE2EC);
  static const Color warningNik = Color(0xFFA0520F);
  static const Color errorBannerBg = Color(0xFFFDECEC);
  static const Color errorBannerBorder = Color(0xFFF2B8B5);
  static const Color errorBannerTitle = Color(0xFF9E2522);
  static const Color errorBannerText = Color(0xFF7A1F1C);
  static const Color borderDashed = Color(0xFFCCD4E1);
  static const Color bgScaffold = Color(0xFFF2F4F8);
  static const Color badgeOffStdBg = Color(0xFFFFF1E6);
  static const Color bgUploadSuccess = Color(0xFFF1FAF4);
  static const Color borderUploadSuccess = Color(0xFFCFE6D8);
  static const Color borderUploadDashed = Color(0xFF9AA5B5);
  static const Color bgUploadBox = Color(0xFFFAFBFD);
  static const Color iconCheckMuted = Color(0xFF8A94A6);
  static const Color bgPreviewDoc = Color(0xFFE6EAF1);
  static const Color shadowDoc1 = Color(0x1F0E2B53);
  static const Color shadowDoc2 = Color(0x0F0E2B53);
  static const Color watermarkDraft = Color(0x1AC8322F);
  static const Color borderTable = Color(0xFFC9D1DD);
  static const Color blueFooterAskrindo = Color(0xFF2E4A7D);
  static const Color ribbonBlue = Color(0xFFDCE6F2);
  static const Color badgeP2Bg = Color(0xFFFDEEDF);
  static const Color badgeP1Bg = Color(0xFFE3F4EA);
  static const Color badgeIdleDivider = Color(0xFFF3E4D8);
  static const Color avatarGradientBlue1 = Color(0xFF6B8BB8);
  static const Color avatarGradientOrange1 = Color(0xFFE8A66E);
  static const Color avatarGradientGreen1 = Color(0xFF7FB89A);
  static const Color avatarGradientPurple1 = Color(0xFFA99BD6);
  static const Color avatarGradientPurple2 = Color(0xFF5B4B99);
  static const Color transparent = Color(0x00000000);
  static const Color bannerCameraIcon = Color(0xD9FFFFFF);
  static const Color bannerOverlayDark = Color(0xA6000000);
  static const Color textWhite70 = Color(0xB3FFFFFF);
  static const Color whiteAlpha12 = Color(0x1FFFFFFF);
  static const Color whiteAlpha14 = Color(0x24FFFFFF);
  static const Color whiteAlpha25 = Color(0x40FFFFFF);
  static const Color whiteAlpha72 = Color(0xB8FFFFFF);
  static const Color whiteAlpha75 = Color(0xBFFFFFFF);
  static const Color whiteAlpha78 = Color(0xC7FFFFFF);
  static const Color badgeDraftText = Color(0xFFF6B489);
  static const Color badgeReadyText = Color(0xFF8FE3B5);
  static const Color greenLightBanner = Color(0xFFE6F3EC);
  static const Color greenDarkText = Color(0xFF1D5E3E);
  static const Color bgSelectPipe = Color(0xFFF0F5FA);
}

class AppRadius {
  static const double xs = 6.0;
  static const double sm = 8.0;
  static const double md = 10.0;
  static const double lg = 12.0;
  static const double xl = 14.0;
  static const double xxl = 16.0;
  static const double xxxl = 20.0;
  static const double phone = 44.0;
  
  static BorderRadius get radiusXs => BorderRadius.circular(xs);
  static BorderRadius get radiusSm => BorderRadius.circular(sm);
  static BorderRadius get radiusMd => BorderRadius.circular(md);
  static BorderRadius get radiusLg => BorderRadius.circular(lg);
  static BorderRadius get radiusXl => BorderRadius.circular(xl);
  static BorderRadius get radius2Xl => BorderRadius.circular(xxl);
  static BorderRadius get radius3Xl => BorderRadius.circular(xxxl);
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(9999));
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class AppShadows {
  static const BoxShadow level1 = BoxShadow(
    color: Color(0x140D2C54), // rgba(13,44,84,0.08)
    offset: Offset(0, 2),
    blurRadius: 8,
  );

  static const BoxShadow level2 = BoxShadow(
    color: Color(0x140D2C54),
    offset: Offset(0, 2),
    blurRadius: 10,
  );

  static const BoxShadow level3 = BoxShadow(
    color: Color(0x660D2C54), // rgba(13,44,84,0.40)
    offset: Offset(0, 4),
    blurRadius: 16,
  );

  static const BoxShadow level4 = BoxShadow(
    color: Color(0x260D2C54), // rgba(13,44,84,0.15)
    offset: Offset(0, 8),
    blurRadius: 32,
  );
}

/// Gaya isian form yang seragam. Default Material mengambil `bodyLarge` (18) untuk
/// teks TextField dan `titleMedium` (22) untuk teks DropdownButtonFormField — jauh
/// lebih besar dari ideal form. Pakai [fieldText] sebagai `style:` pada TextField /
/// TextFormField / DropdownButtonFormField agar semua form konsisten ~14sp.
class AppInput {
  static const TextStyle fieldText =
      TextStyle(fontSize: 14, color: AppColors.textPrimary);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgScreen,
      primaryColor: AppColors.primaryNavy,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryNavy,
        secondary: AppColors.secondaryOrange,
        surface: AppColors.surfaceWhite,
        error: AppColors.errorRed,
      ),
      fontFamily: 'PlusJakartaSans',
      // Global ChoiceChip/FilterChip styling so every filter chip is consistent:
      // navy when selected, a white checkmark (never a dark one), and no stray
      // orange tint/ripple flash when toggling between chips.
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceWhite,
        selectedColor: AppColors.primaryNavy,
        secondarySelectedColor: AppColors.primaryNavy,
        disabledColor: AppColors.grayBg,
        checkmarkColor: Colors.white,
        showCheckmark: true,
        // Label putih saat terpilih (di atas latar navy). FilterChip tidak otomatis
        // memakai secondaryLabelStyle; warnanya harus WidgetStateColor pada
        // labelStyle.color (jalur yang benar-benar di-resolve chip), bukan
        // WidgetStateTextStyle — kalau tidak, chip jatuh ke warna default gelap.
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: WidgetStateColor.resolveWith((states) =>
              states.contains(WidgetState.selected)
                  ? Colors.white
                  : AppColors.textSecondary),
        ),
        secondaryLabelStyle: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        elevation: 0,
        pressElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      // Konsistensi form di seluruh aplikasi: label/hint/helper/error dibuat
      // seragam ~14/12sp. Tanpa ini, teks dekorasi mewarisi skala teks besar
      // (bodyLarge 18) sehingga hint search & label form tampak jauh lebih besar
      // dari isian idealnya. Hanya menyetel UKURAN FONT dekorasi (bukan padding/
      // border) agar tak menggeser layout form yang sudah ada.
      inputDecorationTheme: const InputDecorationTheme(
        labelStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        floatingLabelStyle:
            TextStyle(fontSize: 13, color: AppColors.textSecondary),
        hintStyle: TextStyle(fontSize: 14, color: AppColors.grayStage),
        helperStyle: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        errorStyle: TextStyle(fontSize: 12, color: AppColors.errorRed),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 40/34),
        titleLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 32/26),
        titleMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w500, color: AppColors.textPrimary, height: 28/22),
        bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 24/18),
        bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppColors.textPrimary, height: 22/16),
        bodySmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary, height: 20/15),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 18/14),
      ),
    );
  }
}

class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedRectPainter({
    this.color = Colors.black,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(10),
    ));

    final Path dashPath = Path();
    double distance = 0.0;
    for (final PathMetric metric in path.computeMetrics()) {
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + gap),
          Offset.zero,
        );
        distance += gap * 2;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(DashedRectPainter oldDelegate) =>
      color != oldDelegate.color ||
      strokeWidth != oldDelegate.strokeWidth ||
      gap != oldDelegate.gap;
}
