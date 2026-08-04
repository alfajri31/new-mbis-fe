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

/// Isian angka desimal (rate premi, kurs, diskon) untuk papan ketik ponsel.
///
/// **Masalah yang diperbaiki.** Papan ketik angka Android memunculkan tombol pemisah
/// desimal sesuai locale perangkat — **koma** untuk Indonesia. Filter lama hanya
/// mengizinkan `[0-9.]`, sehingga tombol koma terlihat ada tetapi setiap ditekan
/// karakternya dibuang diam-diam. Bagi pemakai gejalanya persis seperti tombol rusak:
/// "ada koma tapi tidak bisa dipencet", dan rate 2,5% mustahil diketik dari ponsel.
///
/// **Aturannya.** Titik dan koma sama-sama diterima, lalu **diseragamkan jadi titik**
/// supaya `double.tryParse` di seluruh aplikasi bekerja tanpa perlu tahu pemisah mana
/// yang dipakai perangkat. Pemisah kedua ditolak (`1.2.3` mustahil), karakter selain
/// angka dibuang, dan pemisah di awal dilengkapi nol (`,5` → `0.5`) supaya isinya
/// selalu angka sah — bukan string yang lolos ke `tryParse` lalu jadi null dan
/// dilaporkan ke pemakai sebagai "angka tidak valid".
///
/// Posisi kursor dihitung ulang mengikuti karakter yang benar-benar dipertahankan,
/// jadi menyisipkan atau menghapus di tengah teks tidak melompatkan kursor ke ujung.
class DecimalInputFormatter extends TextInputFormatter {
  const DecimalInputFormatter({this.decimalRange});

  /// Maksimum angka di belakang pemisah. `null` = bebas.
  final int? decimalRange;

  static const int _zero = 0x30; // '0'
  static const int _nine = 0x39; // '9'

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final src = newValue.text;
    final cursor = newValue.selection.baseOffset;
    final buf = StringBuffer();
    var kept = 0; // karakter dipertahankan yang berada SEBELUM kursor
    var hasSeparator = false;
    var decimals = 0;

    for (var i = 0; i < src.length; i++) {
      final ch = src[i];
      final code = ch.codeUnitAt(0);
      String? keep;

      if (code >= _zero && code <= _nine) {
        // Angka di belakang pemisah dibatasi hanya bila decimalRange diminta.
        final full = hasSeparator && decimalRange != null && decimals >= decimalRange!;
        if (!full) {
          keep = ch;
          if (hasSeparator) decimals++;
        }
      } else if ((ch == '.' || ch == ',') && !hasSeparator) {
        keep = '.'; // koma pun disimpan sebagai titik
        hasSeparator = true;
      }

      if (keep != null) {
        buf.write(keep);
        if (cursor > i) kept++;
      }
    }

    var text = buf.toString();
    var offset = cursor < 0 ? text.length : kept;
    if (text.startsWith('.')) {
      text = '0$text';
      offset++;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset.clamp(0, text.length)),
      // Teks ditulis ulang; menyisakan composing range milik teks lama membuat
      // papan ketik memakai rentang yang tak lagi cocok.
      composing: TextRange.empty,
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
    final formatted = maskNpwp(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Terapkan mask NPWP `XX.XXX.XXX.X-XXX.XXX` pada string apa pun (hanya angka
/// yang dipakai, dipotong 15 digit). Dipakai formatter live & saat prefill nilai
/// tersimpan (yang disimpan sebagai angka murni).
String maskNpwp(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
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
  return buf.toString();
}
