import 'dart:math';

/// Jenis produk yang didukung Quotation Slip.
enum QsProduct { psakdi, paXtra }

/// Tipe pertanggungan.
enum QsType { single, group }

/// Mode perhitungan premi.
enum QsPremiMode { normal, mutlak, flat }

/// Jenis risiko PSAKDI.
enum PsakdiRiskType { a, ab }

/// Jenis polis.
enum QsPolisType { cetak, ePolis }

/// Status QS.
enum QsStatus { draft, menungguUw, ditolakUw, disetujuiUw, finalQs }

// ---------------------------------------------------------------------------
// Keyword → kelas saran
// ---------------------------------------------------------------------------
const Map<int, List<String>> _kelasKeywords = {
  4: [
    'tambang', 'listrik', 'tegangan', 'bangunan bertingkat', 'lepas pantai',
    'awak kapal', 'kendaraan umum', 'ojek',
  ],
  3: [
    'dokter gigi', 'bedah', 'paramedis', 'perawat', 'sopir', 'supir',
    'mekanik', 'laboratorium', 'manajer lapangan', 'teknisi',
  ],
  2: [
    'penjualan', 'sales', 'marketing', 'ibu rumah tangga', 'pimpinan proyek',
    'manajer', 'wiraswasta', 'pedagang',
  ],
  1: [
    'direktur', 'akuntan', 'sekretaris', 'administrasi', 'karyawan', 'staf',
    'pns', 'bumn', 'pegawai',
  ],
};

/// Default rate PSAKDI per kelas (%).
const Map<String, List<double>> defaultPsakdiRates = {
  // index 0=Kelas1, 1=Kelas2, 2=Kelas3, 3=Kelas4
  'A':  [0.08, 0.10, 0.12, 0.16],
  'AB': [0.10, 0.13, 0.16, 0.18],
  'C':  [2.00, 2.00, 2.00, 2.00],
};

/// Default rate PA Xtra (%).
const double defaultPaXtraRatePokokWithCacatTetap = 0.15;
const double defaultPaXtraRatePokokWithoutCacatTetap = 0.10;

const Map<String, double> defaultPaXtraSantunanRates = {
  'pengobatan':  2.00,
  'ambulan':     2.00,
  'pemakaman':   0.10,
  'barang':      2.00,
  'dokumen':     2.00,
  'pendidikan':  0.10,
  'pemulangan':  0.10,
};

/// Batas maksimal santunan PA Xtra.
double batasSantunan(String key, double up) {
  switch (key) {
    case 'pengobatan':  return min(0.10 * up, 10000000);
    case 'ambulan':     return min(0.10 * up,  2000000);
    case 'pemakaman':   return min(0.10 * up,  2000000);
    case 'barang':      return min(0.10 * up,   500000);
    case 'dokumen':     return min(0.10 * up,   500000);
    case 'pendidikan':  return min(0.10 * up,  5000000);
    case 'pemulangan':
    case 'repatriasi':  return min(0.10 * up,  5000000);
    default: return 0;
  }
}

/// Label santunan PA Xtra.
const Map<String, String> santunanLabels = {
  'pengobatan':  'Perawatan & Pengobatan',
  'ambulan':     'Ambulan & Evakuasi',
  'pemakaman':   'Pemakaman / Kremasi',
  'barang':      'Kehilangan Barang Pribadi',
  'dokumen':     'Pengurusan Dokumen',
  'pendidikan':  'Biaya Pendidikan',
  'pemulangan':  'Pemulangan Jenazah / Repatriasi',
};

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Saran kelas dari pekerjaan.
int? saranKelas(String pekerjaan) {
  final lower = pekerjaan.toLowerCase().trim();
  if (lower.isEmpty) return null;
  for (final entry in _kelasKeywords.entries) {
    for (final kw in entry.value) {
      if (lower.contains(kw)) return entry.key;
    }
  }
  return null;
}

/// Hitung usia pada tanggal tertentu.
int hitungUsia(DateTime lahir, DateTime padaTanggal) {
  int usia = padaTanggal.year - lahir.year;
  if (padaTanggal.month < lahir.month ||
      (padaTanggal.month == lahir.month && padaTanggal.day < lahir.day)) {
    usia--;
  }
  return usia;
}

/// Hitung usia dalam bulan (untuk PA Xtra batas bawah 3 bulan).
int hitungUsiaBulan(DateTime lahir, DateTime padaTanggal) {
  return (padaTanggal.year - lahir.year) * 12 +
      padaTanggal.month - lahir.month -
      (padaTanggal.day < lahir.day ? 1 : 0);
}

