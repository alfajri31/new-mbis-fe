import 'dart:convert' show LineSplitter;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Menanam (burn-in) cap waktu dan lokasi ke dalam PIKSEL foto kunjungan — CR-12 (MTR-7).
///
/// Sengaja bukan metadata EXIF: EXIF hilang begitu gambar dikompres ulang, di-share
/// lewat chat, atau ditempel ke dokumen — persis perjalanan yang dialami foto bukti
/// kunjungan. Yang tercetak di piksel ikut ke mana pun gambarnya pergi, dan itulah
/// alasan cabang memintanya.
///
/// Dijalankan di isolate lewat [compute]: encode/decode JPEG di paket `image` murni
/// Dart dan makan ratusan milidetik untuk foto belasan megapiksel — di thread UI itu
/// terasa sebagai aplikasi membeku tepat setelah tombol ditekan.
class VisitPhotoStamp {
  const VisitPhotoStamp._();

  /// Kembalikan JPEG baru berisi [bytes] dengan panel keterangan di bagian bawah.
  ///
  /// Mengembalikan [bytes] APA ADANYA bila gambarnya gagal didekode. Foto tanpa cap
  /// masih jauh lebih berguna daripada kunjungan yang gagal tersimpan — pencapan ini
  /// pelengkap bukti, bukan syarat sahnya data.
  static Future<Uint8List> apply({
    required Uint8List bytes,
    required DateTime takenAt,
    required String timeZoneLabel,
    String? locationLabel,
    double? latitude,
    double? longitude,
  }) {
    return compute(
      _stamp,
      _StampRequest(
        bytes: bytes,
        lines: _buildLines(
          takenAt: takenAt,
          timeZoneLabel: timeZoneLabel,
          locationLabel: locationLabel,
          latitude: latitude,
          longitude: longitude,
        ),
      ),
    );
  }

  /// Baris teks yang dicetak, urut dari atas. Dipisah agar bisa diuji tanpa gambar.
  @visibleForTesting
  static List<String> buildLinesForTest({
    required DateTime takenAt,
    required String timeZoneLabel,
    String? locationLabel,
    double? latitude,
    double? longitude,
  }) =>
      _buildLines(
        takenAt: takenAt,
        timeZoneLabel: timeZoneLabel,
        locationLabel: locationLabel,
        latitude: latitude,
        longitude: longitude,
      );

  static List<String> _buildLines({
    required DateTime takenAt,
    required String timeZoneLabel,
    String? locationLabel,
    double? latitude,
    double? longitude,
  }) {
    final lines = <String>[
      '${_formatDateTime(takenAt)} $timeZoneLabel',
    ];
    if (locationLabel != null) {
      // Label lokasi di layar kunjungan berbentuk "alamat" + baris baru + "koordinat"
      // — MULTI-BARIS. Menyerahkannya bulat-bulat ke penggambar satu-baris membuat
      // bagian sesudah baris baru tertimpa di atas baris yang sama; pada foto uji
      // 2026-08-18 hasilnya koordinat yang saling tindih dan tak terbaca. Jadi
      // dipecah di sini, bukan mengandalkan pemanggil mengirim string bersih.
      for (final part in const LineSplitter().convert(locationLabel)) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) {
          lines.add(trimmed);
        }
      }
    }
    if (latitude != null && longitude != null) {
      // Koordinat dicetak apa adanya supaya bukti tetap bisa diverifikasi walau
      // label alamatnya kosong (geocoding gagal / offline). Kalau label tadi sudah
      // memuat koordinat versi pendek, baris itu dibuang supaya tidak kembar —
      // dibandingkan lewat awalannya karena presisi desimalnya memang berbeda.
      final precise = '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
      lines.removeWhere((l) => _looksLikeSameCoordinate(l, latitude, longitude));
      lines.add(precise);
    }
    return lines;
  }

  /// True bila [line] adalah penulisan koordinat yang sama dengan [lat]/[lng] pada
  /// presisi berapa pun (layar memakai 5 desimal, cap memakai 6).
  static bool _looksLikeSameCoordinate(String line, double lat, double lng) {
    final compact = line.replaceAll(' ', '');
    for (var digits = 4; digits <= 6; digits++) {
      final candidate =
          '${lat.toStringAsFixed(digits)},${lng.toStringAsFixed(digits)}';
      if (compact == candidate) {
        return true;
      }
    }
    return false;
  }

  static String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final d = dt.day.toString().padLeft(2, '0');
    final m = months[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d $m ${dt.year} $hh:$mm';
  }
}

