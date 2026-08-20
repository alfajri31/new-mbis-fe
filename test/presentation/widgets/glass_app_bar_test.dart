import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/presentation/widgets/glass_app_bar.dart';
import 'package:mbis/presentation/widgets/max_width_body.dart';
import 'package:mbis/theme/app_theme.dart';
import 'package:mbis/utils/responsive.dart';

/// Judul GlassAppBar harus sejajar dengan tepi kiri isi layarnya.
///
/// Dulu judul di-cap ke [Responsive.contentMaxWidthFor] (1200/1440/1800) lalu
/// di-center DI DALAM slot title milik AppBar. Dua kesalahan sekaligus:
/// slot itu dimulai setelah tombol back, jadi judul tergeser ke kanan separuh lebar
/// tombol (28 px); dan cap responsif itu tidak berlaku untuk konsol admin yang
/// body-nya [MaxWidthBody] 800 px, maupun layar yang full-bleed. Terukur di layar
/// 1920: judul "Tools" meleset 268 px dari isinya. Dilaporkan 2026-08-20.
void main() {
  const double screen = 1920;

  Future<double> titleX(
    WidgetTester tester, {
    required Widget body,
    double? contentMaxWidth,
    bool showBack = false,
  }) async {
    tester.view.physicalSize = const Size(screen, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: GlassAppBar(
          title: 'Judul',
          showBack: showBack,
          contentMaxWidth: contentMaxWidth,
        ),
        body: body,
      ),
    ));
    await tester.pumpAndSettle();
    return tester.getTopLeft(find.text('Judul')).dx;
  }

  // Align memaksa isi memenuhi lebar yang tersedia, seperti ListView di layar sungguhan;
  // tanpa itu Text menyusut ke lebar intrinsiknya dan MaxWidthBody menengahkannya.
  Widget padded(Widget child) => Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 100, AppSpacing.lg, 0),
        child: Align(alignment: Alignment.topLeft, child: child),
      );

  testWidgets('konsol admin (MaxWidthBody 800): judul sejajar dengan isi', (tester) async {
    final x = await titleX(
      tester,
      contentMaxWidth: MaxWidthBody.defaultMaxWidth,
      showBack: true,
      body: MaxWidthBody(child: padded(const Text('isi'))),
    );
    final isi = tester.getTopLeft(find.text('isi')).dx;
    expect(x, isi);
    // (1920-800)/2 + 16 = 576 \u2014 jauh dari 284 px yang dihasilkan versi lama.
    expect(x, 576.0);
  });

  testWidgets('layar full-bleed: judul menempel kiri, tepat setelah tombol back',
      (tester) async {
    final x = await titleX(
      tester,
      contentMaxWidth: double.infinity,
      showBack: true,
      body: padded(const Text('isi')),
    );
    // Tidak bisa persis di 16 karena tombol back menempati 0..56; kToolbarHeight + lg.
    expect(x, kToolbarHeight + AppSpacing.lg);
    expect(x, lessThan(100));
  });

  testWidgets('layar full-bleed tanpa tombol back: judul persis di tepi isi',
      (tester) async {
    final x = await titleX(
      tester,
      contentMaxWidth: double.infinity,
      body: padded(const Text('isi')),
    );
    expect(x, tester.getTopLeft(find.text('isi')).dx);
    expect(x, AppSpacing.lg);
  });

  testWidgets('cap responsif (default): tombol back tidak lagi menggeser judul',
      (tester) async {
    final tanpaBack = await titleX(tester, body: const SizedBox.shrink());
    final denganBack =
        await titleX(tester, showBack: true, body: const SizedBox.shrink());
    expect(denganBack, tanpaBack,
        reason: 'dulu selisih 28 px = separuh lebar tombol back');
    expect(tanpaBack, (screen - 1440) / 2 + AppSpacing.lg);
  });

  testWidgets('ponsel: tetap seperti AppBar bawaan (tidak menempel ke tombol back)',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        appBar: GlassAppBar(
          title: 'Judul',
          showBack: true,
          contentMaxWidth: MaxWidthBody.defaultMaxWidth,
        ),
        body: SizedBox.shrink(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Judul')).dx, kToolbarHeight + AppSpacing.lg);
  });
}
