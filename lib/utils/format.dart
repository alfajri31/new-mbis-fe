/// Centralized number/currency formatting — design.md §8.1.
///
/// Kept in one place so screens never format inline; when we move to real
/// backend data + `intl`, only this file changes.
class AppFormat {
  AppFormat._();

  /// Parse a pre-formatted premi/TSI string (e.g. "Rp 375.000.000") into a
  /// numeric IDR amount. Returns null for non-IDR currencies so callers can
  /// exclude them from an IDR total instead of mixing currencies.
  static num? parseIdr(String formatted, String currency) {
    if (currency.toUpperCase() != 'IDR') return null;
    final digits = formatted.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return num.tryParse(digits);
  }

  /// Short currency format untuk kartu ringkasan:
  /// ≥ 1 Miliar → "Rp X,XX M"; ≥ 1 Juta → "Rp X,X Jt"; ≥ 1 Ribu → "Rp X Rb";
  /// sisanya angka utuh.
  ///
  /// Tiga hal yang diperbaiki di sini, semuanya bergejala di kartu dashboard:
  ///
  /// 1. **Tingkat ribuan dulu tidak ada**, jadi nilai di bawah satu juta jatuh ke
  ///    angka utuh — "Rp 850.000". Di kartu ringkasan yang seharusnya sekali lihat,
  ///    deretan digit bertitik itu justru yang paling lambat dibaca, dan mudah
  ///    tertukar dengan desimal.
  /// 2. **Bagian bulat tidak punya pemisah ribuan**, sehingga nominal besar tampil
  ///    "Rp 1234,56 M" — empat digit menempel tanpa jeda.
  /// 3. **Nilai negatif tidak ikut dipendekkan**: perbandingan `>=` gagal untuk
  ///    bilangan minus, jadi ia lolos ke cabang terakhir dan tampil utuh. Sejak
  ///    realisasi resmi boleh minus (koreksi/pembatalan polis), ini bukan lagi
  ///    kasus teoretis.
  static String currencyShort(num idr) {
    final negatif = idr < 0;
    final v = idr.abs();
    final String badan;
    if (v >= 1000000000) {
      badan = '${_grouped(v / 1000000000, 2)} M';
    } else if (v >= 1000000) {
      badan = '${_grouped(v / 1000000, 1)} Jt';
    } else if (v >= 1000) {
      badan = '${_grouped(v / 1000, 0)} Rb';
    } else {
      badan = thousands(v.round());
    }
    return 'Rp ${negatif ? '-' : ''}$badan';
  }

  /// Angka pendek dengan pemisah ribuan pada bagian bulatnya, mis. "1.234,56".
  static String _grouped(num value, int places) {
    final s = _decimal(value, places);
    final koma = s.indexOf(',');
    if (koma < 0) {
      return thousands(int.tryParse(s) ?? value.round());
    }
    final bulat = int.tryParse(s.substring(0, koma)) ?? value.truncate();
    return '${thousands(bulat)},${s.substring(koma + 1)}';
  }

  /// Full rupiah with thousands separators, e.g. "Rp 1.234.567".
  /// Returns "-" for zero (used by the premium calculator's empty rows).
  static String rupiah(num value) {
    if (value == 0) return '-';
    return 'Rp ${thousands(value.round())}';
  }

  /// Indonesian short month names, 1-indexed (index 0 unused).
  static const _monthsId = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// Indonesian weekday names, indexed by DateTime.weekday (Mon=1..Sun=7;
  /// index 0 unused).
  static const _daysId = [
    '', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
  ];

  /// Formats an ISO date/datetime to weekday + date, e.g. "Kamis, 25 Jun 2026".
  /// Used for date-grouped agenda headers. Same null/unparseable fallback as
  /// [dateOnly].
  static String dayDate(dynamic value) {
    if (value == null) return '-';
    final dt = value is DateTime ? value.toLocal() : DateTime.tryParse(value.toString())?.toLocal();
    if (dt == null) {
      final s = value.toString();
      return s.isEmpty ? '-' : s;
    }
    return '${_daysId[dt.weekday]}, ${dt.day} ${_monthsId[dt.month]} ${dt.year}';
  }

