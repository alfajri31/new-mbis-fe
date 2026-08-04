import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/utils/input_formatters.dart';

/// Mengunci perbaikan temuan lapangan: di ponsel, Rate Premi tidak bisa diisi
/// desimal. Papan ketik angka Android memunculkan tombol pemisah sesuai locale
/// perangkat — koma untuk Indonesia — sementara filter lama hanya mengizinkan
/// `[0-9.]`, jadi tombol itu terlihat ada tapi setiap ditekan hasilnya dibuang.
/// Pemakai melaporkannya sebagai "ada koma tapi tidak bisa dipencet".
void main() {
  const f = DecimalInputFormatter();

  /// Mensimulasikan satu ketikan: [before] + [typed] pada posisi akhir.
  TextEditingValue type(String before, String typed) {
    final text = before + typed;
    return f.formatEditUpdate(
      TextEditingValue(
        text: before,
        selection: TextSelection.collapsed(offset: before.length),
      ),
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      ),
    );
  }

  group('DecimalInputFormatter', () {
    test('koma diterima dan disimpan sebagai titik (inti bug)', () {
      final out = type('2', ',');
      expect(out.text, '2.');
      expect(type('2.', '5').text, '2.5');
    });

    test('titik tetap bekerja seperti sebelumnya', () {
      expect(type('2', '.').text, '2.');
      expect(type('0.0', '5').text, '0.05');
    });

    test('pemisah kedua ditolak — "1.2.3" mustahil', () {
      expect(type('1.2', '.').text, '1.2');
      expect(type('1.2', ',').text, '1.2');
    });

    test('pemisah di awal dilengkapi nol supaya tetap angka sah', () {
      final out = type('', ',');
      expect(out.text, '0.');
      // Yang penting: hasilnya bisa di-parse, bukan null yang divonis
      // "angka tidak valid" padahal pemakai sudah mengetik dengan benar.
      expect(double.tryParse(type('0.', '5').text), 0.5);
    });

    test('huruf dan simbol dibuang', () {
      expect(type('2', 'a').text, '2');
      expect(type('2.5', '%').text, '2.5');
    });

    test('hasilnya selalu bisa di-parse double (rate 2,5% dari ponsel)', () {
      var text = '';
      for (final ch in ['2', ',', '5']) {
        text = type(text, ch).text;
      }
      expect(text, '2.5');
      expect(double.tryParse(text), 2.5);
    });

    test('kursor mengikuti sisipan di tengah, tidak melompat ke ujung', () {
      // "25" dengan kursor di tengah, lalu mengetik koma → "2.5", kursor di 2.
      final out = f.formatEditUpdate(
        const TextEditingValue(
          text: '25',
          selection: TextSelection.collapsed(offset: 1),
        ),
        const TextEditingValue(
          text: '2,5',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(out.text, '2.5');
      expect(out.selection.baseOffset, 2);
    });

    test('karakter yang dibuang tidak menggeser kursor', () {
      final out = f.formatEditUpdate(
        const TextEditingValue(
          text: '25',
          selection: TextSelection.collapsed(offset: 1),
        ),
        const TextEditingValue(
          text: '2x5',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(out.text, '25');
      expect(out.selection.baseOffset, 1);
    });

    test('decimalRange membatasi angka di belakang pemisah', () {
      const limited = DecimalInputFormatter(decimalRange: 2);
      final out = limited.formatEditUpdate(
        const TextEditingValue(text: '2.55'),
        const TextEditingValue(
          text: '2.555',
          selection: TextSelection.collapsed(offset: 5),
        ),
      );
      expect(out.text, '2.55');
    });

    test('isian kosong tetap kosong', () {
      expect(type('', '').text, '');
    });
  });
}
