# Rilis Android — Google Play

Runbook rilis M-BIS mobile ke Google Play. Pasangannya untuk iOS ada di
[`RILIS-IOS.md`](RILIS-IOS.md). Checklist audit lengkapnya ada di
[`../../DEPLOY-PLAYSTORE.md`](../../DEPLOY-PLAYSTORE.md) — dokumen ini adalah
langkah operasionalnya.

Identitas paket yang sudah dikunci (jangan diubah, permanen setelah rilis pertama):

| | |
|---|---|
| applicationId (prod) | `com.askrindo.mbis.mobile` |
| applicationId (staging) | `com.askrindo.mbis.mobile.staging` |
| flavor rilis | `prod` |
| compileSdk / targetSdk | 36 |

---

## 1. Keystore rilis

> **Ini upload key, bukan app signing key.** Aplikasi baru yang diunggah sebagai
> AAB memakai **Play App Signing**: Google yang memegang kunci penandatangan
> final, sementara kunci yang Anda buat di bawah dipakai untuk *mengunggah*.
> Artinya kehilangan kunci ini **tidak** mematikan aplikasi — Anda bisa meminta
> reset upload key ke Google dan mendaftarkan yang baru.
>
> Versi sebelumnya dokumen ini menulis "kalau hilang, Anda tidak bisa lagi
> menerbitkan update". Itu benar untuk model penandatanganan lama, dan salah kalau
> Play App Signing aktif — pastikan statusnya di Play Console → Setup → App signing
> saat mendaftarkan aplikasi. Tetap backup dengan benar, tapi jangan biarkan
> ketakutan itu menunda rilis.

Dibuat **sekali**, di folder **di luar repo** (folder proyek ada di bawah OneDrive,
jadi apa pun di dalamnya ikut tersinkron ke cloud):

```bash
keytool -genkeypair -v \
  -keystore mbis-upload.jks -storetype PKCS12 \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias mbis \
  -dname "CN=PT Asuransi Kredit Indonesia (Persero), OU=Divisi Pengelolaan Jaringan, O=PT Asuransi Kredit Indonesia (Persero), L=Jakarta, C=ID"
```

Kata sandi ditanyakan interaktif — **jangan** menaruhnya di baris perintah, nanti
tersimpan di riwayat shell. Pakai kata sandi yang **sama** untuk store dan key:
PKCS12 tidak mendukung kata sandi terpisah dengan baik, dan bila dibedakan Gradle
gagal dengan pesan yang menyesatkan.

Lalu salin [`android/key.properties.example`](../android/key.properties.example)
menjadi `android/key.properties` (gitignored, **jangan** di-commit) dan isi:

```properties
storeFile=C:/Users/<user>/Secure/mbis-upload.jks
storePassword=...
keyAlias=mbis
keyPassword=...
```

⚠️ **Wajib garis miring depan pada `storeFile`.** Berkas `.properties` memperlakukan
`\` sebagai karakter escape, jadi `C:\Users\...` terbaca rusak. `build.gradle.kts`
kini memeriksa hal ini dan berhenti dengan pesan yang menyebut dugaan tersebut —
sebelumnya kegagalannya tidak menyebut sebab sama sekali.

**Pastikan kuncinya benar-benar terpakai** setelah build AAB pertama:

```bash
keytool -printcert -jarfile build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

Harus memunculkan `CN=PT Asuransi Kredit Indonesia (Persero)`. Kalau yang muncul
`CN=Android Debug`, `key.properties` tidak terbaca.

Yang harus dibackup: berkas `.jks`, `storePassword`, `keyPassword`, dan `keyAlias`
— di password manager organisasi, bukan laptop perorangan.

> `android/app/build.gradle.kts` **menolak** menjalankan task `bundle*Release`
> kalau `key.properties` tidak ada. Ini disengaja: sebelumnya build diam-diam
> jatuh ke debug key, dan kegagalannya baru ketahuan setelah AAB ditolak
> Play Console. Build APK release masih boleh tanpa keystore (untuk uji lokal),
> tapi Gradle mencetak peringatan.

### Di CI (Codemagic)

