import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Pelaporan crash lewat Firebase Crashlytics.
///
/// **Kenapa ada.** Build rilis Android memakai minify R8, sehingga stack trace
/// lapisan JVM teracak dan crash di lapangan tidak lagi bisa dipulihkan dari
/// laporan pengguna ("aplikasinya tiba-tiba tertutup"). Tanpa ini, kelas bug yang
/// hanya muncul di build rilis praktis tidak terlihat.
///
/// **Batas yang dijaga.** Crashlytics mengirim data ke Google, jadi isinya dibatasi
/// pada apa yang dibutuhkan untuk memperbaiki bug: jenis galat, stack trace, model
/// perangkat, dan versi OS. **Tidak pernah** NIK, NPWP, nama nasabah, nomor
/// rekening, atau isi catatan kunjungan. [setUser] sengaja hanya menerima id
/// pengguna — bukan nama atau surel — supaya laporan bisa dikaitkan ke satu akun
/// tanpa membocorkan identitasnya ke pihak ketiga.
///
/// **Kalau Firebase tidak terkonfigurasi**, seluruh kelas ini menjadi tidak aktif
/// dan aplikasi tetap berjalan — pola yang sama dipakai [PushService].
class CrashReporter {
  const CrashReporter._();

  static bool _active = false;

  /// True bila laporan benar-benar dikirim. Dipakai test dan diagnostik.
  static bool get isActive => _active;

  /// Memasang penangkap galat global. Dipanggil SETELAH Firebase diinisialisasi;
  /// bila inisialisasi gagal, pemanggilan ini dilewati oleh pemanggilnya.
  ///
  /// Web tidak didukung Crashlytics, jadi di web ia tidak dipasang sama sekali.
  static void install() {
    if (kIsWeb) return;
    final crashlytics = FirebaseCrashlytics.instance;

    // Debug build: laporan dimatikan supaya crash saat pengembangan tidak
    // mengotori dasbor produksi dan tidak menutupi crash pengguna nyata.
    unawaited(crashlytics.setCrashlyticsCollectionEnabled(kReleaseMode));

    // Galat framework Flutter (build/layout/paint).
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      crashlytics.recordFlutterFatalError(details);
    };

    // Galat asinkron di luar zona Flutter (Future yang gagal tanpa penangkap).
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };

    _active = true;
  }

  /// Mengaitkan laporan berikutnya dengan satu akun.
  ///
  /// Hanya id akun — **bukan** NIP, nama, atau surel. Id sudah cukup untuk
  /// menelusuri satu kasus lewat basis data internal, tanpa mengirim identitas
  /// pegawai ke layanan pihak ketiga.
  static Future<void> setUser(String? userId) async {
    if (!_active) return;
    await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
  }

  /// Mencatat galat yang sudah ditangani (tidak menghentikan aplikasi), mis.
  /// kegagalan sinkronisasi yang sudah ditampilkan sebagai pesan ke pengguna.
  ///
  /// [reason] harus berupa keterangan teknis singkat, bukan data pengguna.
  static Future<void> recordHandled(Object error, StackTrace? stack,
      {String? reason}) async {
    if (!_active) return;
    await FirebaseCrashlytics.instance
        .recordError(error, stack, reason: reason, fatal: false);
  }
}
