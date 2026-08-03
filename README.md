# MBIS Frontend

![Flutter](https://img.shields.io/badge/Flutter-3.44.2-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.12.2-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey)
![State](https://img.shields.io/badge/State-Riverpod-4B6BFB)

Aplikasi klien **M-BIS** (Marketing Business Intelligence System) PT Asuransi Kredit Indonesia.
Satu basis kode Flutter yang dikompilasi ke tiga target: Android, iOS, dan Web.

| Kanal | Pengguna |
|---|---|
| Mobile | Relationship Manager dan Agen di lapangan |
| Web | Peran back-office — RO, BM, KUP, operasional, dan administrator |

---

## Daftar Isi

1. [Ikhtisar](#1-ikhtisar)
2. [Teknologi](#2-teknologi)
3. [Prasyarat](#3-prasyarat)
4. [Menjalankan Aplikasi](#4-menjalankan-aplikasi)
5. [Konfigurasi](#5-konfigurasi)
6. [Flavor Android](#6-flavor-android)
7. [Pengujian](#7-pengujian)
8. [Build Rilis](#8-build-rilis)
9. [Struktur Proyek](#9-struktur-proyek)
10. [Keamanan Transport](#10-keamanan-transport)
11. [Catatan Performa](#11-catatan-performa)
12. [Pemecahan Masalah](#12-pemecahan-masalah)

---

## 1. Ikhtisar

Aplikasi ini mengonsumsi REST API dari layanan backend M-BIS dan menyajikan fungsi manajemen
nasabah, pipeline penjualan, kunjungan, keagenan, komisi, premi, serta dasbor kinerja sesuai peran
pengguna.

Repositori ini sebelumnya bernama `MBIS-App`. Rujukan pada dokumentasi lama yang menggunakan nama
tersebut mengacu pada repositori ini.

---

## 2. Teknologi

| Komponen | Teknologi |
|---|---|
| Framework | Flutter 3.44.2 (Dart 3.12.2) |
| Manajemen state | Riverpod (`flutter_riverpod`) |
| Navigasi | `go_router` |
| Penyimpanan token | `flutter_secure_storage` |
| Klien HTTP | `http` |
| Notifikasi | Firebase Cloud Messaging — Android; iOS belum dikonfigurasi |
| Peta | `flutter_map` dan `latlong2` — implementasi Dart murni, tanpa kunci API |
| Identitas aplikasi | `com.askrindo.mbis.mobile` dan `com.askrindo.mbis.mobile.staging` |

---

## 3. Prasyarat

| Kebutuhan | Keterangan |
|---|---|
| Flutter 3.44.2 | Tersedia pada `PATH` |
| Backend M-BIS | Berjalan pada `localhost:8080` |
| Android SDK Platform Tools | Diperlukan untuk pengujian pada perangkat fisik |
| Xcode dan macOS | Diperlukan khusus untuk build iOS |

---

## 4. Menjalankan Aplikasi

### 4.1 Web

```bash
flutter run -d chrome \
  --dart-define=API_URL=http://localhost:8080 \
  --dart-define=APP_ENV=dev
```

### 4.2 Perangkat Android fisik

Perangkat tidak dapat menjangkau `localhost` milik komputer pengembang, sehingga diperlukan
penerusan port melalui `adb`:

```bash
adb reverse tcp:8080 tcp:8080

flutter run -d <device-id> --flavor staging \
  --dart-define=API_URL=http://localhost:8080 \
  --dart-define=APP_ENV=dev
```

### 4.3 Emulator Android

Emulator memetakan host melalui alamat `10.0.2.2`:

```bash
./scripts/run-dev.sh
```

### 4.4 Kredensial pengembangan

| Identifier | Kata sandi |
|---|---|
| `ADMIN` | `Admin1234!` |
| Akun demo lainnya | `Test1234!` |

Autentikasi menggunakan NIP dan bersifat *case-sensitive*.

---

## 5. Konfigurasi

Seluruh konfigurasi lingkungan diteruskan melalui `--dart-define` dan dibaca oleh `AppConfig`
(`lib/src/config/app_config.dart`). Tidak terdapat nilai yang ditanam langsung pada kode.

| Variabel | Nilai bawaan | Keterangan |
|---|---|---|
| `APP_ENV` | `dev` | Lingkungan aktif: `dev`, `staging`, atau `prod` |
| `API_URL` | Bergantung platform | Base URL layanan backend |
| `PRIVACY_POLICY_URL` | Kosong | Wajib diisi untuk build rilis produksi |
| `ACCOUNT_DELETION_URL` | Kosong | Tautan halaman penghapusan akun |
| `PRIVACY_CONTACT_EMAIL` | Kosong | Opsional |
| `ENTRA_TENANT_ID` | Kosong | SSO Microsoft Entra ID |
| `ENTRA_CLIENT_ID` | Kosong | SSO Microsoft Entra ID |

Apabila `API_URL` tidak ditetapkan, nilai ditentukan sebagai berikut:

- **Web** — string kosong (*same-origin*), karena Nginx meneruskan permintaan `/api`
- **Mobile** — `http://10.0.2.2:8080`, alamat host dari emulator Android

`API_URL` boleh memuat **path**, bukan hanya host. Produksi menempatkan backend di bawah
prefix `/v2` (`https://mbis.askrindo.co.id/v2`) karena domain tersebut dibagi beberapa
aplikasi. Garis miring di akhir dibuang otomatis, dan seluruh kode fitur menambahkan
`/api/...` di belakangnya.

Web produksi **tidak** lagi mengandalkan *same-origin*: bundel dilayani terpisah dari API,
sehingga `API_URL` wajib diisi saat membangun image web
(`docker build --build-arg API_URL=...`) dan backend wajib mengizinkan origin web pada
`MBIS_CORS_ALLOWED_ORIGINS`. Rinciannya di [`docs/MIGRASI-DOMAIN-PROD-V2.md`](docs/MIGRASI-DOMAIN-PROD-V2.md).
Staging tetap *same-origin* dan tidak berubah.

Variabel SSO yang dikosongkan menyebabkan opsi autentikasi Microsoft tidak ditampilkan.

---

## 6. Flavor Android

| Flavor | Application ID | Peruntukan |
|---|---|---|
| `prod` | `com.askrindo.mbis.mobile` | Distribusi Google Play |
| `staging` | `com.askrindo.mbis.mobile.staging` | Pengujian; dapat terpasang berdampingan dengan versi produksi |

Parameter `--flavor` wajib disertakan pada setiap perintah build maupun run untuk target Android.

> **Status saat ini.** Build dengan `--flavor staging` menghasilkan galat `No matching client found`
> apabila berkas `google-services.json` produksi dipasang, karena application ID varian staging
> belum terdaftar pada proyek Firebase `mbis-38aa0`.

---

## 7. Pengujian

```bash
flutter analyze
flutter test
```

> **Penting.** Perintah `flutter analyze` mengembalikan exit code 1 untuk temuan pada level `info`
> sekalipun. Satu temuan dengan severitas rendah cukup untuk menyebabkan kegagalan pada CI.
> Evaluasi hasil berdasarkan exit code, bukan berdasarkan teks ringkasan:

```bash
flutter analyze; echo "exit=$?"
```

---

## 8. Build Rilis

### 8.1 Android

Gunakan skrip yang tersedia, bukan perintah `flutter build` secara langsung. Skrip menerapkan
validasi prasyarat sebelum build dijalankan.

```bash
PRIVACY_POLICY_URL=https://... \
ACCOUNT_DELETION_URL=https://... \
./scripts/build-aab.sh
```

Validasi menolak proses build apabila `PRIVACY_POLICY_URL` kosong atau `android/key.properties`
tidak tersedia. Ketiadaan validasi kedua menyebabkan build rilis ditandatangani menggunakan debug
key tanpa peringatan, sehingga tidak dapat diunggah ke Google Play.

> **Catatan ukuran distribusi.** Ukuran berkas AAB tidak mencerminkan ukuran unduhan pengguna.
> Google Play mendistribusikan APK yang disesuaikan per perangkat. Angka rujukan tersedia pada
> Play Console melalui menu *App bundle explorer → Download size*.

### 8.2 Web

```bash
flutter build web --wasm --release --no-web-resources-cdn
```

> **Penting.** Lingkungan produksi dikompilasi ke **WasmGC** (`--wasm`), sedangkan
> `flutter run -d chrome` menggunakan target JavaScript. Karakteristik unduhan dan runtime keduanya
> berbeda, sehingga performa produksi tidak dapat disimpulkan dari hasil `flutter run`.

Proses kompilasi, prakompresi gzip, dan penyajian melalui `gzip_static` telah diatur pada
`Dockerfile` dan `nginx.conf`.

### 8.3 iOS

Build iOS tidak dapat dijalankan dari lingkungan Windows. Seluruh proses dilakukan melalui
**Codemagic**, workflow `ios-testflight` pada `codemagic.yaml`.

Distribusi iOS belum dapat dilakukan: Apple Team ID belum tersedia, dan berkas
`ios/Runner/GoogleService-Info.plist` belum dikonfigurasi sehingga notifikasi push tidak aktif pada
platform tersebut.

---

## 9. Struktur Proyek

```
MBIS-Frontend/
├── lib/
│   ├── main.dart                   Titik masuk aplikasi
│   ├── src/                        Modul per domain: auth, customer, pipeline,
│   │                               dashboard, assistant, legal, location, network
│   ├── presentation/               Layar dan widget bersama
│   ├── core/                       Provider dan konfigurasi lintas modul
│   ├── features/                   Struktur feature-first
│   └── data/ · theme/ · utils/
├── android/                        Konfigurasi flavor, R8, google-services.json
├── ios/                            Runner dan privacy manifest (target iOS 13.0)
├── web/                            index.html, splash screen, halaman legal
├── test/                           Pengujian unit dan widget
├── scripts/                        Skrip run dan build
├── docs/                           Dokumentasi rilis dan kepatuhan
├── Dockerfile                      Build web dan image Nginx
├── nginx.conf                      Penyajian bundel dan proxy /api
└── codemagic.yaml                  Definisi CI untuk iOS dan Android
```

Direktori `lib/src/` dan `lib/presentation/` merupakan struktur yang berlaku saat ini, sedangkan
`lib/features/` merupakan arah pengembangan berikutnya. Keduanya digunakan secara berdampingan
sebagai bagian dari migrasi bertahap.

---

## 10. Keamanan Transport

Mekanisme certificate pinning telah disiapkan namun **nonaktif secara bawaan**.
Tanpa `--dart-define=SSL_PINNED_HOSTS`, aplikasi berperilaku identik dengan
kondisi sebelum mekanisme ini ditambahkan.

| Platform | Dukungan |
|---|---|
| Android dan iOS | Didukung, aktif saat dikonfigurasi |
| Web | Tidak didukung — pinning tidak dapat diterapkan pada browser |

Pinning diterapkan **per host**. Aplikasi menghubungi tiga layanan pihak ketiga
(`nominatim.openstreetmap.org`, `api.frankfurter.dev`,
`login.microsoftonline.com`) yang menggunakan CA berbeda; penerapan secara global
akan memutus ketiganya.

Dokumentasi lengkap — model ancaman, prasyarat aktivasi, prosedur perpanjangan
sertifikat, dan perlindungan pengganti untuk kanal web — tersedia pada
[`docs/KEAMANAN-TLS.md`](docs/KEAMANAN-TLS.md).

---

## 11. Catatan Performa

Hasil audit performa yang perlu dipertimbangkan sebelum melakukan optimasi lanjutan.

### 10.1 Kondisi yang sudah sesuai

- **Pemuatan daftar.** Terdapat 64 penggunaan `itemCount`, 26 `ListView.separated`, dan 8
  `ListView.builder`. Jumlah agregat penggunaan `ListView(` tidak dapat dijadikan indikator, karena
  mayoritas merupakan daftar dengan elemen tetap seperti tampilan galat dan layar detail.
- **Penggunaan `shrinkWrap: true`.** Parameter ini hanya menonaktifkan pemuatan lazy apabila
  constraint tinggi dari widget induk tidak terbatas. Evaluasi widget induk diperlukan sebelum
  menyimpulkan adanya permasalahan.
- **Penggunaan `setState`.** Terdapat 356 pemanggilan yang seluruhnya sesuai dengan konvensi
  proyek: data dari backend beserta status pemuatan dan galat dikelola melalui Notifier, sedangkan
  state presentasi seperti kata kunci pencarian, tab aktif, pilihan dropdown, dan controller
  formulir tetap menggunakan `setState`. Rincian tersedia pada
  [`docs/STATE-MANAGEMENT.md`](docs/STATE-MANAGEMENT.md).

### 10.2 Keterbatasan yang diketahui

- **Deferred loading tidak berfungsi pada build `--wasm`.** Kompilator WasmGC tidak menerima opsi
  `--enable-deferred-loading`, dan runtime memperlakukan `loadLibrary()` sebagai operasi kosong.
  Mekanisme ini hanya efektif pada target JavaScript, sehingga penerapannya pada produksi tidak
  memberikan penghematan ukuran.

### 10.3 Peluang optimasi

- `assets/images/maskot.png` berukuran 877 KB dan merupakan aset terbesar pada bundel, melampaui
  total seluruh berkas font.
- Kelima varian `ic_launcher.png` memiliki checksum identik — satu berkas berukuran 160 KB disalin
  ke seluruh bucket densitas alih-alih disediakan dalam resolusi yang sesuai.

---

## 12. Pemecahan Masalah

### Diff berisi perubahan yang tidak relevan setelah pemformatan

Hindari menjalankan `dart format` pada berkas lama. Formatter Dart 3.12 menerapkan gaya *tall style*
yang mengubah ratusan baris di luar cakupan perubahan sehingga menyulitkan proses review.

### Galat "Tried to modify a provider while the widget tree was building"

Pemanggilan `notifier.start()` atau `reload()` secara sinkron pada `didChangeDependencies`
menyebabkan galat ini. Bungkus pemanggilan dengan post-frame callback:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  if (mounted) notifier.start();
});
```

### Assertion Flutter muncul pada layar saat memuat data

Bentuk `setState(() => _future = repo.muat())` mengembalikan `Future` ke `setState`. Gunakan bentuk
blok:

```dart
setState(() {
  _future = repo.muat();
});
```

Kedua permasalahan di atas tidak terdeteksi oleh `flutter analyze` maupun `flutter test` dan hanya
muncul saat aplikasi dijalankan pada perangkat.

### Halaman legal kosong atau 404 setelah perubahan Nginx

Rute `/kebijakan-privasi` dan `/hapus-akun` wajib dapat diakses tanpa autentikasi sesuai persyaratan
Google Play, dan dikecualikan dari pemeriksaan sesi melalui `rutePublikLegal` pada
`lib/src/router.dart`. Ketentuan ini diverifikasi oleh `test/src/legal/rute_publik_test.dart`.

Keduanya disajikan **dua kali** dari satu naskah, dan keduanya harus tetap bekerja:

| Cara diakses | Yang menjawab |
|---|---|
| URL dimuat langsung (reviewer, bot Play, mesin pencari) | berkas statis `web/*.html` lewat blok `location =` di `nginx.conf` |
| Navigasi di dalam aplikasi (`context.push`) | layar Flutter, dirender dari naskah Dart |

Pada `nginx.conf`, blok `location = /kebijakan-privasi` dan `= /hapus-akun` **wajib ada** — tanpa
keduanya, URL jatuh ke SPA fallback dan pengambil HTTP yang tidak menjalankan JS/WASM hanya
menerima cangkang `index.html` tanpa naskah kebijakan. Catatan lama di berkas ini yang melarang
blok tersebut berasal dari periode 27–30 Juli 2026 saat berkas HTML-nya memang tidak ada.

Setelah setiap perubahan konfigurasi Nginx, verifikasi rute `/`, `/dashboard`,
`/kebijakan-privasi`, dan `/hapus-akun` — untuk dua yang terakhir, pastikan isinya **naskah**,
bukan cangkang:

```bash
curl -s http://localhost:8081/kebijakan-privasi | grep -c "Pengendali Data"   # harus >= 1
```

Kalau naskah di `lib/src/legal/` diubah, bangkitkan ulang HTML-nya:

```bash
dart run tool/gen_policy_html.dart
```

`test/src/legal/policy_html_drift_test.dart` gagal kalau langkah ini terlewat.

### Perintah `adb` tidak dikenali

Pada Windows, berkas eksekusi umumnya berada di luar `PATH`:

```
C:\Users\<pengguna>\AppData\Local\Android\Sdk\platform-tools\adb.exe
```

Serial perangkat yang dilaporkan `adb devices` dapat berbeda dari identifier yang digunakan
`flutter run -d`.

### Mengatur ulang sesi saat pengujian lintas peran

```bash
adb shell pm clear com.askrindo.mbis.mobile.staging
adb reverse tcp:8080 tcp:8080
```

Penerusan port perlu dijalankan ulang setelah data aplikasi dihapus.