Workflow `android-release` merakit `key.properties` dari environment group
`mbis-android-keystore`: `KEYSTORE_B64` (isi `.jks` yang di-base64),
`KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`. Semuanya harus dicentang
"Secure".

```bash
base64 -w0 mbis-release.jks > mbis-release.jks.b64   # isi variabel KEYSTORE_B64
```

---

## 2. Konfigurasi wajib sebelum build

Build prod menolak jalan kalau salah satu kosong — lihat `scripts/build-aab.*`
dan gerbang yang sama di `codemagic.yaml`.

| Variabel | Wajib | Kenapa |
|---|---|---|
| `API_URL` | ✅ | Base URL backend produksi. Harus HTTPS; `network_security_config` prod menolak cleartext |
| `PRIVACY_POLICY_URL` | ✅ | URL kebijakan privasi untuk **Play Console**. Prod: `https://mbis.askrindo.co.id/app/kebijakan-privasi` — HTML statis dari `web/kebijakan-privasi.html`, terbaca pengambil otomatis Play tanpa menjalankan JS/WASM. Kewajiban "dapat dibuka dari dalam aplikasi" dipenuhi terpisah: naskahnya terbundel dan dirender di `/profil/privasi/kebijakan`, jadi tidak bergantung pada variabel ini |
| `ACCOUNT_DELETION_URL` | ✅ | Halaman permintaan hapus akun yang bisa diakses **tanpa memasang aplikasi**; URL-nya dilampirkan di Data safety form. Prod: `https://mbis.askrindo.co.id/app/hapus-akun`. Lihat [HALAMAN-KEBIJAKAN-PUBLIK.md](HALAMAN-KEBIJAKAN-PUBLIK.md) |
| `PRIVACY_CONTACT_EMAIL` | — | Ditampilkan di layar Privasi & Akun kalau diisi |

Ketiganya dibaca `AppConfig` lewat `--dart-define` dan tampil di layar
**Profil → Privasi & Akun** (`/profil/privasi`, dan `/agent/profil/privasi`
untuk shell Agen).

Satu gerbang lagi yang bukan variabel: `scripts/build-aab.*` menolak build
selama `kebijakanMasihDraf = true` di
`lib/src/legal/kebijakan_privasi_content.dart` — naskah kebijakan terbundel di
aplikasi, jadi build rilis akan menerbitkan teks yang belum disahkan Legal.
Lihat [HALAMAN-KEBIJAKAN-PUBLIK.md](HALAMAN-KEBIJAKAN-PUBLIK.md) §2.

### Catatan penghapusan akun

Akun M-BIS **tidak** dibuat sendiri oleh pengguna: admin membuatnya lewat
`POST /api/auth/admin/users`, dan akun Agen didaftarkan oleh RM. Karena tidak ada
pendaftaran mandiri di dalam aplikasi, kewajiban "tombol hapus akun instan" tidak
berlaku secara harfiah — tetapi jalur permintaan penghapusan dan halaman webnya
tetap wajib ada, dan itulah yang disediakan layar Privasi & Akun.

Halaman web yang dibuat unit terkait minimal harus memuat: cara mengajukan,
identitas apa yang diverifikasi, data mana yang dihapus, dan **data mana yang
ditahan karena ketentuan arsip perusahaan asuransi** beserta jangka waktunya.
Isi halaman itu harus konsisten dengan teks di layar Privasi & Akun.

---

## 3. Build AAB

```bash
export PRIVACY_POLICY_URL="https://mbis.askrindo.co.id/app/kebijakan-privasi"
export ACCOUNT_DELETION_URL="https://mbis.askrindo.co.id/app/hapus-akun"
export PRIVACY_CONTACT_EMAIL="..."          # opsional

scripts/build-aab.sh https://mbis.askrindo.co.id/v2
```

Windows:

```bat
set PRIVACY_POLICY_URL=https://mbis.askrindo.co.id/app/kebijakan-privasi
set ACCOUNT_DELETION_URL=https://mbis.askrindo.co.id/app/hapus-akun
scripts\build-aab.bat https://mbis.askrindo.co.id/v2
```

Keluaran:

