import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/utils/pipeline_nilai_wajib.dart';

/// Regresi CR-05, ditemukan saat SIT 20 Agustus 2026 (TC-16).
///
/// Formulir sudah menjanjikan "Untuk KUR, TSI dan rate premi boleh diisi 0 dulu",
/// tetapi menyimpannya tetap ditolak "2 isian wajib belum lengkap" karena
/// pemeriksaan sebelum simpan masih memakai `<= 0` tanpa pengecualian KUR.
void main() {
  group('tsiBelumLengkap', () {
    test('KUR: 0 diterima, inti CR-05', () {
      expect(tsiBelumLengkap(teks: '0', isKur: true), isFalse);
    });

    test('KUR: kosong tetap ditolak supaya 0 jadi pilihan sadar', () {
      expect(tsiBelumLengkap(teks: '', isKur: true), isTrue);
      expect(tsiBelumLengkap(teks: '   ', isKur: true), isTrue);
    });

    test('non KUR: 0 tetap ditolak', () {
      expect(tsiBelumLengkap(teks: '0', isKur: false), isTrue);
    });

    test('pemisah ribuan tidak mengganggu pembacaan', () {
      expect(tsiBelumLengkap(teks: '1.000.000.000', isKur: false), isFalse);
      expect(tsiBelumLengkap(teks: 'Rp 0', isKur: true), isFalse);
    });

    test('nol berganda tetap terbaca nol, bukan kosong', () {
      expect(tsiBelumLengkap(teks: '00', isKur: true), isFalse);
      expect(tsiBelumLengkap(teks: '00', isKur: false), isTrue);
    });
  });

  group('rateBelumLengkap', () {
    test('KUR: 0 diterima', () {
      expect(rateBelumLengkap(teks: '0', isKur: true), isFalse);
    });

    test('KUR: kosong tetap ditolak', () {
      expect(rateBelumLengkap(teks: '', isKur: true), isTrue);
    });

    test('non KUR: 0 ditolak, nilai wajar diterima', () {
      expect(rateBelumLengkap(teks: '0', isKur: false), isTrue);
      expect(rateBelumLengkap(teks: '0.5', isKur: false), isFalse);
      expect(rateBelumLengkap(teks: '2.1', isKur: false), isFalse);
    });

    test('bukan angka dianggap belum lengkap', () {
      expect(rateBelumLengkap(teks: 'abc', isKur: true), isTrue);
    });

    test('rate di atas 100 bukan urusan fungsi ini', () {
      // Pesannya berbeda ("maksimal 100%"), jadi ditangani pemanggil.
      expect(rateBelumLengkap(teks: '150', isKur: false), isFalse);
    });
  });
}
