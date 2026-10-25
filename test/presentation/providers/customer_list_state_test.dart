import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/presentation/providers/customer_list_provider.dart';
import 'package:mbis/src/dashboard/dashboard_repository.dart';

/// Mengunci semantik `CustomerListState.copyWith` — khususnya pembersihan field
/// nullable (regionId/branchId/entityFilter/error) via sentinel `_keep`, yang jadi
/// dasar transisi filter di CustomerListNotifier (mis. onRegionChanged clear branch,
/// onEntityChanged(null) = "Semua"). Karakterisasi migrasi setState→Riverpod.
void main() {
  group('CustomerListState.copyWith', () {
    test('default values', () {
      const s = CustomerListState();
      expect(s.page, 0);
      expect(s.searchTerm, '');
      expect(s.entityFilter, isNull);
      expect(s.regionId, isNull);
      expect(s.branchId, isNull);
      expect(s.initialLoading, true);
      expect(s.hvcFilter, false);
      expect(s.canAddCustomer, false);
      expect(s.items, isEmpty);
    });

    test('set nullable fields', () {
      final s = const CustomerListState().copyWith(
        entityFilter: 'BUMN',
        regionId: 'R1',
        branchId: 'B1',
        error: 'oops',
      );
      expect(s.entityFilter, 'BUMN');
      expect(s.regionId, 'R1');
      expect(s.branchId, 'B1');
      expect(s.error, 'oops');
    });

    test('omitted nullable fields are KEPT (not cleared)', () {
      final s = const CustomerListState().copyWith(
        entityFilter: 'BUMN',
        regionId: 'R1',
        error: 'oops',
      );
      final s2 = s.copyWith(page: 3); // hanya ubah page
      expect(s2.page, 3);
      expect(s2.entityFilter, 'BUMN');
      expect(s2.regionId, 'R1');
      expect(s2.error, 'oops');
    });

    test('explicit null CLEARS nullable fields', () {
      final s = const CustomerListState().copyWith(
        entityFilter: 'BUMN',
        regionId: 'R1',
        branchId: 'B1',
        error: 'oops',
      );
      final s2 = s.copyWith(
        entityFilter: null,
        regionId: null,
        branchId: null,
        error: null,
      );
      expect(s2.entityFilter, isNull);
      expect(s2.regionId, isNull);
      expect(s2.branchId, isNull);
      expect(s2.error, isNull);
    });

    test('onRegionChanged semantics: new region clears branch', () {
      // Cerminan CustomerListNotifier.onRegionChanged: copyWith(regionId:x, branchId:null)
      final s = const CustomerListState().copyWith(regionId: 'R1', branchId: 'B1');
      final s2 = s.copyWith(regionId: 'R2', branchId: null);
      expect(s2.regionId, 'R2');
      expect(s2.branchId, isNull);
    });

    /// CR-08. Urutan sengaja BUKAN field nullable ber-sentinel `_keep` seperti
    /// filter: selalu ada satu urutan yang berlaku, jadi "tanpa urutan" bukan
    /// keadaan yang bisa dipilih dan tidak ada yang perlu dibersihkan.
    test('urutan bawaan: terbaru (createdAt desc)', () {
      const s = CustomerListState();
      expect(s.sortBy, 'createdAt');
      expect(s.sortDir, 'desc');
    });

    test('urutan diubah independen dari filter', () {
      final s = const CustomerListState()
          .copyWith(entityFilter: 'BUMN', hvcFilter: true)
          .copyWith(sortBy: 'createdAt', sortDir: 'desc');
      expect(s.sortBy, 'createdAt');
      expect(s.sortDir, 'desc');
      // Mengurutkan bukan menyaring: filter yang aktif tidak boleh ikut hilang.
      expect(s.entityFilter, 'BUMN');
      expect(s.hvcFilter, true);
    });

    test('urutan DIPERTAHANKAN saat transisi lain (mis. pindah halaman)', () {
      final s = const CustomerListState()
          .copyWith(sortBy: 'createdAt', sortDir: 'desc');
      final s2 = s.copyWith(page: 3, initialLoading: true);
      expect(s2.sortBy, 'createdAt');
      expect(s2.sortDir, 'desc');
    });

    /// Cerminan `CustomerListNotifier.resetAllFilters`, yang sengaja TIDAK
    /// menyebut sortBy/sortDir: tombol "Reset" di sheet menghitung dan menyebut
    /// FILTER, jadi diam-diam mengubah urutan di situ membuat labelnya berbohong.
    test('reset filter tidak ikut mengembalikan urutan', () {
      final s = const CustomerListState().copyWith(
        entityFilter: 'BUMN',
        hvcFilter: true,
        stageFilter: 'P3',
        sortBy: 'createdAt',
        sortDir: 'desc',
      );
      final s2 = s.copyWith(
        entityFilter: null,
        hvcFilter: false,
        stageFilter: null,
        regionId: null,
        branchId: null,
        rmId: null,
        rmName: null,
      );
      expect(s2.entityFilter, isNull);
      expect(s2.stageFilter, isNull);
      expect(s2.sortBy, 'createdAt');
      expect(s2.sortDir, 'desc');
    });

    test('non-null fields updated independently', () {
      final s = const CustomerListState().copyWith(
        searchTerm: 'abc',
        hvcFilter: true,
        page: 2,
        totalPages: 5,
        totalElements: 42,
        initialLoading: false,
      );
      expect(s.searchTerm, 'abc');
      expect(s.hvcFilter, true);
      expect(s.page, 2);
      expect(s.totalPages, 5);
      expect(s.totalElements, 42);
      expect(s.initialLoading, false);
      // Field lain tetap default.
      expect(s.entityFilter, isNull);
    });
  });

  /// Mengunci pembedaan "belum dimuat" vs "gagal dimuat" pada kartu
  /// Target/Realisasi. Sebelum ini `_loadSummary` menelan error diam-diam,
  /// sehingga `customer-summary` yang membalas 404 di prod tampil sebagai
  /// Rp 0 / 0% dan tersangka jadi salah (dikira bug perhitungan realisasi).
  group('CustomerListState.summaryFailed', () {
    test('bawaan: belum dimuat, bukan gagal', () {
      const s = CustomerListState();
      expect(s.summary, isNull);
      expect(s.summaryFailed, false);
    });

    test('jalur gagal: summary dikosongkan DAN ditandai gagal', () {
      // Cerminan CustomerListNotifier._loadSummary catch-block.
      final loaded = const CustomerListState().copyWith(
        summary: CustomerScopedSummary(premiTarget: 100, realisasi: 40),
      );
      expect(loaded.summaryFailed, false);

      final failed = loaded.copyWith(summary: null, summaryFailed: true);
      expect(failed.summaryFailed, true);
      // Angka filter SEBELUMNYA tidak boleh tertinggal di layar.
      expect(failed.summary, isNull);
    });

    test('jalur berhasil menghapus tanda gagal sebelumnya', () {
      final failed =
          const CustomerListState().copyWith(summary: null, summaryFailed: true);
      final ok = failed.copyWith(
        summary: CustomerScopedSummary(premiTarget: 10, realisasi: 5),
        summaryFailed: false,
      );
      expect(ok.summaryFailed, false);
      expect(ok.summary?.realisasi, 5);
    });

    test('jalur cadangan: angka terisi, ditandai fallback, bukan gagal', () {
      // Cerminan CustomerListNotifier._loadSummaryFallback (sumber:
      // /api/dashboard/summary, endpoint yang sama dengan kartu dashboard).
      final fallback = const CustomerListState().copyWith(
        summary: CustomerScopedSummary(premiTarget: 0, realisasi: 55745600),
        summaryFailed: false,
        summaryIsFallback: true,
      );
      expect(fallback.summaryFailed, false);
      expect(fallback.summaryIsFallback, true);
      // Yang penting bagi pemakai: realisasinya terisi, bukan nol.
      expect(fallback.summary?.realisasi, 55745600);
    });

    test('customer-summary yang pulih membatalkan tanda fallback', () {
      final fallback = const CustomerListState().copyWith(
        summary: CustomerScopedSummary(realisasi: 55745600),
        summaryIsFallback: true,
      );
      final scoped = fallback.copyWith(
        summary: CustomerScopedSummary(premiTarget: 100, realisasi: 40),
        summaryFailed: false,
        summaryIsFallback: false,
      );
      expect(scoped.summaryIsFallback, false);
      expect(scoped.summary?.realisasi, 40);
    });

    test('kedua sumber gagal: tidak ada angka yang tertinggal', () {
      final fallback = const CustomerListState().copyWith(
        summary: CustomerScopedSummary(realisasi: 55745600),
        summaryIsFallback: true,
      );
      final failed = fallback.copyWith(
        summary: null,
        summaryFailed: true,
        summaryIsFallback: false,
      );
      expect(failed.summary, isNull);
      expect(failed.summaryFailed, true);
      expect(failed.summaryIsFallback, false);
    });

    test('summaryFailed tidak berubah bila tidak disebut', () {
      final failed =
          const CustomerListState().copyWith(summary: null, summaryFailed: true);
      final s2 = failed.copyWith(page: 2); // transisi lain, mis. paginasi
      expect(s2.summaryFailed, true);
    });
  });

  /// Mengunci agar dropdown COB tetap menggerakkan angka saat kartu memakai
  /// jalur cadangan. Sebelum ini cadangan hanya memakai `/summary` (yang tak
  /// mengenal COB), sehingga memilih KUR/KBG menampilkan angka "Semua COB" yang
  /// sama persis — dilaporkan lagi sebagai bug realisasi.
  group('applyCobToFallback', () {
    DashboardCategoryStat stat(
      String category, {
      required double targetFullYear,
      required double realisasiYtd,
      List<DashboardCategoryMonth> months = const [],
    }) =>
        DashboardCategoryStat(
          category: category,
          label: category,
          description: '',
          targetYtd: 0,
          realisasiYtd: realisasiYtd,
          targetFullYear: targetFullYear,
          // Uji ini soal pemilihan COB, bukan soal realisasi resmi: tanpa
          // unggahan pusat, angka yang tampil memang sama dengan angka WON.
          realisasiWonYtd: realisasiYtd,
          realisasiResmiYtd: 0,
          bulanResmi: 0,
          months: months,
        );

    DashboardCategories cats(List<DashboardCategoryStat> list,
            {int currentMonth = 8}) =>
        DashboardCategories(
          year: 2026,
          currentMonth: currentMonth,
          defaultCategory: 'NON_PROGRAM_NON_ASKRED',
          categories: list,
        );

    final base = CustomerScopedSummary(
      premiTarget: 0,
      realisasi: 55745600,
      realisasiMtd: 1000,
      visitCountYtd: 42,
      visitCountMtd: 7,
    );

    test('COB terpilih memakai angka kategori itu, bukan angka lingkup penuh',
        () {
      final out = applyCobToFallback(
        base,
        cats([
          stat('KUR', targetFullYear: 900, realisasiYtd: 300),
          stat('KBG', targetFullYear: 500, realisasiYtd: 120),
        ]),
        'KUR',
      );
      expect(out.realisasi, 300);
      expect(out.premiTarget, 900);
      expect(out.cob, 'KUR');
    });

    test('ganti COB → angka ikut ganti (inti bug yang dilaporkan)', () {
      final all = cats([
        stat('KUR', targetFullYear: 900, realisasiYtd: 300),
        stat('KBG', targetFullYear: 500, realisasiYtd: 120),
      ]);
      expect(applyCobToFallback(base, all, 'KUR').realisasi, 300);
      expect(applyCobToFallback(base, all, 'KBG').realisasi, 120);
    });

    test('realisasi MTD diambil dari bulan berjalan kategori itu', () {
      final out = applyCobToFallback(
        base,
        cats(
          [
            stat('KUR', targetFullYear: 900, realisasiYtd: 300, months: [
              DashboardCategoryMonth(
                  month: 7,
                  label: 'Jul',
                  target: 0,
                  realisasi: 50,
                  realisasiWon: 50),
              DashboardCategoryMonth(
                  month: 8,
                  label: 'Agu',
                  target: 0,
                  realisasi: 80,
                  realisasiWon: 80),
            ]),
          ],
          currentMonth: 8,
        ),
        'KUR',
      );
      expect(out.realisasiMtd, 80);
    });

    test('bulan berjalan tanpa baris → MTD 0, bukan angka lingkup penuh', () {
      final out = applyCobToFallback(
        base,
        cats([stat('KUR', targetFullYear: 900, realisasiYtd: 300)]),
        'KUR',
      );
      expect(out.realisasiMtd, 0);
    });

    // CR-09 membuat `customer-summary?cob=X` menyaring kunjungan per COB, TAPI
    // hanya di sana: jalur cadangan ini dirakit dari `/api/dashboard/categories`,
    // yang tidak membawa angka kunjungan sama sekali. Angka dasar dipakai apa
    // adanya — mengarang angka per-COB di klien akan bertabrakan dengan server.
    test('jalur cadangan: visit tetap angka dasar (tak ada sumber per-COB)', () {
      final out = applyCobToFallback(
        base,
        cats([stat('KUR', targetFullYear: 900, realisasiYtd: 300)]),
        'KUR',
      );
      expect(out.visitCountYtd, 42);
      expect(out.visitCountMtd, 7);
    });

    test('tanpa COB (Semua COB) angka dasar dipakai apa adanya', () {
      final out = applyCobToFallback(
        base,
        cats([stat('KUR', targetFullYear: 900, realisasiYtd: 300)]),
        null,
      );
      expect(out.realisasi, 55745600);
      expect(out.cob, isNull);
    });

    test('COB tak dikenal TIDAK jatuh ke kategori pertama', () {
      // `DashboardCategories.byName` sengaja tidak dipakai: jatuh ke kategori
      // pertama akan menampilkan angka KUR di bawah label COB lain.
      final out = applyCobToFallback(
        base,
        cats([stat('KUR', targetFullYear: 900, realisasiYtd: 300)]),
        'TIDAK_ADA',
      );
      expect(out.realisasi, 55745600);
    });
  });
}