/// Argumen [compute] — satu objek karena [compute] hanya menerima satu parameter.
class _StampRequest {
  const _StampRequest({required this.bytes, required this.lines});

  final Uint8List bytes;
  final List<String> lines;
}

/// Lebar teks dalam piksel menurut metrik font bitmap-nya.
///
/// Wajib diukur, tidak boleh ditaksir: [img.drawString] tanpa `wrap` menulis lurus
/// melewati tepi kanan gambar, dan karena penulisannya menembus akhir buffer piksel,
/// kelebihannya MELINGKAR ke bagian atas gambar. Di layar uji hal itu terlihat sebagai
/// alamat yang "muncul dua kali" plus baris koordinat yang saling tindih — ditemukan
/// 2026-08-18 pada foto kamera asli 3072x4096, bukan pada gambar uji kecil.
int _measure(img.BitmapFont font, String text) {
  var width = 0;
  for (final code in text.codeUnits) {
    final ch = font.characters[code];
    width += ch?.xAdvance ?? (font.base ~/ 2);
  }
  return width;
}

/// Pecah [line] menjadi baris-baris yang muat dalam [maxWidth]. Kata tunggal yang
/// tetap tidak muat (mis. koordinat panjang tanpa spasi) dipotong paksa, karena
/// membiarkannya lewat berarti mengulang cacat di atas.
List<String> _fitToWidth(img.BitmapFont font, String line, int maxWidth) {
  if (maxWidth <= 0 || _measure(font, line) <= maxWidth) {
    return [line];
  }
  final out = <String>[];
  var current = '';
  for (final word in line.split(' ')) {
    final candidate = current.isEmpty ? word : '$current $word';
    if (_measure(font, candidate) <= maxWidth) {
      current = candidate;
      continue;
    }
    if (current.isNotEmpty) {
      out.add(current);
    }
    var solo = word;
    while (solo.length > 1 && _measure(font, solo) > maxWidth) {
      solo = solo.substring(0, solo.length - 1);
    }
    current = solo;
  }
  if (current.isNotEmpty) {
    out.add(current);
  }
  return out;
}

/// Baris siap gambar: hasil pembungkusan [lines] pada lebar [maxWidth], dibatasi
/// [maxLines] supaya panel tidak menelan setengah foto saat alamatnya sangat panjang.
@visibleForTesting
List<String> layoutStampLines(
  img.BitmapFont font,
  List<String> lines,
  int maxWidth, {
  int maxLines = 6,
}) {
  final out = <String>[];
  for (final line in lines) {
    for (final piece in _fitToWidth(font, line, maxWidth)) {
      if (out.length >= maxLines) return out;
      out.add(piece);
    }
  }
  return out;
}

/// Harus top-level (syarat [compute]): closure tidak bisa dikirim ke isolate.
Uint8List _stamp(_StampRequest req) {
  final decoded = img.decodeImage(req.bytes);
  if (decoded == null || req.lines.isEmpty) {
    return req.bytes;
  }

  // Ukuran huruf mengikuti lebar gambar. Foto kamera HP bisa >3000 px; font kecil
  // di gambar sebesar itu tidak terbaca setelah diperkecil di layar/laporan.
  final width = decoded.width;
  final font = width >= 1600
      ? img.arial48
      : width >= 800
          ? img.arial24
          : img.arial14;
  final lineHeight = font.lineHeight;
  final padding = (lineHeight * 0.4).round();

  final lines = layoutStampLines(font, req.lines, width - padding * 2);
  if (lines.isEmpty) {
    return req.bytes;
  }

  final panelHeight = lineHeight * lines.length + padding * 2;
  final panelTop = decoded.height - panelHeight < 0 ? 0 : decoded.height - panelHeight;

  // Panel gelap semi-transparan: teks putih polos hilang di atas dinding/langit terang.
  img.fillRect(
    decoded,
    x1: 0,
    y1: panelTop,
    x2: width - 1,
    y2: decoded.height - 1,
    color: img.ColorRgba8(0, 0, 0, 140),
  );

  var y = panelTop + padding;
  for (final line in lines) {
    img.drawString(
      decoded,
      line,
      font: font,
      x: padding,
      y: y,
      color: img.ColorRgb8(255, 255, 255),
    );
    y += lineHeight;
  }

  // JPEG, bukan PNG: sumbernya foto, dan PNG dari foto berukuran berkali lipat —
  // langsung terasa pada unggahan RM di jaringan cabang.
  return Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
}
