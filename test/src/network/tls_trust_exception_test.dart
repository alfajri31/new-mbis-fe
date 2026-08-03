import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/src/network/ssl_pinning.dart';

/// Yang diuji di sini adalah KONTRAK PESAN, bukan TLS-nya.
///
/// `login_screen.dart` menaruh `e.toString()` langsung ke banner error. Begitu
/// `toString()` berubah jadi uraian teknis panjang — persis bentuk bawaan
/// `HandshakeException` — banner itu tidak terbaca lagi, dan tidak ada yang
/// merah sampai seseorang kebetulan gagal login di perangkat sungguhan. Uji ini
/// mengunci pembagiannya: ringkas untuk layar, lengkap untuk log.
void main() {
  const kegagalan = TlsTrustException(
    host: 'mbis.askrindo.co.id',
    pinned: false,
    cause: 'HandshakeException: CERTIFICATE_VERIFY_FAILED: self signed certificate',
  );

  group('TlsTrustException', () {
    test('toString ringkas, menyebut host, dan menolak salahkan akun', () {
      final pesan = kegagalan.toString();

      expect(pesan, contains('mbis.askrindo.co.id'));
      expect(pesan, contains('sertifikat'));
      // Gejala paling mahal dari galat ini adalah salah tuduh: pengguna mengira
      // kata sandinya salah dan mencoba berkali-kali sampai akun terkunci.
      expect(pesan, contains('bukan masalah akun atau kata sandi'));
      // Ambang panjang, bukan angka keramat: cukup untuk memergoki kalau suatu
      // saat `details` tanpa sengaja dipakai sebagai `toString`.
      expect(pesan.length, lessThan(200));
      expect(pesan, isNot(contains('openssl')));
    });

    test('details memuat bahan diagnosa: host, perintah verifikasi, galat asli', () {
      final rinci = kegagalan.details;

      expect(rinci, contains('mbis.askrindo.co.id'));
      expect(rinci, contains('openssl s_client'));
      expect(rinci, contains('CERTIFICATE_VERIFY_FAILED'));
    });

    test('penyebab dibedakan antara host ter-pin dan tidak', () {
      const terPin = TlsTrustException(
        host: 'mbis.askrindo.co.id',
        pinned: true,
        cause: 'HandshakeException',
      );

      // Dua situasi, dua tindakan berbeda: yang ter-pin mengarah ke berkas di
      // assets/ssl yang usang, yang tidak ter-pin mengarah ke sertifikat server.
      expect(terPin.details, contains('assets/ssl'));
      expect(kegagalan.details, isNot(contains('assets/ssl')));
      expect(kegagalan.details, contains('CA sistem'));
    });
  });
}
