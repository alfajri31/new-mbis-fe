/// Versi aplikasi yang ditampilkan ke pengguna.
///
/// **Kenapa berkas ini ada.** Nomor versi sebelumnya di-hardcode DUA kali — di
/// `profil_screen.dart` dan `agent_profil_screen.dart` — dan sudah menyimpang dari
/// `pubspec.yaml` (`version: 1.0.0+1` sementara layar menampilkan `v2.1.0`). Nomor
/// versi adalah hal pertama yang ditanyakan saat menerima laporan galat, jadi angka
/// yang salah membuat penelusuran berangkat dari pijakan yang keliru.
///
/// **Kenapa masih konstanta, bukan dibaca saat runtime.** Membaca versi asli dari
/// paket menuntut `package_info_plus`, yang memakai platform channel — widget test
/// yang menyentuh kedua layar profil harus ikut memasangkan mock, dan menambah
/// dependensi tepat sebelum unggahan pertama ke Play menambah risiko tanpa imbalan
/// setara. Sebagai gantinya konstanta ini dijaga
/// `test/src/config/app_version_drift_test.dart`, yang membaca `pubspec.yaml` dan
/// menolak lulus bila keduanya berbeda. Pola yang sama dengan naskah kebijakan:
/// satu sumber, penyimpangan dijadikan gagal-berisik.
///
/// **Cara menaikkan versi:** ubah `version:` di `pubspec.yaml`, lalu samakan
/// [versiAplikasi] di sini. Test drift akan menyebut nilai yang benar bila lupa.
library;

/// Bagian `versionName` dari `pubspec.yaml` (sebelum tanda `+`).
///
/// Harus sama persis dengan `version:` di `pubspec.yaml`. Angka setelah `+`
/// (`versionCode`) sengaja TIDAK ikut ditampilkan: itu nomor internal Play yang
/// tidak berarti bagi pengguna.
///
/// Nilainya mengikuti `pubspec.yaml`, BUKAN sebaliknya. Layar profil sempat
/// meng-hardcode `v2.1.0` sementara berkas build bilang `1.0.0` — arah
/// penyelesaiannya adalah tampilan mengikuti yang benar-benar dibangun, karena
/// itulah angka yang muncul di Play Console dan di laporan crash.
const String versiAplikasi = '1.0.0';

/// Baris versi utuh di kaki layar profil — dipakai layar profil pegawai maupun
/// Agen supaya keduanya mustahil berbeda bunyi.
const String labelVersiAplikasi =
    'M-BIS v$versiAplikasi • PT Askrindo (Persero)';
