import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/src/dashboard/dashboard_periode.dart';
import 'package:mbis/src/dashboard/dashboard_repository.dart';

/// CR-02 — potongan periode Target vs Realisasi dihitung di klien dari 12 bulan
/// yang dikirim `/api/dashboard/categories`. Aturan pembatasan bulannya yang paling
/// mudah salah diam-diam, jadi dikunci di sini.
void main() {
  DashboardCategoryMonth bulan(int m, {double target = 0, double realisasi = 0}) =>
      DashboardCategoryMonth(
        month: m,
        label: 'B$m',
        target: target,
        realisasi: realisasi,
        realisasiWon: realisasi,
      );

  /// Kategori dengan target 100 dan realisasi 10×bulan untuk kedua belas bulan.
  DashboardCategoryStat kategori() => DashboardCategoryStat(
        category: 'X',
        label: 'X',
        description: '',
        targetYtd: 0,
        realisasiYtd: 0,
        targetFullYear: 1200,
        realisasiWonYtd: 0,
        realisasiResmiYtd: 0,
        bulanResmi: 0,
        months: [
          for (int m = 1; m <= 12; m++) bulan(m, target: 100, realisasi: m * 10),
        ],
      );

  group('rentang bulan', () {
    test('YTD = Januari s/d bulan berjalan', () {
      expect(DashboardPeriode.ytd.months(8), [1, 2, 3, 4, 5, 6, 7, 8]);
    });

    test('MTD = bulan berjalan saja', () {
      expect(DashboardPeriode.mtd.months(8), [8]);
    });

    test('triwulan yang sudah lewat utuh', () {
      expect(DashboardPeriode.tw1.months(8), [1, 2, 3]);
      expect(DashboardPeriode.tw2.months(8), [4, 5, 6]);
    });

    test('triwulan berjalan dipotong di bulan berjalan', () {
      // Agustus: Triwulan III (Jul-Sep) baru terisi Juli & Agustus. Tanpa pemotongan
      // ini September ikut terhitung sebagai target tanpa realisasi.
      expect(DashboardPeriode.tw3.months(8), [7, 8]);
    });

    test('triwulan yang belum tiba kosong, bukan nol palsu', () {
      expect(DashboardPeriode.tw4.months(8), isEmpty);
    });

    test('tahun lampau (currentMonth 12) memuat semua triwulan utuh', () {
      expect(DashboardPeriode.tw4.months(12), [10, 11, 12]);
      expect(DashboardPeriode.ytd.months(12).length, 12);
    });
  });

  group('penjumlahan angka', () {
    test('YTD menjumlahkan seluruh bulan berjalan', () {
      final a = hitungPeriode(kategori(), DashboardPeriode.ytd, 8);
      expect(a.target, 800); // 8 bulan x 100
      expect(a.realisasi, 360); // 10+20+...+80
      expect(a.belumTiba, isFalse);
    });

    test('MTD hanya bulan berjalan', () {
      final a = hitungPeriode(kategori(), DashboardPeriode.mtd, 8);
      expect(a.target, 100);
      expect(a.realisasi, 80);
    });

    test('triwulan berjalan hanya menjumlahkan bulan yang sudah terjadi', () {
      final a = hitungPeriode(kategori(), DashboardPeriode.tw3, 8);
      expect(a.target, 200); // Juli + Agustus, BUKAN 300
      expect(a.realisasi, 150); // 70 + 80
    });

    test('periode belum tiba ditandai, progress-nya nol', () {
      final a = hitungPeriode(kategori(), DashboardPeriode.tw4, 8);
      expect(a.belumTiba, isTrue);
      expect(a.target, 0);
      expect(a.realisasi, 0);
      expect(a.progress, 0);
    });

    test('target nol tapi ada realisasi dihitung 100%, sama seperti getter progress', () {
      final cat = DashboardCategoryStat(
        category: 'X',
        label: 'X',
        description: '',
        targetYtd: 0,
        realisasiYtd: 0,
        targetFullYear: 0,
        realisasiWonYtd: 0,
        realisasiResmiYtd: 0,
        bulanResmi: 0,
        months: [bulan(1, target: 0, realisasi: 500)],
      );
      expect(hitungPeriode(cat, DashboardPeriode.mtd, 1).progress, 1.0);
    });

    test('melampaui target boleh lebih dari 100%', () {
      final cat = DashboardCategoryStat(
        category: 'X',
        label: 'X',
        description: '',
        targetYtd: 0,
        realisasiYtd: 0,
        targetFullYear: 0,
        realisasiWonYtd: 0,
        realisasiResmiYtd: 0,
        bulanResmi: 0,
        months: [bulan(1, target: 100, realisasi: 250)],
      );
      expect(hitungPeriode(cat, DashboardPeriode.mtd, 1).progress, 2.5);
    });

    test('bulan yang tidak dikirim server dihitung nol, bukan melempar', () {
      final cat = DashboardCategoryStat(
        category: 'X',
        label: 'X',
        description: '',
        targetYtd: 0,
        realisasiYtd: 0,
        targetFullYear: 0,
        realisasiWonYtd: 0,
        realisasiResmiYtd: 0,
        bulanResmi: 0,
        months: [bulan(1, target: 100, realisasi: 10)], // hanya Januari
      );
      final a = hitungPeriode(cat, DashboardPeriode.ytd, 3);
      expect(a.target, 100);
      expect(a.realisasi, 10);
    });
  });
}