/// Validasi usia mengembalikan pesan error atau null.
String? validasiUsia(QsProduct product, DateTime? lahir, DateTime? mulai) {
  if (lahir == null || mulai == null) return null;
  if (product == QsProduct.psakdi) {
    final usia = hitungUsia(lahir, mulai);
    if (usia < 17 || usia > 60) {
      return 'Usia di luar ketentuan. PSAKDI Single: minimal 17 tahun, maksimal 60 tahun.';
    }
  } else {
    final bulan = hitungUsiaBulan(lahir, mulai);
    final usia = hitungUsia(lahir, mulai);
    if (bulan < 3 || usia > 75) {
      return 'Usia di luar ketentuan. PA Xtra Single: minimal 3 bulan, maksimal 75 tahun.';
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Penyimpangan UW
// ---------------------------------------------------------------------------

/// Satu butir penyimpangan yang memicu persetujuan UW.
class UwDeviation {
  final String field;
  final String message;
  const UwDeviation({required this.field, required this.message});
}

/// Deteksi semua penyimpangan dari form state.
List<UwDeviation> detectDeviations({
  required QsProduct product,
  required QsPremiMode mode,
  // PSAKDI
  int? kelasPeserta,
  int? saranKelasPeserta,
  double? rateA,
  double? rateAB,
  double? rateC,
  double? premiMutlakTotal,
  double? premiStandarTotal,
  double? tarifFlatPerHari,
  double? saranFlatPerHari,
  // PA Xtra T/C
  bool tcTambahanDiubah = false,
  String? deductible,
}) {
  final deviations = <UwDeviation>[];

  if (product == QsProduct.psakdi) {
    // 1. Kelas lebih rendah dari saran
    if (kelasPeserta != null && saranKelasPeserta != null &&
        kelasPeserta < saranKelasPeserta) {
      deviations.add(UwDeviation(
        field: 'Klasifikasi Peserta',
        message: 'Kelas $kelasPeserta lebih rendah dari saran (Kelas $saranKelasPeserta).',
      ));
    }

    if (mode == QsPremiMode.normal) {
      // 2. Rate di bawah tabel
      final kelasIdx = (kelasPeserta ?? 1) - 1;
      if (rateA != null) {
        final std = defaultPsakdiRates['A']![kelasIdx];
        if (rateA < std) {
          deviations.add(UwDeviation(
            field: 'Rate A',
            message: 'Rate A ($rateA%) di bawah standar ($std%).',
          ));
        }
      }
      if (rateAB != null) {
        final std = defaultPsakdiRates['AB']![kelasIdx];
        if (rateAB < std) {
          deviations.add(UwDeviation(
            field: 'Rate A/B',
            message: 'Rate A/B ($rateAB%) di bawah standar ($std%).',
          ));
        }
      }
      if (rateC != null) {
        final std = defaultPsakdiRates['C']![kelasIdx];
        if (rateC < std) {
          deviations.add(UwDeviation(
            field: 'Rate C',
            message: 'Rate C ($rateC%) di bawah standar ($std%).',
          ));
        }
      }
    } else if (mode == QsPremiMode.mutlak) {
      // 3. Premi mutlak di bawah tarif standar
      if (premiMutlakTotal != null && premiStandarTotal != null &&
          premiMutlakTotal < premiStandarTotal) {
        deviations.add(const UwDeviation(
          field: 'Premi Mutlak',
          message: 'Total premi manual di bawah tarif standar.',
        ));
      }
    } else if (mode == QsPremiMode.flat) {
      // 4. Tarif flat di bawah saran
      if (tarifFlatPerHari != null && saranFlatPerHari != null &&
          tarifFlatPerHari < saranFlatPerHari) {
        deviations.add(UwDeviation(
          field: 'Tarif Flat',
          message: 'Tarif per hari (Rp ${tarifFlatPerHari.toStringAsFixed(0)}) di bawah saran (Rp ${saranFlatPerHari.toStringAsFixed(0)}).',
        ));
      }
    }
  } else {
    // PA Xtra
    if (mode == QsPremiMode.flat) {
      if (tarifFlatPerHari != null && saranFlatPerHari != null &&
          tarifFlatPerHari < saranFlatPerHari) {
        deviations.add(UwDeviation(
          field: 'Tarif Flat',
          message: 'Tarif per hari (Rp ${tarifFlatPerHari.toStringAsFixed(0)}) di bawah saran (Rp ${saranFlatPerHari.toStringAsFixed(0)}).',
        ));
      }
    }
    // 5. T/C tambahan diubah
    if (tcTambahanDiubah) {
      deviations.add(const UwDeviation(
        field: 'T/C Tambahan',
        message: 'T/C tambahan diubah dari standar.',
      ));
    }
    // 6. Deductible bukan Nil
    if (deductible != null && deductible.isNotEmpty &&
        deductible.toLowerCase() != 'nil') {
      deviations.add(UwDeviation(
        field: 'Deductible',
        message: 'Deductible diisi "$deductible" (bukan Nil).',
      ));
    }
  }

  return deviations;
}

// ---------------------------------------------------------------------------
// Perhitungan Premi
// ---------------------------------------------------------------------------

/// Hasil perhitungan premi.
class PremiResult {
  final double premiPokok;     // A or AB (or Pokok PA Xtra)
  final double premiTambahan;  // C (or Tambahan PA Xtra)
  final double gross;
  final double diskon;
  final double netto;
  final double biayaAdmin;
  final double total;

  const PremiResult({
    required this.premiPokok,
    required this.premiTambahan,
    required this.gross,
    required this.diskon,
    required this.netto,
    required this.biayaAdmin,
    required this.total,
  });
}

/// Hitung premi PSAKDI Normal.
PremiResult hitungPsakdiNormal({
  required double upA,
  required PsakdiRiskType riskType,
  double? upC,
  required double rateAB,
  required double rateC,
  required int hari,
  required int jumlahOrang,
  required double diskonPersen,
  required double biayaAdmin,
}) {
  final premiAB = upA * (rateAB / 100) * (hari / 365) * jumlahOrang;
  final premiC = (upC ?? 0) * (rateC / 100) * (hari / 365) * jumlahOrang;
  final gross = premiAB + premiC;
  final disk = gross * (diskonPersen / 100);
  final netto = gross - disk;
  final total = netto + biayaAdmin;
  return PremiResult(
    premiPokok: premiAB,
    premiTambahan: premiC,
    gross: gross,
    diskon: disk,
    netto: netto,
    biayaAdmin: biayaAdmin,
    total: total,
  );
}

/// Hitung premi PSAKDI Flat.
double saranFlatPsakdi({
  required double upA,
  required PsakdiRiskType riskType,
  double? upC,
  required double rateAB,
  required double rateC,
}) {
  final pAB = upA * rateAB / 100;
  final pC = (upC ?? 0) * rateC / 100;
  return ((pAB + pC) / 365).ceilToDouble();
}

/// Hitung premi PA Xtra Normal.
PremiResult hitungPaXtraNormal({
  required double up,
  required bool cacatTetap,
  required Map<String, double> santunanValues,
  required int hari,
  required int jumlahOrang,
  required double diskonPersen,
  required double biayaAdmin,
}) {
  final ratePokok = cacatTetap
      ? defaultPaXtraRatePokokWithCacatTetap
      : defaultPaXtraRatePokokWithoutCacatTetap;
  final premiPokok = up * (ratePokok / 100) * (hari / 365) * jumlahOrang;

  double sumPremiSantunan = 0;
  for (final entry in santunanValues.entries) {
    final rate = defaultPaXtraSantunanRates[entry.key] ?? 0;
    sumPremiSantunan += entry.value * (rate / 100);
  }
  final premiTambahan = sumPremiSantunan * (hari / 365) * jumlahOrang;

  final gross = premiPokok + premiTambahan;
  final disk = gross * (diskonPersen / 100);
  final netto = gross - disk;
  final total = netto + biayaAdmin;
  return PremiResult(
    premiPokok: premiPokok,
    premiTambahan: premiTambahan,
    gross: gross,
    diskon: disk,
    netto: netto,
    biayaAdmin: biayaAdmin,
    total: total,
  );
}

/// Saran flat per hari PA Xtra.
double saranFlatPaXtra({
  required double up,
  required bool cacatTetap,
  required Map<String, double> santunanValues,
}) {
  final ratePokok = cacatTetap
      ? defaultPaXtraRatePokokWithCacatTetap
      : defaultPaXtraRatePokokWithoutCacatTetap;
  final premiPokokTahunan = up * (ratePokok / 100);

  double sumPremiSantunan = 0;
  for (final entry in santunanValues.entries) {
    final rate = defaultPaXtraSantunanRates[entry.key] ?? 0;
    sumPremiSantunan += entry.value * (rate / 100);
  }

  return ((premiPokokTahunan + sumPremiSantunan) / 365).ceilToDouble();
}

/// Biaya admin berdasarkan jenis polis.
double biayaAdminForPolis(QsPolisType type) {
  switch (type) {
    case QsPolisType.cetak:
      return 30000; // Polis 20k + Materai 10k
    case QsPolisType.ePolis:
      return 10000; // Materai saja
  }
}

/// Format tanggal Indonesia (contoh: "14 Okt 2026" atau "14 Oktober 2026").
/// Mencegah runtime LocaleDataException dari package:intl jika initializeDateFormatting belum dipanggil.
String formatTglIndo(DateTime? dt, {bool longMonth = false}) {
  if (dt == null) return '';
  const shortMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  const longMonths = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  final m = longMonth ? longMonths[dt.month - 1] : shortMonths[dt.month - 1];
  final d = dt.day.toString().padLeft(2, '0');
  return '$d $m ${dt.year}';
}
