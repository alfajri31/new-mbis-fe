@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mbis/src/config/app_version.dart';

/// Menjaga versi yang DITAMPILKAN tetap sama dengan versi yang DIBANGUN.
///
/// **Kenapa test ini ada.** Nomor versi sempat di-hardcode dua kali di layar
/// profil dan menyimpang dari `pubspec.yaml`: berkas build bilang `1.0.0+1`,
/// layar bilang `v2.1.0`. Penyimpangan seperti ini gagal dengan sunyi — aplikasi
/// tetap jalan, `flutter analyze` tetap bersih, dan yang salah baru ketahuan saat
/// menerima laporan galat dari pengguna yang menyebutkan versi yang tidak pernah
/// benar-benar dirilis.
///
/// Test ini membaca `pubspec.yaml` langsung, bukan konstanta lain, supaya sumber
/// kebenarannya tetap satu: berkas yang dipakai Gradle/Xcode saat membangun.
void main() {
  group('versi aplikasi', () {
    late String versionNamePubspec;

    setUpAll(() {
      final pubspec = File('pubspec.yaml');
      expect(pubspec.existsSync(), isTrue,
          reason: 'Test harus dijalankan dari akar repo; sekarang di '
              '${Directory.current.absolute.path}');

      // Diambil dengan regex, bukan paket YAML: satu baris sederhana tidak
      // sepadan dengan menambah dependensi ke aplikasi rilis.
      final baris = pubspec
          .readAsLinesSync()
          .firstWhere((l) => l.startsWith('version:'), orElse: () => '');
      expect(baris, isNotEmpty,
          reason: 'Tidak ada baris "version:" di pubspec.yaml.');

      // `2.1.0+1` -> `2.1.0`. Bagian setelah `+` adalah versionCode, nomor
      // internal Play yang memang tidak ditampilkan ke pengguna.
      versionNamePubspec = baris.split(':')[1].trim().split('+').first;
    });

    test('versiAplikasi sama dengan version: di pubspec.yaml', () {
      expect(
        versiAplikasi,
        versionNamePubspec,
        reason: 'Versi yang ditampilkan ($versiAplikasi) tidak sama dengan yang '
            'dibangun ($versionNamePubspec).\n'
            'Perbaiki dengan menyamakan `versiAplikasi` di '
            'lib/src/config/app_version.dart menjadi "$versionNamePubspec", '
            'atau naikkan `version:` di pubspec.yaml.',
      );
    });

    test('label versi memuat nomor versi dan nama perusahaan', () {
      // Bukan sekadar "keduanya sama": kalau labelnya berhenti menyebut nomor
      // versi, test di atas tetap hijau sementara layar profil kehilangan
      // informasi yang justru jadi alasan baris itu ada.
      expect(labelVersiAplikasi, contains(versionNamePubspec));
      expect(labelVersiAplikasi, contains('M-BIS'));
      expect(labelVersiAplikasi, contains('PT Askrindo (Persero)'));
    });

    test('versionName berbentuk semver tiga bagian', () {
      // Play menolak versionName kosong, dan format tiga bagian yang dipakai
      // selama ini juga yang tertulis di dokumen rilis.
      expect(versionNamePubspec, matches(RegExp(r'^\d+\.\d+\.\d+$')),
          reason: 'versionName "$versionNamePubspec" bukan bentuk X.Y.Z.');
    });
  });
}