  /// Indonesian short weekday names, indexed by DateTime.weekday (Mon=1..Sun=7;
  /// index 0 unused).
  static const _daysShortId = [
    '', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min',
  ];

  /// Short weekday for date-chip labels, e.g. "Kam". "-" for null/unparseable.
  static String weekdayShort(dynamic value) {
    if (value == null) return '-';
    final dt = value is DateTime ? value.toLocal() : DateTime.tryParse(value.toString())?.toLocal();
    if (dt == null) return '-';
    return _daysShortId[dt.weekday];
  }

  /// Day + short month, no year, e.g. "25 Jun". "-" for null/unparseable.
  static String dayMonth(dynamic value) {
    if (value == null) return '-';
    final dt = value is DateTime ? value.toLocal() : DateTime.tryParse(value.toString())?.toLocal();
    if (dt == null) return '-';
    return '${dt.day} ${_monthsId[dt.month]}';
  }

  /// Formats an ISO date/datetime string to date-only, e.g. "25 Jun 2026".
  /// Accepts a [DateTime] or ISO string; returns "-" for null/empty,
  /// and the raw input if it can't be parsed.
  static String dateOnly(dynamic value) {
    if (value == null) return '-';
    final dt = value is DateTime ? value.toLocal() : DateTime.tryParse(value.toString())?.toLocal();
    if (dt == null) {
      final s = value.toString();
      return s.isEmpty ? '-' : s;
    }
    return '${dt.day} ${_monthsId[dt.month]} ${dt.year}';
  }

  /// Formats an ISO date/datetime to date + 24h time, e.g. "25 Jun 2026, 14:30".
  static String dateTime(dynamic value) {
    if (value == null) return '-';
    final dt = value is DateTime ? value.toLocal() : DateTime.tryParse(value.toString())?.toLocal();
    if (dt == null) {
      final s = value.toString();
      return s.isEmpty ? '-' : s;
    }
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_monthsId[dt.month]} ${dt.year}, $hh:$mm';
  }

  /// 24h time only, e.g. "14:30". "-" for null/unparseable.
  static String timeOnly(dynamic value) {
    if (value == null) return '-';
    final dt = value is DateTime ? value.toLocal() : DateTime.tryParse(value.toString())?.toLocal();
    if (dt == null) return '-';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// Indonesian timezone abbreviation for a local time, from the device's UTC
  /// offset: +7 → WIB, +8 → WITA, +9 → WIT. Falls back to "UTC±H" for any other
  /// offset (e.g. a device set outside Indonesia).
  static String timeZoneLabel([DateTime? at]) {
    final offset = (at ?? DateTime.now()).timeZoneOffset;
    switch (offset.inHours) {
      case 7:
        return 'WIB';
      case 8:
        return 'WITA';
      case 9:
        return 'WIT';
      default:
        final h = offset.inHours;
        return 'UTC${h >= 0 ? '+' : ''}$h';
    }
  }

  /// Date + 24h time + device zone label, e.g. "25 Jun 2026, 14:30 WIB". Use for
  /// schedule/visit times so a viewer in another zone sees which zone the time is in.
  static String dateTimeZone(dynamic value) {
    if (value == null) return '-';
    final dt = value is DateTime ? value.toLocal() : DateTime.tryParse(value.toString())?.toLocal();
    if (dt == null) {
      final s = value.toString();
      return s.isEmpty ? '-' : s;
    }
    return '${dateTime(dt)} ${timeZoneLabel(dt)}';
  }

  /// Indonesian decimal (comma separator), trimming a trailing ",0"/",00".
  static String _decimal(num value, int places) {
    var s = value.toStringAsFixed(places).replaceAll('.', ',');
    if (s.contains(',')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r',$'), '');
    }
    return s;
  }

  /// Thousands separator with dots (Indonesian convention).
  static String thousands(int value) {
    final s = value.abs().toString();
    final buf = StringBuffer(value < 0 ? '-' : '');
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
