import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/features/quotation_slip/widgets/pertanggungan/repositories/pekerjaan_repository.dart';

void main() {
  group('PekerjaanRepository & PekerjaanController Tests', () {
    test('MockPekerjaanRepository mengembalikan daftar mock sesuai kontrak', () async {
      const mockItems = [
        'Karyawan',
        'Wiraswasta',
        'PNS / BUMN',
        'Ibu Rumah Tangga',
        'Sopir',
        'Pekerja Tambang',
      ];
      const repo = MockPekerjaanRepository(mockItems);

      final result = await repo.list();
      expect(result, equals(mockItems));
    });

    test('PekerjaanController memuat data via repository (positive case & loading state)', () async {
      var callCount = 0;
      final testRepo = _CountingMockRepository(() {
        callCount++;
        return ['Pekerjaan $callCount'];
      });

      final controller = PekerjaanController(repository: testRepo);

      expect(callCount, equals(0));
      expect(controller.items, isEmpty);
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);

      final future = controller.loadPekerjaan();
      expect(controller.isLoading, isTrue);

      await future;
      expect(callCount, equals(1));
      expect(controller.items, equals(['Pekerjaan 1']));
      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isFalse);

      // Panggilan kedua selalu get langsung ke repository/API (tanpa cache)
      await controller.loadPekerjaan();
      expect(callCount, equals(2));
      expect(controller.items, equals(['Pekerjaan 2']));
    });

    test('PekerjaanController menangani negative case (error / kegagalan API)', () async {
      final errorRepo = MockPekerjaanRepository(const [], true);
      final controller = PekerjaanController(repository: errorRepo);

      expect(controller.hasError, isFalse);

      await controller.loadPekerjaan();

      expect(controller.isLoading, isFalse);
      expect(controller.hasError, isTrue);
      expect(controller.error, contains('Mock network error'));
      expect(controller.items, isEmpty);
    });

    test('PekerjaanController dapat pulih saat retry setelah error', () async {
      var shouldFail = true;
      final retryRepo = _CountingMockRepository(() {
        if (shouldFail) {
          throw Exception('Koneksi terputus');
        }
        return ['Karyawan', 'Wiraswasta'];
      });

      final controller = PekerjaanController(repository: retryRepo);

      // Panggilan 1: Gagal (negative case)
      await controller.loadPekerjaan();
      expect(controller.hasError, isTrue);
      expect(controller.items, isEmpty);

      // Perbaiki koneksi dan retry
      shouldFail = false;
      await controller.refresh();

      expect(controller.hasError, isFalse);
      expect(controller.items, equals(['Karyawan', 'Wiraswasta']));
    });
  });
}

class _CountingMockRepository implements PekerjaanRepository {
  final List<String> Function() _onList;

  _CountingMockRepository(this._onList);

  @override
  Future<List<String>> list() async => _onList();
}
