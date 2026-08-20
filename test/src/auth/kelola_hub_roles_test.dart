import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/src/auth/roles.dart';

/// Regresi UTC-16, ditemukan saat SIT 20 Agustus 2026.
///
/// Tab "Kelola" memang disembunyikan dari RM, tetapi rutenya tidak digerbangi.
/// Seorang RM masih bisa mengetik `/kelola/export-data` dan mendapat halaman
/// yang tergambar lengkap padahal setiap tombolnya berujung 403 tanpa pesan —
/// terbaca sebagai aplikasi rusak, bukan sebagai penolakan akses.
///
/// Daftar peran di sini kini dipakai bersama oleh penampilan tab dan gerbang
/// rute, jadi keduanya tidak bisa lagi menyimpang.
void main() {
  group('Roles.kelolaHubRoles', () {
    test('RM biasa tidak boleh membuka hub Kelola', () {
      expect(Roles.hasAny(['RM'], Roles.kelolaHubRoles), isFalse);
    });

    test('AGENT tidak boleh', () {
      expect(Roles.hasAny(['AGENT'], Roles.kelolaHubRoles), isFalse);
    });

    test('pimpinan kantor dan admin boleh', () {
      for (final peran in ['ADMIN', 'BM', 'RO', 'KUP']) {
        expect(Roles.hasAny([peran], Roles.kelolaHubRoles), isTrue,
            reason: '$peran seharusnya boleh membuka hub Kelola');
      }
    });

    test('divisi kurator boleh, divisi yang hanya melihat tidak', () {
      for (final peran in Roles.curatorDivisions) {
        expect(Roles.hasAny([peran], Roles.kelolaHubRoles), isTrue,
            reason: '$peran mengelola daftar master, jadi butuh hub Kelola');
      }
      // DIV_AUDIT & DIV_PROGRAM hanya melihat; hub Kelola bagi mereka isinya
      // pintu yang seluruhnya 403.
      expect(Roles.hasAny([Roles.divAudit], Roles.kelolaHubRoles), isFalse);
      expect(Roles.hasAny([Roles.divProgram], Roles.kelolaHubRoles), isFalse);
    });

    test('peran ganda cukup salah satu yang berhak', () {
      expect(Roles.hasAny(['RM', 'BM'], Roles.kelolaHubRoles), isTrue);
    });

    test('daftar peran kosong atau null ditolak', () {
      expect(Roles.hasAny(const [], Roles.kelolaHubRoles), isFalse);
      expect(Roles.hasAny(null, Roles.kelolaHubRoles), isFalse);
    });
  });
}
