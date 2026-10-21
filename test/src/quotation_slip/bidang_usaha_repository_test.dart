import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/features/quotation_slip/widgets/pertanggungan/repositories/bidang_usaha_repository.dart';

void main() {
  group('BidangUsahaRepository & BidangUsahaController Tests', () {
    test('MockBidangUsahaRepository mengembalikan daftar mock sesuai kontrak', () async {
      const mockItems = ['Pertanian', 'Perikanan', 'Teknologi'];
      const repo = MockBidangUsahaRepository(mockItems);

      final result = await repo.list();
      expect(result, equals(mockItems));
    });

    test('BidangUsahaController memuat data via repository (positive case & loading state)', () async {
      var callCount = 0;
      final testRepo = _CountingMockRepository(() {
        callCount++;
        return ['Item $callCount'];
      });

      final controller = BidangUsahaController(repository: testRepo);

      expect(callCount, equals(0));
      expect(controller.items, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);

      // Panggilan loadBidangUsaha
      final future = controller.loadBidangUsaha();
      expect(controller.isLoading, isTrue);

      await future;
      expect(callCount, equals(1));
      expect(controller.items, equals(['Item 1']));
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);

      // Panggilan kedua selalu get langsung ke repository/API (tanpa cache)
      await controller.loadBidangUsaha();
      expect(callCount, equals(2));
      expect(controller.items, equals(['Item 2']));
    });

    test('BidangUsahaController menangani negative case (error / kegagalan API)', () async {
      final errorRepo = MockBidangUsahaRepository(const [], true);
      final controller = BidangUsahaController(repository: errorRepo);

      expect(controller.hasError, isFalse);

      await controller.loadBidangUsaha();

      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isTrue);
      expect(controller.error, contains('Mock network error'));
      expect(controller.items, isEmpty);
    });

    test('BidangUsahaController dapat pulih saat retry setelah error', () async {
      var shouldFail = true;
      final retryRepo = _CountingMockRepository(() {
        if (shouldFail) {
          throw Exception('Koneksi terputus');
        }
        return ['Manufaktur', 'Perdagangan'];
      });

      final controller = BidangUsahaController(repository: retryRepo);

      // Panggilan 1: Gagal (negative case)
      await controller.loadBidangUsaha();
      expect(controller.hasError, isTrue);
      expect(controller.items, isEmpty);

      // Perbaiki koneksi dan retry
      shouldFail = false;
      await controller.refresh();

      expect(controller.hasError, isFalse);
      expect(controller.items, equals(['Manufaktur', 'Perdagangan']));
    });
  });
}

class _CountingMockRepository implements BidangUsahaRepository {
  final List<String> Function() _onList;

  _CountingMockRepository(this._onList);

  @override
  Future<List<String>> list() async => _onList();
}
