# Panduan Rilis Play Store — Step by Step

Panduan urut dari nol sampai aplikasi tayang di Google Play, ditulis untuk Anda
yang menjalankan langkahnya sendiri. Detail teknis tiap bagian ada di
[`RILIS-ANDROID.md`](RILIS-ANDROID.md); dokumen ini adalah **urutan kerjanya**.

> **Konteks handover.** Aplikasi ini akan diserahkan ke divisi lain, dan Play
> Console-nya milik mereka (Anda diundang sebagai kolaborator). Itu bagus: lihat
> [Langkah 8](#langkah-8--serah-terima-ke-divisi-penerima) — kepemilikan aplikasi
> menempel pada akun Play, bukan pada keystore, jadi serah-terimanya rendah risiko.

---

## Peta singkat

```
[0] Prasyarat  →  [1] Buat keystore  →  [2] key.properties  →  [3] Build AAB
        →  [4] Verifikasi AAB  →  [5] Siapkan materi Play Console
        →  [6] Deploy ulang web (dependensi URL kebijakan)
        →  [7] Publish (Internal Testing → Production)  →  [8] Serah terima
```

Yang **hanya bisa Anda lakukan** (menyangkut kata sandi produksi / akun Play):
Langkah 1, 2, 7, 8. Sisanya bisa dibantu/diverifikasi.

---

## Model dua kunci (baca sekali, supaya tidak salah kaprah)

Aplikasi baru yang diunggah sebagai AAB memakai **Play App Signing**:

| Kunci | Dipegang | Kalau hilang |
|---|---|---|
| **App signing key** (final) | **Google**, di bawah akun Play divisi | tidak pernah dipegang manusia — aman |
| **Upload key** (yang Anda buat di Langkah 1) | Anda / divisi | **bisa direset** oleh pemilik Play Console |

Artinya: yang Anda buat cuma **upload key**, dan itu bisa direset. Kehilangannya
**tidak** mematikan aplikasi. Tetap backup dengan benar, tapi tidak perlu takut
berlebihan.

---

## Langkah 0 — Prasyarat

- [ ] **Flutter** terpasang (`flutter --version` → 3.44.x).
- [ ] **JDK** ada — di mesin ini: `C:\Program Files\Java\jdk-23`.
- [ ] **Akses Play Console** ke akun divisi sudah aktif (undangan diterima).
- [ ] Folder aman **di luar repo** untuk menyimpan keystore, mis.
      `C:\Users\rakad\Secure\`. (Folder proyek ada di bawah OneDrive, jadi jangan
      taruh `.jks` di dalamnya — ikut tersinkron ke cloud.)

---

## Langkah 1 — Buat upload keystore

Jalankan di **PowerShell**, dari folder aman tadi:

```powershell
mkdir C:\Users\rakad\Secure -Force
cd C:\Users\rakad\Secure

& "C:\Program Files\Java\jdk-23\bin\keytool.exe" -genkeypair -v `
  -keystore mbis-upload.jks -storetype PKCS12 `
  -keyalg RSA -keysize 4096 -validity 10000 `
  -alias mbis `
  -dname "CN=PT Asuransi Kredit Indonesia (Persero), OU=Divisi Pengelolaan Jaringan, O=PT Asuransi Kredit Indonesia (Persero), L=Jakarta, C=ID"
```

Saat diminta kata sandi:

- Ketik kata sandi (tidak terlihat saat diketik — itu normal), lalu ulangi.
- Bila ditanya *"Enter key password for <mbis>"*, **tekan Enter** agar sama dengan
  kata sandi keystore. PKCS12 tidak menangani kata sandi terpisah dengan baik.
- **Simpan kata sandinya di password manager organisasi sekarang juga**, sebelum
  lanjut. Jangan di catatan pribadi.

Aturan: jangan pernah menaruh kata sandi di baris perintah (`-storepass ...`) —
tersimpan di riwayat PowerShell.

---

## Langkah 2 — Buat `android/key.properties`

```powershell
cd c:\Users\rakad\OneDrive\Dokumen\Projects\mbis\fe-new-mbis\android
copy key.properties.example key.properties
notepad key.properties
```

Isi (hapus baris komentar boleh):

```properties
storeFile=C:/Users/rakad/Secure/mbis-upload.jks
storePassword=<kata sandi Langkah 1>
keyAlias=mbis
keyPassword=<kata sandi yang sama>
```

⚠️ **Wajib garis miring depan `/` pada `storeFile`**, bukan `\`. Berkas
`.properties` memperlakukan `\` sebagai escape, jadi `C:\Users\...` terbaca rusak.
`build.gradle.kts` akan menghentikan build dengan pesan yang menyebut dugaan ini
kalau terjadi — tapi lebih baik tidak kena.

> `key.properties` sudah gitignored (dua lapis). Jangan pernah di-commit.

---

## Langkah 3 — Build AAB

> ⚠️ **WAJIB `flutter clean` dulu — repo ini ada di bawah OneDrive.** Terbukti
> 3 Agustus 2026: build tanpa clean menghasilkan AAB **basi**. OneDrive mengubah
> timestamp berkas saat sinkronisasi, sehingga incremental build Flutter mengira
> kode Dart tidak berubah dan memakai hasil kompilasi lama — perubahan seperti
> penghapusan tombol "Lupa Password?" **tidak ikut**, meski sumbernya sudah benar.
> Resource native (ikon, versionCode) tidak terkena karena diproses Gradle, jadi
> gejalanya menyesatkan: ikon/versi benar, tapi UI Dart tertinggal. Gejala ini
> hanya terlihat kalau AAB diuji di perangkat (Langkah 4c) — bukan dari `analyze`
> atau `test`, yang membaca sumber, bukan artefak build.

> ⚠️ **JANGAN pakai `flutter build appbundle` mentah.** Tanpa
> `--dart-define=API_URL=...`, aplikasi default ke alamat emulator
> `http://10.0.2.2:8080` (lihat `app_config.dart`) — **rusak total di HP
> produksi**. Pakai skrip di bawah, yang **menolak build** bila API_URL / URL
> kebijakan kosong.

Dari akar repo frontend (PowerShell):

```powershell
cd c:\Users\rakad\OneDrive\Dokumen\Projects\mbis\fe-new-mbis
flutter clean            # WAJIB di OneDrive — lihat peringatan di atas
flutter pub get

$env:PRIVACY_POLICY_URL   = "https://mbis.askrindo.co.id/app/kebijakan-privasi"
$env:ACCOUNT_DELETION_URL = "https://mbis.askrindo.co.id/app/hapus-akun"
# (opsional) $env:PRIVACY_CONTACT_EMAIL = "..."
scripts\build-aab.bat https://mbis.askrindo.co.id/v2
```

Argumen pertama = `API_URL` (prefix **`/v2`**, backend). URL kebijakan pakai
prefix **`/app`** (web). Nilai yang sama dipakai APK uji on-device di Langkah 4c.

> **Ini bukan bagian dari alur "docker → server" Anda.** Alur docker itu untuk
> backend + web. AAB adalah artefak Flutter yang terpisah, dibangun di sini.

Keluaran:

- AAB → `build\app\outputs\bundle\prodRelease\app-prod-release.aab`
- mapping R8 → `build\app\outputs\mapping\prodRelease\mapping.txt`

Kalau `key.properties` bermasalah, build **berhenti** dengan kotak
`╭─ RILIS DIBATALKAN ─╮` yang menyebutkan sebabnya (itu disengaja — mencegah AAB
tertandatangani debug key lolos ke Play).

---

## Langkah 4 — Verifikasi AAB sebelum upload

**4a. Tanda tangan benar:**

```powershell
& "C:\Program Files\Java\jdk-23\bin\keytool.exe" -printcert -jarfile build\app\outputs\bundle\prodRelease\app-prod-release.aab
```

Harus muncul `CN=PT Asuransi Kredit Indonesia (Persero)`. Kalau `CN=Android Debug`,
`key.properties` tidak terbaca — cek backslash di `storeFile`.

**4b. Simpan `mapping.txt`** per rilis (untuk membaca stack trace crash di Play):

```powershell
mkdir rilis -Force
copy build\app\outputs\mapping\prodRelease\mapping.txt rilis\mapping-v1.txt
```

**4c. Uji di HP asli — JANGAN dilewati.** Pasang build release di perangkat nyata
dan pakai fitur utamanya. Dua alasan, keduanya hanya terlihat di sini:

1. **Crash R8** — obfuscator hanya aktif di build release, jadi crash akibat
   obfuscation baru muncul di build release, bukan debug.
2. **Build basi** (lihat peringatan Langkah 3) — kalau kode Dart tertinggal, satu-
   satunya cara mengetahuinya adalah melihat UI-nya di perangkat.

Cara cepat (kabel USB, tanpa `bundletool`) — pasang APK release yang ditandatangani
kunci yang sama, fungsional setara untuk uji R8:

```powershell
flutter build apk --flavor prod --release --dart-define=API_URL=https://mbis.askrindo.co.id/v2
# copot build lama bila tanda tangannya beda, lalu pasang:
adb uninstall com.askrindo.mbis.mobile
adb install build\app\outputs\flutter-apk\app-prod-release.apk
```

Lalu buka aplikasinya, login, dan telusuri layar utama sambil memantau crash:

```bash
adb logcat -c && adb logcat | grep -iE "FATAL|E flutter|ClassNotFound|obfuscated"
```

Diverifikasi 3 Agustus 2026 di Xiaomi (Android 13, arm64): setelah `flutter clean`,
build release **tidak crash** saat startup dan layar login benar (tombol "Lupa
Password?" sudah hilang). Uji AAB yang lebih faithful via `bundletool` ada di
[`RILIS-ANDROID.md`](RILIS-ANDROID.md) §4c.

---

## Langkah 5 — Siapkan materi Play Console

Sebagian sudah ada di repo, sebagian masih perlu Anda siapkan.

| Materi | Status | Lokasi / catatan |
|---|---|---|
| Ikon 512×512 | ✅ siap | [`docs/play-store/icon-512.png`](play-store/icon-512.png) |
| Adaptive icon aplikasi | ✅ sudah di AAB | otomatis dari build |
| URL kebijakan privasi | ⚠️ butuh Langkah 6 | `https://mbis.askrindo.co.id/app/kebijakan-privasi` |
| URL hapus akun (Data safety) | ⚠️ butuh Langkah 6 | `https://mbis.askrindo.co.id/app/hapus-akun` |
| Jawaban form Data safety | ✅ tercatat | [`DATA-SAFETY.md`](DATA-SAFETY.md) |
| Akun demo untuk reviewer | ✅ tersedia | lihat seed demo backend + `DATA-SAFETY.md` |
| Feature graphic 1024×500 | ❌ perlu desain | belum ada |
| Screenshot ponsel + tablet | ❌ perlu diambil | dari perangkat/emulator |

---

## Langkah 6 — Deploy ulang web (dependensi URL kebijakan)

**Ini WAJIB sebelum mengisi URL kebijakan di Play Console.** Robot pemeriksa Google
mengambil URL tanpa menjalankan JS/WASM. Saat ini `/app/kebijakan-privasi` masih
mengembalikan cangkang kosong — dicek 3 Agustus 2026:

```bash
curl -s https://mbis.askrindo.co.id/app/kebijakan-privasi | grep -c "Pengendali Data"
# hasil sekarang: 0  → halaman tampak KOSONG bagi bot Play
```

Perbaikannya sudah ada di repo (HTML statis di `web/` + blok nginx). Yang tersisa:
**build & deploy ulang image web prod** supaya berkas itu ikut terbawa. Sesudah
deploy, ulangi perintah di atas — **harus ≥ 1**. Baru setelah itu URL-nya aman
dipasang di Play Console. Rincian di
[`HALAMAN-KEBIJAKAN-PUBLIK.md`](HALAMAN-KEBIJAKAN-PUBLIK.md).

Juga: kalau nanti build lewat Codemagic, isi `PRIVACY_POLICY_URL` /
`ACCOUNT_DELETION_URL` dengan prefiks **`/app`**, bukan `/v2`.

---

## Langkah 7 — Publish (Internal Testing dulu, baru Production)

Di Play Console akun divisi:

1. **Buat aplikasi** (kalau belum): nama, bahasa, kategori. `applicationId`
   permanen: `com.askrindo.mbis.mobile`.
2. **Pastikan Play App Signing aktif** (default untuk aplikasi baru): Setup →
   App integrity / App signing. Ini yang membuat upload key bisa direset nanti.
3. **Isi konten wajib**: kebijakan privasi (URL Langkah 6), Data safety
   ([`DATA-SAFETY.md`](DATA-SAFETY.md)), rating, target audiens, akses aplikasi
   (kredensial akun demo untuk reviewer).
4. **Buat rilis di Internal Testing** dulu — unggah `app-prod-release.aab`,
   tambahkan email penguji. **Internal Testing gratis dan tidak publik** — jauh
   lebih murah menemukan crash R8 di sini daripada setelah tayang.
5. Setelah lolos uji internal, **promote ke Production** dan kirim untuk review.

> Jangan langsung ke Production. Internal Testing adalah jaring pengaman yang paling
> murah.

---

## Langkah 8 — Serah terima ke divisi penerima

Karena aplikasi milik akun Play divisi dan upload key bisa direset, serah-terimanya
sederhana:

1. **Berikan keystore ke divisi via password manager organisasi** — berkas
   `mbis-upload.jks` + `storePassword` + `keyPassword` + `keyAlias` (`mbis`).
   Jangan lewat chat/email/WA.
2. **Serahkan juga** salinan `rilis/mapping-v*.txt` dan dokumen di `docs/`
   (terutama [`RILIS-ANDROID.md`](RILIS-ANDROID.md) dan panduan ini).
3. **Opsional — divisi pakai kunci sendiri.** Kalau mereka ingin tidak bergantung
   pada kunci Anda: Play Console → App signing → **request upload key reset**,
   lalu daftarkan keystore baru buatan mereka. Aplikasi tidak terganggu.
4. **Kalau build pindah ke Codemagic mereka**: masukkan keystore ke environment
   group `mbis-android-keystore` (`KEYSTORE_B64` = isi `.jks` di-base64,
   `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`, semua "Secure"). Base64:
   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\Users\rakad\Secure\mbis-upload.jks")) `
     | Set-Content -Encoding ascii C:\Users\rakad\Secure\mbis-upload.jks.b64
   ```

---

## Checklist ringkas

- [ ] Keystore dibuat & kata sandi di password manager organisasi (L1)
- [ ] `android/key.properties` diisi, `storeFile` pakai `/` (L2)
- [ ] `flutter build appbundle --flavor prod --release` sukses (L3)
- [ ] Tanda tangan AAB = `CN=PT Asuransi Kredit Indonesia (Persero)` (L4a)
- [ ] `mapping.txt` diarsipkan (L4b)
- [ ] AAB release diuji di HP asli, fitur utama jalan (L4c)
- [ ] **Web di-deploy ulang; `/app/kebijakan-privasi` mengembalikan naskah** (L6)
- [ ] Materi Play Console lengkap: ikon, URL kebijakan, Data safety, akun demo,
      feature graphic, screenshot (L5)
- [ ] Rilis lewat Internal Testing sebelum Production (L7)
- [ ] Keystore + dokumen diserahkan ke divisi via password manager (L8)

---

## Catatan status (per 3 Agustus 2026)

- **Nomor versi** ditahan di `1.0.0+1` (versionCode 1) — sesuai keputusan; jangan
  dinaikkan tanpa aba-aba.
- **Keystore** belum dibuat — ini blocker terakhir, dan Langkah 1–2 yang
  menutupnya.
- **Tombol "Lupa Password?"** sudah dihapus (M-BIS tanpa reset mandiri).
- **Ikon** sudah diperbaiki (adaptive + legacy + 512×512).
- **Halaman kebijakan** sudah jadi HTML statis di repo, tapi **web belum
  di-deploy ulang** — lihat Langkah 6.
- **Flavor `staging` di Firebase** belum terdaftar — tidak memblokir rilis prod,
  tapi menghambat jalur uji staging.
- **iOS** belum mungkin (Apple Team ID belum ada) — di luar cakupan panduan ini.
