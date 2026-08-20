import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/utils/format.dart';

/// Kartu ringkasan dashboard memakai [AppFormat.currencyShort] di 37 tempat, dan
/// yang dibaca di sana adalah angka capaian. Uji ini mengunci bentuknya supaya
/// nominal besar tidak diam-diam kembali tampil sebagai deretan digit panjang.
void main() {
  group('AppFormat.currencyShort', () {
    test('miliar: dua desimal, bagian bulat berpemisah ribuan', () {
      expect(AppFormat.currencyShort(15840541145), 'Rp 15,84 M');
      // Bagian bulat empat digit: dulu tampil "1234,56 M" tanpa jeda.
      expect(AppFormat.currencyShort(1234560000000), 'Rp 1.234,56 M');
    });

    test('juta: satu desimal', () {
      expect(AppFormat.currencyShort(26700000), 'Rp 26,7 Jt');
      expect(AppFormat.currencyShort(1000000), 'Rp 1 Jt');
    });

    test('ribuan dipendekkan, bukan ditulis utuh', () {
      // Inti laporannya: "Rp 850.000" di kartu ringkasan terbaca seperti desimal.
      expect(AppFormat.currencyShort(850000), 'Rp 850 Rb');
      expect(AppFormat.currencyShort(1000), 'Rp 1 Rb');
    });

    test('di bawah seribu tetap utuh', () {
      expect(AppFormat.currencyShort(999), 'Rp 999');
      expect(AppFormat.currencyShort(0), 'Rp 0');
    });

    test('negatif ikut dipendekkan', () {
      // Realisasi resmi boleh minus (koreksi/pembatalan polis). Perbandingan
      // ">=" dulu gagal untuk bilangan minus sehingga nilainya tampil utuh.
      expect(AppFormat.currencyShort(-15840541145), 'Rp -15,84 M');
      expect(AppFormat.currencyShort(-850000), 'Rp -850 Rb');
    });

    test('nol desimal tidak menyisakan koma menggantung', () {
      expect(AppFormat.currencyShort(2000000000), 'Rp 2 M');
      expect(AppFormat.currencyShort(5000000), 'Rp 5 Jt');
    });
  });
}
