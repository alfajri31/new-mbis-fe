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
}
