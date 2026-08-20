import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/src/app.dart';
import 'package:mbis/src/auth/roles.dart';

/// Unit test penentuan peran penyelia. Ini yang memutuskan bentuk navigasi:
/// penyelia kehilangan jadwal/akses cepat pribadi, tab Tools ditukar menjadi
/// daftar manajemen RM, dan tombol "Ajukan Agen" disembunyikan.
///
/// Harus cermin dari cakupan backend (ADMIN & divisi kantor pusat nasional,
/// RO/BM/KUP sub-pohon kantor). Kalau keduanya berbeda, pengguna melihat menu yang
/// lalu ditolak server.
void main() {
  group('MbisApp.isSupervisorRole', () {
    test('ADMIN, RO, BM, dan KUP dianggap penyelia', () {
      for (final role in ['ADMIN', 'RO', 'BM', 'KUP']) {
        expect(MbisApp.isSupervisorRole([role]), isTrue, reason: '$role harus penyelia');
      }
    });

    test('divisi kantor pusat dianggap penyelia', () {
      // Mereka tidak bekerja di lapangan: tak punya portofolio nasabah sendiri,
      // jadi jadwal & akses cepat pribadi tidak berlaku. Hak TULIS-nya digerbangi
      // terpisah lewat Roles.curatorDivisions / Roles.agentHqManagers.
      for (final role in Roles.headOfficeDivisions) {
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

    test('daftar peran penyelia sesuai cakupan backend', () {
      expect(MbisApp.supervisorRoles, {
        'ADMIN', 'KUP', 'BM', 'RO',
        'DIV_PRODUCT', 'DIV_SOE', 'DIV_RETAIL', 'DIV_AGEN', 'DIV_AUDIT', 'DIV_PROGRAM',
      });
    });
  });

  /// Nama peran divisi harus sama persis dengan enum `RoleName` di backend dan
  /// dengan CHECK constraint `roles_name_check` (migrasi V50). Salah ketik di sini
  /// tidak memunculkan error apa pun — peran tak dikenal diam-diam jatuh ke cakupan
  /// OWNER, dan seluruh layar penggunanya kosong.
  group('Roles — kontrak nama peran divisi', () {
    test('enam divisi kantor pusat, ejaan persis seperti backend', () {
      expect(Roles.headOfficeDivisions, {
        'DIV_PRODUCT', 'DIV_SOE', 'DIV_RETAIL', 'DIV_AGEN', 'DIV_AUDIT', 'DIV_PROGRAM',
      });
    });

    test('divisi kurator tidak memuat peran yang hanya boleh melihat', () {
      expect(Roles.curatorDivisions, {'DIV_PRODUCT', 'DIV_SOE', 'DIV_RETAIL', 'DIV_AGEN'});
      expect(Roles.curatorDivisions, isNot(contains(Roles.divAudit)));
      expect(Roles.curatorDivisions, isNot(contains(Roles.divProgram)));
    });

    test('penulis data pipeline mencerminkan gerbang server', () {
      // PUT /api/pipelines/{id} → hasAnyRole('RM','BM','RO','KUP'); ADMIN via hierarki.
      expect(Roles.pipelineWriters, {'ADMIN', 'RM', 'BM', 'RO', 'KUP'});
      // Tak satu pun divisi boleh menulis pipeline — termasuk divisi kurator.
      for (final role in Roles.headOfficeDivisions) {
        expect(Roles.hasAny([role], Roles.pipelineWriters), isFalse,
            reason: '$role tidak boleh mengubah pipeline');
      }
    });

    test('pekerja lapangan pipeline lebih sempit daripada penulis datanya', () {
      // Stage, jadwal, kunjungan, dokumen → hasRole('RM'); RoleHierarchy hanya
      // menaikkan ADMIN & KUP ke atas RM, jadi BM/RO TIDAK ikut.
      expect(Roles.pipelineFieldWorkers, {'ADMIN', 'RM', 'KUP'});
      for (final role in ['BM', 'RO']) {
        expect(Roles.hasAny([role], Roles.pipelineWriters), isTrue,
            reason: '$role boleh mengoreksi data pipeline');
        expect(Roles.hasAny([role], Roles.pipelineFieldWorkers), isFalse,
            reason: '$role tidak boleh mencatat pekerjaan lapangan');
      }
      // Himpunan sempit harus benar-benar bagian dari himpunan luas.
      expect(Roles.pipelineWriters.containsAll(Roles.pipelineFieldWorkers), isTrue);
    });

    test('pengelola agen kantor pusat hanya ADMIN & DIV_AGEN', () {
      expect(Roles.agentHqManagers, {'ADMIN', 'DIV_AGEN'});
      expect(Roles.hasAny(['RM'], Roles.agentHqManagers), isFalse);
      expect(Roles.hasAny(['BM'], Roles.agentHqManagers), isFalse);
    });

    test('hasAny aman untuk daftar null & kosong', () {
      expect(Roles.hasAny(null, Roles.curatorDivisions), isFalse);
      expect(Roles.hasAny([], Roles.curatorDivisions), isFalse);
    });
  });
}