- AAB — `build/app/outputs/bundle/prodRelease/app-prod-release.aab`
- mapping — `build/app/outputs/mapping/prodRelease/mapping.txt`

`versionCode`/`versionName` diambil dari `version:` di `pubspec.yaml`. Di CI,
`--build-number=$PROJECT_BUILD_NUMBER` menimpa `versionCode` dengan nomor build
Codemagic sehingga tidak pernah bentrok antar-orang. Untuk build manual, naikkan
angka setelah `+` di `pubspec.yaml` — Play menolak `versionCode` yang berulang
atau mundur.

---

## 4. Verifikasi sebelum upload

### 4a. Simpan mapping.txt

Minify (R8) aktif di buildType release, jadi stack trace crash di Play Console
teracak sampai `mapping.txt` diunggah. Arsipkan per rilis:

```bash
mkdir -p rilis && cp build/app/outputs/mapping/prodRelease/mapping.txt \
  rilis/mapping-v<versionCode>.txt
```

Peta simbol yang sama diunggah **otomatis** ke Firebase Crashlytics saat build rilis
(`mappingFileUploadEnabled = true` di `android/app/build.gradle.kts`), sehingga crash
yang masuk ke konsol Crashlytics sudah terbaca tanpa langkah manual. Salinan di
`rilis/` tetap diperlukan untuk Play Console, yang terpisah dari Crashlytics.

Pelaporan crash **tidak aktif di build debug** — lihat
`lib/core/observability/crash_reporter.dart`. Untuk mengujinya, pakai build rilis dan
picu crash sengaja, lalu tunggu laporannya muncul di konsol Firebase (biasanya
beberapa menit; crash pertama kadang baru terkirim setelah aplikasi dibuka ulang).

> **Aturan yang tidak boleh dilanggar:** jangan pernah menaruh PII di custom key
> Crashlytics. `CrashReporter.setUser` sengaja hanya menerima **id akun** — bukan
> NIP, nama, atau surel — supaya laporan bisa ditelusuri lewat basis data internal
> tanpa mengirim identitas pegawai ke Google.

### 4b. Kompatibilitas 16 KB page size

Wajib sejak 1 November 2025; kalau gagal, **upload diblokir**.

```bash
unzip -o build/app/outputs/bundle/prodRelease/app-prod-release.aab -d /tmp/aab
find /tmp/aab -name "*.so" | while read f; do
  echo "=== $f"
  "$ANDROID_NDK_HOME"/toolchains/llvm/prebuilt/*/bin/llvm-readelf -l "$f" | grep LOAD
done
```

`Align` harus `0x4000` (16384). Kalau ada yang `0x1000`, pelakunya hampir selalu
plugin pihak ketiga — naikkan versinya, dan kalau belum ada rilis yang memperbaiki,
plugin itu harus diganti sebelum rilis.

Tanpa command line: Android Studio → **Build → Analyze APK**.

### 4c. Uji AAB di device asli

Bukan APK debug — **AAB release**. Crash akibat obfuscation R8 hanya muncul di
build release, dan aturan keep ada di `android/app/proguard-rules.pro`.

```bash
bundletool build-apks --bundle=build/app/outputs/bundle/prodRelease/app-prod-release.aab \
  --output=mbis.apks --ks=mbis-release.jks --ks-key-alias=mbis --mode=universal
bundletool install-apks --apks=mbis.apks
```

Yang wajib dijalani minimal sekali di build release:

- [ ] Login semua peran (DPJ/RO/BM/KUP/RM/AGENT)
- [ ] Notifikasi push masuk (FCM + jadwal lokal — bagian yang paling rawan R8)
- [ ] Ambil foto & pilih berkas (image_picker / file_picker)
- [ ] GPS & peta kunjungan (geolocator / flutter_map)
- [ ] Ekspor Excel & PDF kalkulator premi (printing)
- [ ] Buka layar Privasi & Akun, pastikan kedua tautan terbuka
- [ ] Rotasi layar di beberapa halaman, dan sekali di tablet/landscape

### 4d. Cek manifest hasil merge

```bash
bundletool dump manifest --bundle=build/app/outputs/bundle/prodRelease/app-prod-release.aab
```

