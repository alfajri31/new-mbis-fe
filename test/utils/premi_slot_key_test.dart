import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/data/premi_rates.dart';

/// Kunci slot rate default (MTR-2) adalah KONTRAK dengan backend: baris rate yang
/// diisi admin ditemukan kembali hanya kalau kunci yang dibentuk klien sama persis.
/// Kunci yang berubah bentuk tidak memunculkan error di mana pun — rate-nya sekadar
/// "hilang" dan kalkulator diam-diam kembali ke isian kosong. Test ini yang menahan
/// bentuk itu.
void main() {
  group('Kunci slot rate default', () {
    test('Asuransi Umum tanpa tier memakai penanda kosong "-"', () {
      expect(
        premiSlotKeyUmum('Erection All Risk'),
        'UMUM|Erection All Risk|-',
      );
    });

    test('Asuransi Umum dengan tier menyebut kode tier, bukan labelnya', () {
      expect(
        premiSlotKeyUmum("Contractor's All Risk", riskTier: 'HIGH'),
        "UMUM|Contractor's All Risk|HIGH",
      );
    });

    test('Surety & KBG memakai jaminan × tenor', () {
      expect(
        premiSlotKeyBond(PremiCategory.suretyBond,
            jaminan: 'Penawaran', tenor: '>0-3 bulan'),
        'SURETY|Penawaran|>0-3 bulan',
      );
      expect(
        premiSlotKeyBond(PremiCategory.kbg,
            jaminan: 'Pemeliharaan', tenor: '>9-12 bulan'),
        'KBG|Pemeliharaan|>9-12 bulan',
      );
    });

    test('Custom Bond hanya tenor; bagian jaminan tetap terisi "-"', () {
      expect(
        premiSlotKeyBond(PremiCategory.customBond, tenor: '>3-6 bulan'),
        'CUSTOM|-|>3-6 bulan',
      );
    });

    test('Kunci selalu tiga bagian — backend menolak bentuk lain', () {
      final kunci = <String>[
        premiSlotKeyUmum('Marine Cargo (ICC A)'),
        premiSlotKeyUmum("Contractor's All Risk", riskTier: 'LOW'),
        premiSlotKeyBond(PremiCategory.suretyBond,
            jaminan: 'Uang Muka', tenor: '>6-9 bulan'),
        premiSlotKeyBond(PremiCategory.customBond, tenor: '>0-3 bulan'),
      ];
      for (final k in kunci) {
        final bagian = k.split('|');
        expect(bagian, hasLength(3), reason: k);
        expect(bagian.every((b) => b.isNotEmpty), isTrue, reason: k);
      }
    });

    test('Kode kategori tidak ikut berubah saat label tampilan berubah', () {
      expect(PremiCategory.asuransiUmum.slotCode, 'UMUM');
      expect(PremiCategory.suretyBond.slotCode, 'SURETY');
      expect(PremiCategory.kbg.slotCode, 'KBG');
      expect(PremiCategory.customBond.slotCode, 'CUSTOM');
    });
  });

  group('Kode tier risiko', () {
    // CAR: tanpa tier "Normal" — 0 kriteria pun tetap Low.
    const car = RiskModel(criteria: ['a', 'b', 'c']);
    // MB Industry: 0 kriteria = Normal.
    const mb = RiskModel(criteria: ['a', 'b', 'c'], hasNormalTier: true);

    test('Kode mengikuti label yang sudah dipakai di kartu hasil', () {
      expect(car.tierCode(0), 'LOW');
      expect(car.tierLabel(0), 'Low Risk');
      expect(car.tierCode(1), 'LOW');
      expect(car.tierCode(2), 'HIGH');
      expect(car.tierLabel(2), 'High Risk');
      expect(car.tierCode(3), 'HIGH');

      expect(mb.tierCode(0), 'NORMAL');
      expect(mb.tierLabel(0), 'Normal');
      expect(mb.tierCode(1), 'LOW');
      expect(mb.tierCode(2), 'HIGH');
    });

    test('Tier yang berbeda menghasilkan slot yang berbeda', () {
      final high = premiSlotKeyUmum('Machinery Breakdown (Industry)',
          riskTier: mb.tierCode(2));
      final normal = premiSlotKeyUmum('Machinery Breakdown (Industry)',
          riskTier: mb.tierCode(0));
      expect(high, isNot(normal));
    });
  });
}
