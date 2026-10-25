import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/presentation/providers/bumn_provider.dart';
import 'package:mbis/src/bumn/bumn_repository.dart';

void main() {
  group('BumnFilter Tests', () {
    test('BumnFilter initial state is inactive with 0 count', () {
      const filter = BumnFilter();
      expect(filter.isActive, false);
      expect(filter.count, 0);
    });

    test('BumnFilter count increments with active filters', () {
      final filter = const BumnFilter().copyWith(
        wil: 'Kantor Wilayah 1',
        cab: 'Padang',
        stage: 'P3',
        kat: 'Induk',
      );
      expect(filter.isActive, true);
      expect(filter.count, 4);
    });

    test('BumnFilter equality and copyWith works properly', () {
      const f1 = BumnFilter(wil: 'Kantor Wilayah 1', cab: 'Padang');
      final f2 = const BumnFilter().copyWith(wil: 'Kantor Wilayah 1', cab: 'Padang');
      expect(f1, equals(f2));

      final f3 = f1.copyWith(rm: 'Siti Rahmawati');
      expect(f3.rm, 'Siti Rahmawati');
      expect(f3.count, 3);
    });

    test('BumnLink supports kanwil, kc, and rm fields', () {
      const link = BumnLink(
        pipelineId: 'bp1',
        stage: 'P3',
        premi: 250000000,
        customer: BumnCustomer('c1', 'Bank Mandiri'),
        kanwil: 'Kantor Wilayah 2',
        kc: 'Jakarta Selatan',
        rm: 'Siti Rahmawati',
      );

      expect(link.kanwil, 'Kantor Wilayah 2');
      expect(link.kc, 'Jakarta Selatan');
      expect(link.rm, 'Siti Rahmawati');
      expect(link.stage, 'P3');
    });
  });
}
