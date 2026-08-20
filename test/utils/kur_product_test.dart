import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/utils/kur_product.dart';

/// CR-05 — form pipeline melonggarkan TSI & rate premi khusus KUR, jadi deteksi
/// KUR-nya harus persis sama dengan `TargetCategoryClassifier` di backend. Salah
/// sedikit berarti produk lain ikut boleh dikosongkan (atau KUR tetap terkunci).
void main() {
  test('toc KUR dikenali', () {
    expect(isKurProduct(tocCode: 'KUR'), isTrue);
  });

  test('cob Kredit Usaha Rakyat dikenali', () {
    expect(isKurProduct(cobName: 'Kredit Usaha Rakyat'), isTrue);
  });

  test('normalisasi trim + huruf besar, sama seperti norm() backend', () {
    expect(isKurProduct(tocCode: '  kur '), isTrue);
    expect(isKurProduct(cobName: ' kredit usaha rakyat '), isTrue);
  });

  test('produk lain tidak dikenali sebagai KUR', () {
    expect(isKurProduct(tocCode: 'AKK', cobName: 'Asuransi Kredit Kecil'), isFalse);
    expect(isKurProduct(tocCode: 'SB', cobName: 'Surety Bond'), isFalse);
    expect(isKurProduct(cobName: 'KMK DF'), isFalse);
  });

  test('null / kosong bukan KUR', () {
    expect(isKurProduct(), isFalse);
    expect(isKurProduct(tocCode: '', cobName: ''), isFalse);
  });

  test('kemiripan nama tidak ikut tertarik', () {
    // "Kredit Usaha Rakyat Mikro" bukan nilai COB yang dipakai backend; pencocokan
    // backend equals(), bukan contains(), jadi cermin ini pun tidak boleh longgar.
    expect(isKurProduct(cobName: 'Kredit Usaha Rakyat Mikro'), isFalse);
    expect(isKurProduct(tocCode: 'KURS'), isFalse);
  });
}
