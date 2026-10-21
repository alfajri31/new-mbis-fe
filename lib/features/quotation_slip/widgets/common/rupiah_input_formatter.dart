import 'package:flutter/services.dart';

/// Formatter angka ribuan rupiah dengan pemisah titik (.) untuk input UI.
class RupiahInputFormatter extends TextInputFormatter {
  const RupiahInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final cleanDigits = digits.replaceFirst(RegExp(r'^0+(?!$)'), '');
    final formatted = formatDigits(cleanDigits);

    final rawCursor = newValue.selection.baseOffset;
    final digitsBeforeCursor = newValue.text
        .substring(0, rawCursor.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    var newCursor = 0;
    var count = 0;
    for (var i = 0; i < formatted.length; i++) {
      if (formatted[i] != '.') {
        count++;
      }
      if (count == digitsBeforeCursor) {
        newCursor = i + 1;
        break;
      }
    }
    if (digitsBeforeCursor == 0) newCursor = 0;
    if (count < digitsBeforeCursor) newCursor = formatted.length;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: newCursor.clamp(0, formatted.length),
      ),
    );
  }

  /// Format deretan angka menjadi berformat ribuan titik (contoh: 1000000 -> 1.000.000).
  static String formatDigits(String digits) {
    if (digits.isEmpty) return '';
    final s = digits.replaceFirst(RegExp(r'^0+(?!$)'), '');
    final str = s.isEmpty ? '0' : s;
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buf.write('.');
      }
      buf.write(str[i]);
    }
    return buf.toString();
  }
}
