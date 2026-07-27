import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/features/customer/domain/entities/customer.dart';

/// Unit test serialisasi entity nasabah. Lapisan `domain` murni — tanpa Flutter,
/// tanpa HTTP — jadi test ini paling murah dijalankan.
///
/// Nilainya: kontrak API bisa berubah diam-diam (field hilang, tipe angka berubah
/// dari int ke double). Test ini mengunci perilaku default yang sudah disepakati
/// sehingga perubahan seperti itu ketahuan, bukan muncul sebagai layar kosong.
void main() {
  group('Customer.fromJson', () {
    test('memetakan seluruh field saat JSON lengkap', () {
      final customer = Customer.fromJson({
        'id': 'CUST-1',
        'name': 'PT Maju Jaya',
        'entityCategory': 'BUMN',
        'state': 'ACTIVE',
        'isBlacklisted': true,
        'pipelineCount': 7,
      });

      expect(customer.id, 'CUST-1');
      expect(customer.name, 'PT Maju Jaya');
      expect(customer.entityCategory, 'BUMN');
      expect(customer.state, 'ACTIVE');
      expect(customer.isBlacklisted, isTrue);
      expect(customer.pipelineCount, 7);
    });

    test('JSON kosong menghasilkan nilai default yang aman, bukan exception', () {
      // Backend boleh menghilangkan field opsional; UI tidak boleh ikut runtuh.
      final customer = Customer.fromJson(const {});

      expect(customer.id, '');
      expect(customer.name, '');
      expect(customer.entityCategory, isNull);
      expect(customer.state, isNull);
      expect(customer.isBlacklisted, isFalse);
      expect(customer.pipelineCount, 0);
    });

    test('field null diperlakukan sama dengan tidak ada', () {
      final customer = Customer.fromJson(const {
        'id': null,
        'name': null,
        'isBlacklisted': null,
        'pipelineCount': null,
      });

      expect(customer.id, '');
      expect(customer.name, '');
      expect(customer.isBlacklisted, isFalse);
      expect(customer.pipelineCount, 0);
    });

    test('pipelineCount menerima angka desimal dari JSON dan dibulatkan ke int', () {
      // JSON tidak membedakan int dan double; sebagian serializer mengirim 7.0.
      final customer = Customer.fromJson(const {'pipelineCount': 7.0});

      expect(customer.pipelineCount, 7);
      expect(customer.pipelineCount, isA<int>());
    });

    test('nasabah tidak dianggap blacklist kecuali dinyatakan tegas', () {
      // Default harus aman: ketiadaan informasi bukan berarti bersih maupun kotor,
      // tetapi penanda peringatan tidak boleh menyala tanpa dasar.
      expect(Customer.fromJson(const {}).isBlacklisted, isFalse);
      expect(Customer.fromJson(const {'isBlacklisted': false}).isBlacklisted, isFalse);
      expect(Customer.fromJson(const {'isBlacklisted': true}).isBlacklisted, isTrue);
    });

    test('field tak dikenal diabaikan sehingga kontrak boleh bertambah', () {
      final customer = Customer.fromJson(const {
        'id': 'CUST-2',
        'name': 'CV Sinar',
        'fieldBaruDariBackend': 'apa pun',
      });

      expect(customer.id, 'CUST-2');
      expect(customer.name, 'CV Sinar');
    });
  });
}
