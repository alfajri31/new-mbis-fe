import 'dashboard_repository.dart';

/// Rentang periode untuk kartu Target vs Realisasi (CR-02, umpan balik piloting
/// Tangerang: pimpinan cabang butuh memotong angka per bulan/triwulan, bukan YTD saja).
///
/// Seluruhnya dihitung DI KLIEN dari `DashboardCategoryStat.months` — server sudah
/// mengirim 12 bulan target & realisasi sekaligus dalam satu panggilan `/categories`,
/// memang supaya pergantian filter tidak perlu bolak-balik ke server. Jadi tidak ada
/// endpoint baru, dan berpindah periode terasa seketika.
enum DashboardPeriode {
  ytd('YTD', 'Januari s/d bulan berjalan'),
  mtd('MTD', 'Bulan berjalan saja'),
  tw1('Triwulan I', 'Januari - Maret'),
  tw2('Triwulan II', 'April - Juni'),
  tw3('Triwulan III', 'Juli - September'),
  tw4('Triwulan IV', 'Oktober - Desember');

  const DashboardPeriode(this.label, this.keterangan);

  final String label;
  final String keterangan;

  /// Bulan (1..12) yang tercakup periode ini, dibatasi sampai [currentMonth].
  ///
  /// [currentMonth] berasal dari server: bulan berjalan untuk tahun ini, dan 12 untuk
  /// tahun yang sudah lewat (lihat DashboardService). Pembatasan itu penting supaya
  /// Triwulan IV di bulan Agustus tidak menjumlahkan bulan yang belum terjadi lalu
  /// menampilkan pencapaian 0% seolah-olah RM gagal — untuk periode yang memang belum
  /// tiba, hasilnya kosong dan layar menyatakannya apa adanya.
  List<int> months(int currentMonth) {
    final batas = currentMonth.clamp(1, 12);
    switch (this) {
      case DashboardPeriode.ytd:
        return [for (int m = 1; m <= batas; m++) m];
      case DashboardPeriode.mtd:
        return [batas];
      case DashboardPeriode.tw1:
        return _rentang(1, 3, batas);
      case DashboardPeriode.tw2:
        return _rentang(4, 6, batas);
      case DashboardPeriode.tw3:
        return _rentang(7, 9, batas);
      case DashboardPeriode.tw4:
        return _rentang(10, 12, batas);
    }
  }

  static List<int> _rentang(int dari, int sampai, int batas) {
    if (dari > batas) return const []; // triwulan yang belum tiba
    return [for (int m = dari; m <= sampai && m <= batas; m++) m];
  }
}

/// Target & realisasi hasil penjumlahan satu periode.
class AngkaPeriode {
  /// Periode ini belum tiba sama sekali (mis. Triwulan IV dilihat di bulan Agustus).
  final bool belumTiba;
  final double target;
  final double realisasi;

  const AngkaPeriode({
    required this.belumTiba,
    required this.target,
    required this.realisasi,
  });

  /// Rasio pencapaian. Aturannya sengaja disamakan dengan getter `progress` pada
  /// [DashboardCategoryStat]: target 0 tapi ada realisasi dihitung 100%, keduanya 0
  /// dihitung 0. Bisa lebih dari 1 — melampaui target itu boleh dan harus terlihat.
  double get progress {
    if (belumTiba) return 0;
    if (target > 0) return realisasi / target;
    return realisasi > 0 ? 1.0 : 0.0;
  }
}

/// Jumlahkan target & realisasi kategori ini untuk [periode].
///
/// Bulan yang tidak dikirim server dianggap nol, bukan dilewati — bulan tanpa baris
/// berarti tidak ada target maupun realisasi, dan itu memang nol.
AngkaPeriode hitungPeriode(
  DashboardCategoryStat cat,
  DashboardPeriode periode,
  int currentMonth,
) {
  final bulan = periode.months(currentMonth);
  if (bulan.isEmpty) {
    return const AngkaPeriode(belumTiba: true, target: 0, realisasi: 0);
  }
  final perBulan = <int, DashboardCategoryMonth>{
    for (final m in cat.months) m.month: m,
  };
  double target = 0;
  double realisasi = 0;
  for (final m in bulan) {
    final row = perBulan[m];
    if (row == null) continue;
    target += row.target;
    realisasi += row.realisasi;
  }
  return AngkaPeriode(belumTiba: false, target: target, realisasi: realisasi);
}
