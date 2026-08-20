import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/utils/bank_komisi.dart';

/// Mengunci daftar bank pencairan komisi agen dan perlakuan terhadap nilai lama.
///
/// Yang diuji bukan isi daftarnya semata, tapi syarat yang membuat dropdown-nya
/// tidak meledak: `DropdownButtonFormField` melempar assertion bila nilai
/// terpilih tidak ada di antara item-nya, dan data lama berisi nama bank yang
/// dulu diketik bebas.
void main() {
  group('BankKomisi', () {
    test('memuat bank yang ditetapkan unit bisnis, urut seperti daftarnya', () {
      expect(BankKomisi.values.first, BankKomisi.bca);
      expect(BankKomisi.values.last, BankKomisi.seabank);
      expect(BankKomisi.values, hasLength(13));
      expect(labelBankKomisi.first, 'BANK BCA');
      expect(labelBankKomisi.last, 'SEABANK');
    });

    test('label unik — satu nilai ganda membuat dropdown melempar', () {
      expect(labelBankKomisi.toSet(), hasLength(labelBankKomisi.length));
    });

    test('memuat bank yang tidak ada di master /api/banks', () {
      // Justru dua nama inilah alasan himpunan ini tidak diambil dari master:
      // SEABANK belum ada di sana, dan BSI masih tercatat sebagai nama lamanya.
      expect(BankKomisi.seabank.label, 'SEABANK');
      expect(BankKomisi.syariahIndonesia.label, 'BANK SYARIAH INDONESIA');
    });

    test('label adalah nilai yang disimpan, jadi tidak boleh berubah diam-diam', () {
      // Label mendarat di agents.bank_name; menggantinya = mengubah data.
      expect(BankKomisi.bpdBali.label, 'BPD BALI');
      expect(BankKomisi.cimbNiaga.label, 'CIMB NIAGA');
      expect(BankKomisi.hanaBank.label, 'HANA BANK');
    });
  });

  group('BankKomisi.dariLabel', () {
    test('mengenali label yang sama persis', () {
      expect(BankKomisi.dariLabel('BANK MANDIRI'), BankKomisi.mandiri);
      expect(BankKomisi.dariLabel('  SEABANK  '), BankKomisi.seabank);
    });

    test('null untuk kosong maupun nilai di luar himpunan', () {
      expect(BankKomisi.dariLabel(null), isNull);
      expect(BankKomisi.dariLabel(''), isNull);
      expect(BankKomisi.dariLabel('Bank Permata'), isNull);
      // Sengaja peka huruf: nilainya dipakai apa adanya sebagai data.
      expect(BankKomisi.dariLabel('bank mandiri'), isNull);
    });
  });

  group('opsiBankKomisi', () {
    test('kosong atau null -> daftar apa adanya', () {
      expect(opsiBankKomisi(null), labelBankKomisi);
      expect(opsiBankKomisi(''), labelBankKomisi);
      expect(opsiBankKomisi('   '), labelBankKomisi);
    });

    test('nilai yang sudah ada di daftar tidak digandakan', () {
      final opsi = opsiBankKomisi('BANK MANDIRI');

      expect(opsi, labelBankKomisi);
      expect(opsi.where((b) => b == 'BANK MANDIRI'), hasLength(1));
    });

    test('nilai lama di luar daftar tetap ditampilkan, di posisi pertama', () {
      // Membuangnya diam-diam membuat RM mengira rekening belum pernah diisi.
      final opsi = opsiBankKomisi('Bank Permata');

      expect(opsi.first, 'Bank Permata');
      expect(opsi, hasLength(labelBankKomisi.length + 1));
      expect(opsi, containsAll(labelBankKomisi));
    });

    test('nilai lama tetap unik agar dropdown tidak melempar assertion', () {
      final opsi = opsiBankKomisi('bca');

      expect(opsi.toSet(), hasLength(opsi.length));
    });
  });
}
