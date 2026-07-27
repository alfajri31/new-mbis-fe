import 'package:flutter/services.dart';
import 'format.dart';

/// Live thousands-separator for numeric money inputs (e.g. "500000000" -> "500.000.000").
/// Strip with `text.replaceAll(RegExp(r'[^0-9]'), '')` before parsing.
class ThousandsInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final formatted = AppFormat.thousands(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Live NPWP mask: "092345678012345" -> "09.234.567.8-012.345" (15 digits,
/// pola XX.XXX.XXX.X-XXX.XXX). Menerima input apa pun, hanya angka yang dipakai,
/// dipotong di 15 digit. Ambil angka murni dengan
/// `text.replaceAll(RegExp(r'[^0-9]'), '')` sebelum dikirim/divalidasi.
class NpwpInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final capped = digits.length > 15 ? digits.substring(0, 15) : digits;
    final buf = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i == 2 || i == 5 || i == 8 || i == 12) {
        buf.write('.');
      } else if (i == 9) {
        buf.write('-');
      }
      buf.write(capped[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
