import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/src/app.dart';

/// Unit test penentuan peran penyelia. Ini yang memutuskan bentuk navigasi:
/// penyelia kehilangan jadwal/akses cepat pribadi, tab Tools ditukar menjadi
/// daftar manajemen RM, dan tombol "Ajukan Agen" disembunyikan.
///
/// Harus cermin dari cakupan backend (ADMIN nasional, RO/BM/KUP sub-pohon kantor).
/// Kalau keduanya berbeda, pengguna melihat menu yang lalu ditolak server.
void main() {
  group('MbisApp.isSupervisorRole', () {
    test('ADMIN, RO, BM, dan KUP dianggap penyelia', () {
      for (final role in ['ADMIN', 'RO', 'BM', 'KUP']) {
        expect(MbisApp.isSupervisorRole([role]), isTrue, reason: '$role harus penyelia');
      }
    });

    test('RM dan AGENT bukan penyelia', () {
      expect(MbisApp.isSupervisorRole(['RM']), isFalse);
      expect(MbisApp.isSupervisorRole(['AGENT']), isFalse);
    });

    test('DPJ belum termasuk daftar penyelia di sisi aplikasi', () {
      // Didokumentasikan apa adanya: supervisorRoles hanya memuat ADMIN/KUP/BM/RO.
      // Bila DPJ nanti perlu tab manajemen RM, test ini yang pertama gagal.
      expect(MbisApp.isSupervisorRole(['DPJ']), isFalse);
    });

    test('satu peran penyelia sudah cukup walau bercampur peran lain', () {
      expect(MbisApp.isSupervisorRole(['RM', 'BM']), isTrue);
      expect(MbisApp.isSupervisorRole(['AGENT', 'ADMIN']), isTrue);
    });

    test('daftar null atau kosong bukan penyelia', () {
      // Gagal ke arah aman: tanpa informasi peran, jangan tampilkan menu penyelia.
      expect(MbisApp.isSupervisorRole(null), isFalse);
      expect(MbisApp.isSupervisorRole([]), isFalse);
    });

    test('peran tak dikenal tidak memberi hak penyelia', () {
      expect(MbisApp.isSupervisorRole(['PERAN_BARU']), isFalse);
    });

    test('pencocokan peka huruf besar-kecil, sesuai peran dari backend', () {
      // Backend mengirim peran dalam huruf besar. Didokumentasikan supaya kalau
      // suatu saat kontraknya berubah menjadi huruf kecil, kegagalannya kelihatan.
      expect(MbisApp.isSupervisorRole(['bm']), isFalse);
      expect(MbisApp.isSupervisorRole(['BM']), isTrue);
    });

    test('daftar peran penyelia persis empat dan sesuai cakupan backend', () {
      expect(MbisApp.supervisorRoles, {'ADMIN', 'KUP', 'BM', 'RO'});
    });
  });
}