Pastikan: tidak ada `android:debuggable`, tidak ada permission `AD_ID`
(sudah dibuang lewat `tools:node="remove"`), dan `networkSecurityConfig` yang
terpakai adalah versi ketat dari `src/main` — pengecualian cleartext untuk
localhost hanya ada di source set `debug` dan flavor `staging`.

---

## 5. Yang masih harus disiapkan di luar kode

Bagian ini belum tersentuh kode dan biasanya paling lama; lihat
[`../../DEPLOY-PLAYSTORE.md`](../../DEPLOY-PLAYSTORE.md) bagian H, I, dan K.

- [ ] Halaman kebijakan privasi (direview legal, di-host di domain organisasi)
- [ ] Halaman permintaan penghapusan akun
- [ ] Tabel inventaris Data safety per SDK
- [ ] Akun demo aktif untuk reviewer Google
- [ ] Bukti afiliasi resmi BUMN atas nama pemilik akun Play Console
- [x] ~~Adaptive icon (`mipmap-anydpi-v26`)~~ — **SELESAI 3 Agustus 2026**, lihat §6.
- [x] ~~Icon 512×512~~ — dibangkitkan ke
      [`docs/play-store/icon-512.png`](play-store/icon-512.png), tinggal diunggah.
- [ ] Aset grafis sisanya: feature graphic 1024×500, screenshot ponsel + tablet

---

## 6. Ikon aplikasi

Dibangkitkan dari **logo aplikasi yang sudah dipakai** (`assets/images/logo-mbis.webp`
— monogram MB yang juga tampil di splash, login, dan header), bukan aset baru.

```bash
dart run flutter_launcher_icons     # konfigurasinya di pubspec.yaml
```

### Apa yang diperbaiki

Sebelumnya ikonnya rusak tanpa ada yang menyadari: **satu berkas 582×393 — tidak
persegi — disalin identik ke kelima folder mipmap.**

| | Sebelum | Sesudah |
|---|---|---|
| Bentuk | 582×393 (melebar) → diregangkan/dipotong launcher | persegi, sesuai densitas |
| Ukuran per densitas | sama semua (160 KB × 5) | 48/72/96/144/192 px |
| Total di APK | ±820 KB | ±43 KB (legacy) + ±199 KB (foreground adaptive) |
| Adaptive icon | **tidak ada** | ada (`mipmap-anydpi-v26/ic_launcher.xml`) |

Tanpa adaptive icon, Android 8+ membungkus ikon lawas dengan latar abu-abu lalu
mengecilkannya — dan `targetSdk` di sini 36, jadi itu yang selama ini terjadi.

### Safe zone — jangan asal membesarkan logonya

Kanvas adaptive icon 108dp, tapi yang **dijamin** terlihat hanya lingkaran tengah
72dp (66,7%); sisanya bisa terpotong tergantung bentuk mask launcher. Karena logo
MB melebar (rasio 1,48), yang membatasi adalah **diagonal**-nya, bukan lebarnya.

`flutter_launcher_icons` juga menambahkan `inset="16%"` sendiri pada foreground,
jadi ada dua penyusutan yang bertumpuk. Perhitungan yang dipakai:

```
logo 783 px pada kanvas 1024
  → setelah inset 16%   : 52,0% kanvas
  → diagonal            : 62,8%   (batas aman 66,7%)  ✓
```

Percobaan pertama memakai 560 px dan hasilnya hanya 44,9% — muat, tapi logonya
tampak kekecilan dengan ruang kosong berlebih. Kalau nanti logonya diganti,
hitung ulang: perbesar sampai diagonalnya mendekati 66,7%, jangan lewat.

> `assets/icon/*.png` **sengaja tidak** didaftarkan di `flutter: assets:`. Keduanya
> hanya dibaca saat membangkitkan ikon, bukan saat aplikasi berjalan —
> mendaftarkannya cuma menambah ukuran APK tanpa guna.

iOS sengaja dilewati (`ios: false`): rilis iOS belum mungkin dan ikon iOS punya
aturan sendiri (tanpa alpha). Nyalakan bersamaan saat jalur App Store disiapkan.
