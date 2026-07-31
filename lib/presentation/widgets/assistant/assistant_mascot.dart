import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Maskot Dubi: `Image.asset` dengan fallback ikon bila aset gagal dimuat.
/// [dark] memilih warna ikon fallback — putih (default) untuk di atas app bar
/// navy, navy untuk di atas surface terang. Murni presentational — diekstrak
/// dari `assistant_screen.dart` (behavior-preserving).
class AssistantMascot extends StatelessWidget {
  const AssistantMascot({super.key, required this.size, this.dark = false});

  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/maskot.png',
    width: size,
    height: size,
    // maskot.png berukuran 1309x1202 (±6 MB saat di-decode ke bitmap ARGB),
    // padahal dirender maksimal 64 px. Tanpa cacheWidth/cacheHeight, Flutter
    // tetap men-decode pada resolusi penuh walau width/height sudah diberi —
    // width/height hanya mengatur ukuran GAMBAR, bukan ukuran DECODE.
    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
    cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
    errorBuilder: (_, _, _) => Icon(
      Icons.smart_toy_outlined,
      size: size,
      color: dark ? AppColors.primaryNavy : Colors.white,
    ),
  );
}
