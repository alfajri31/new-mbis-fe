import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/src/product_knowledge/product_knowledge_models.dart';
import 'package:mbis/presentation/screens/product_detail_screen.dart';

void main() {
  const cat = PkCategory(
      id: 'suretyship', name: 'Penjaminan / Suretyship', icon: 'shield-check', color: Color(0xFF0D2C54));

  PkProduct make({required bool active, Map<String, dynamic>? sections, Map<String, String>? qf}) => PkProduct(
        id: '1IA',
        slug: 'surety-bond',
        name: 'Surety Bond',
        categoryId: 'suretyship',
        active: active,
        quickFacts: qf ?? const {},
        rawSections: sections ?? const {},
        skemaUrl: null,
      );

  testWidgets('Detail produk aktif (lengkap) merender tanpa exception', (tester) async {
    final p = make(active: true, qf: {
      'premi': 'rate × nilai jaminan',
      'masaPertanggungan': 'sesuai kontrak',
      'nilaiPertanggungan': '% nilai kontrak',
    }, sections: {
      'deskripsi': 'Jaminan kontraktor ke pemberi kerja.',
      'manfaat': ['Melindungi pemberi kerja.'],
      'pengecualian': ['Penipuan', 'Perselisihan'],
      'persyaratan': ['Form A', 'Copy NPWP'],
      'tataCara': ['Ajukan', 'Analisa', 'Terbit polis'],
    });
    await tester.pumpWidget(MaterialApp(home: ProductDetailScreen(product: p, category: cat)));
    await tester.pumpAndSettle();
    expect(find.text('Surety Bond'), findsWidgets);
    // Sumber tunggal: semua section yang ada di JSON tampil.
    expect(find.text('Deskripsi'), findsOneWidget);
    expect(find.text('Pengecualian'), findsOneWidget);
  });

  testWidgets('Detail produk maintenance (tanpa section) merender tanpa exception', (tester) async {
    final p = make(active: false);
    await tester.pumpWidget(MaterialApp(home: ProductDetailScreen(product: p, category: cat)));
    await tester.pumpAndSettle();
    expect(find.text('Surety Bond'), findsWidgets);
    expect(find.textContaining('Segera Hadir'), findsWidgets);
  });
}
