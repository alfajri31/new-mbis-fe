import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/presentation/providers/customer_list_provider.dart';

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
}
