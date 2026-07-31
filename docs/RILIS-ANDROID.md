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

**Dibuat sekali seumur aplikasi.** Kalau hilang setelah publish, Anda tidak bisa
lagi menerbitkan update untuk `com.askrindo.mbis.mobile` — kecuali lewat proses
pemulihan key Google yang panjang. Simpan di password manager organisasi, bukan
di laptop perorangan.

```bash
keytool -genkeypair -v \
  -keystore mbis-release.jks -storetype PKCS12 \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -alias mbis \
  -dname "CN=PT Askrindo (Persero), OU=PJD, O=PT Askrindo (Persero), L=Jakarta, C=ID"
```

Lalu buat `android/key.properties` (gitignored, **jangan** di-commit):

```properties
storeFile=C:/path/absolut/ke/mbis-release.jks
storePassword=...
keyAlias=mbis
keyPassword=...
```

Yang harus dibackup: berkas `.jks`, `storePassword`, `keyPassword`, dan `keyAlias`.

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
| `PRIVACY_POLICY_URL` | ✅ | URL kebijakan privasi untuk **Play Console**. Halamannya rute Flutter publik `/kebijakan-privasi`, dikecualikan dari gerbang auth. Kewajiban "dapat dibuka dari dalam aplikasi" dipenuhi terpisah: naskahnya terbundel dan dirender di `/profil/privasi/kebijakan`, jadi tidak bergantung pada variabel ini |
| `ACCOUNT_DELETION_URL` | ✅ | Halaman permintaan hapus akun yang bisa diakses **tanpa memasang aplikasi**; URL-nya dilampirkan di Data safety form. Halamannya rute Flutter publik `/hapus-akun`. Lihat [HALAMAN-KEBIJAKAN-PUBLIK.md](HALAMAN-KEBIJAKAN-PUBLIK.md) |
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
export PRIVACY_POLICY_URL="https://.../kebijakan-privasi"
export ACCOUNT_DELETION_URL="https://.../hapus-akun"
export PRIVACY_CONTACT_EMAIL="..."          # opsional

scripts/build-aab.sh https://mbis.askrindo.co.id/v2
```

Windows:

```bat
set PRIVACY_POLICY_URL=https://.../kebijakan-privasi
set ACCOUNT_DELETION_URL=https://.../hapus-akun
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
- [ ] Aset grafis: icon 512×512, feature graphic 1024×500, screenshot ponsel + tablet
- [ ] Adaptive icon (`mipmap-anydpi-v26`) — sekarang icon masih PNG persegi biasa,
      butuh aset logo dengan safe-zone yang benar dari tim desain
