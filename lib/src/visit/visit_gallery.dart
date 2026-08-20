import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';

/// Hasil percobaan menyimpan foto kunjungan ke galeri perangkat — CR-12 (MTR-7).
///
/// Sengaja mengembalikan hasil, bukan melempar: menyimpan ke galeri adalah SALINAN
/// kenyamanan. Foto yang sesungguhnya dipakai sebagai bukti sudah ikut terunggah
/// bersama kunjungan, jadi galeri yang gagal tidak boleh menggagalkan pencatatan
/// kunjungan RM di lapangan.
enum GallerySaveStatus {
  saved,

  /// Platform tanpa galeri (web) — tidak dianggap kegagalan, cukup dilewati diam-diam.
  unsupported,

  /// Izin akses galeri ditolak pengguna.
  permissionDenied,

  /// Gagal karena sebab lain (penyimpanan penuh, kesalahan OS).
  failed,
}

/// Menyimpan foto kunjungan ke galeri/album perangkat.
class VisitGallery {
  const VisitGallery._();

  /// Nama album tempat foto kunjungan dikumpulkan, supaya tidak tercecer di antara
  /// foto pribadi RM.
  static const String albumName = 'M-BIS Kunjungan';

  /// Simpan [bytes] ke galeri. Tidak pernah melempar; lihat [GallerySaveStatus].
  ///
  /// Catatan platform: paket `gal` tidak punya implementasi web, jadi pemanggilan
  /// dijaga [kIsWeb] — tanpa itu versi web aplikasi ini akan gagal saat berjalan,
  /// bukan saat dibangun, sehingga baru ketahuan di tangan pengguna.
  static Future<GallerySaveStatus> save(Uint8List bytes, {String name = 'kunjungan'}) async {
    if (kIsWeb) {
      return GallerySaveStatus.unsupported;
    }
    try {
      // Di Android 10+ (scoped storage) ini tidak meminta izin apa pun; permintaan
      // izin hanya muncul di Android 7-9 dan di iOS.
      if (!await Gal.hasAccess(toAlbum: true)) {
        if (!await Gal.requestAccess(toAlbum: true)) {
          return GallerySaveStatus.permissionDenied;
        }
      }
      await Gal.putImageBytes(bytes, album: albumName, name: name);
      return GallerySaveStatus.saved;
    } on GalException catch (e) {
      return e.type == GalExceptionType.accessDenied
          ? GallerySaveStatus.permissionDenied
          : GallerySaveStatus.failed;
    } catch (_) {
      return GallerySaveStatus.failed;
    }
  }

  /// Pesan berbahasa Indonesia untuk ditampilkan saat penyimpanan tidak berhasil,
  /// atau null bila tidak ada yang perlu diberitahukan ke pengguna.
  static String? messageFor(GallerySaveStatus status) {
    switch (status) {
      case GallerySaveStatus.saved:
      case GallerySaveStatus.unsupported:
        return null;
      case GallerySaveStatus.permissionDenied:
        return 'Izin galeri ditolak, jadi salinan foto tidak disimpan di perangkat. '
            'Kunjungan tetap tersimpan.';
      case GallerySaveStatus.failed:
        return 'Salinan foto gagal disimpan ke galeri perangkat. '
            'Kunjungan tetap tersimpan.';
    }
  }
}
