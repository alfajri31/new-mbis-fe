# Rilis iOS M-BIS — panduan langkah demi langkah

> Status repo diverifikasi 2026-07-23 pada `main@16ae359`.
> Belum ada build iOS yang pernah diunggah. Dokumen ini urut dari nol.

## 0. Tiga hal yang memblokir sebelum menyentuh kode

### a. Role App Store Connect Anda kemungkinan belum cukup

Role **Developer** boleh meng-*upload* build, tapi **tidak boleh membuat app record baru**
dan **tidak boleh submit for review**. Itu perlu **App Manager**, **Admin**, atau
**Account Holder**. Sertifikat *distribution* umumnya juga perlu Admin/Account Holder.

**Aksi:** minta Account Holder Apple Developer Askrindo menaikkan role Anda ke **App Manager**.
Tanpa ini, langkah §3 ke bawah akan mentok.

### b. Build iOS wajib macOS

Xcode hanya jalan di macOS; kita bekerja di Windows. Pilihan:

| Opsi | Catatan |
|---|---|
| **Codemagic** | Sudah jadi rencana di CLAUDE.md; ada tier gratis; `codemagic.yaml` belum dibuat |
| **Xcode Cloud** | Terintegrasi App Store Connect, butuh role yang memadai |
| **GitHub Actions** runner `macos-*` | Repo sudah pakai GitHub Actions untuk CI |
| Mac fisik | Paling sederhana kalau tim TI punya |

### c. Rute distribusi — keputusan tim TI, bukan teknis

M-BIS adalah aplikasi **internal pegawai** (RM + Agen) dengan tembok login korporat. App Store
publik kerap **menolak** aplikasi seperti ini (audiens terbatas / tanpa fungsi bagi publik).

| Rute | Cocok untuk | Catatan |
|---|---|---|
| **TestFlight** | Pilot sekarang | 100 tester internal; tercepat |
| **Custom App (Apple Business Manager)** ⭐ | Produksi internal | Distribusi privat ke organisasi Askrindo; perlu Askrindo terdaftar di ABM |
| **Unlisted App Distribution** | Produksi via tautan | Ada di App Store tapi tidak muncul di pencarian; perlu pengajuan ke Apple |
| App Store publik | — | Risiko penolakan tertinggi; **wajib** sediakan akun demo untuk reviewer |

**Rekomendasi:** TestFlight untuk pilot → **Custom App via ABM** untuk produksi.
**Tanyakan ke TI:** apakah Askrindo sudah punya Apple Business Manager?

## 1. Prasyarat repo

Sudah dikerjakan — ada di branch **`chore/prep-rilis-ios`** (terpisah dari branch dokumen ini):

| Item | Status | Keterangan |
|---|---|---|
| `ios/Runner/PrivacyInfo.xcprivacy` | ✅ dibuat & **terdaftar di target Xcode** | Mencegah **ITMS-91053**. Mendeklarasikan UserDefaults `CA92.1`, FileTimestamp `C617.1`, DiskSpace `E174.1`, `NSPrivacyTracking=false`, plus data yang dikumpulkan |
| `ITSAppUsesNonExemptEncryption` | ✅ `false` | Hanya HTTPS/TLS standar = exempt; App Store Connect tidak bertanya lagi tiap unggahan |
| `CFBundleDisplayName` | ✅ `Mbis` → `M-BIS` | Nama di home screen |
| `description` pubspec | ✅ diisi | Bukan lagi `A new Flutter project.` |
| **Target iPhone saja** | ✅ `TARGETED_DEVICE_FAMILY` `"1,2"` → `1` | Diterapkan pada Debug/Release/Profile; `UISupportedInterfaceOrientations~ipad` ikut dihapus. **Screenshot iPad tidak lagi diperlukan** |
| `codemagic.yaml` | ✅ dibuat & placeholder terisi | Workflow `ios-testflight` + `android-release` |

> Karena tidak ada Mac, `PrivacyInfo.xcprivacy` didaftarkan dengan menyunting
> `project.pbxproj` langsung (PBXBuildFile + PBXFileReference + grup Runner +
> Copy Bundle Resources). Kalau nanti dibuka di Xcode, berkas itu harus muncul di
> **Runner → Build Phases → Copy Bundle Resources**. Bila tidak, tambahkan lewat GUI.

### 1a. Nilai yang harus diisi di UI Codemagic

`codemagic.yaml` sengaja **tidak** memuat rahasia. Yang berikut diisi di dasbor Codemagic,
bukan di repo:

| Tempat | Kunci | Isi |
|---|---|---|
| Teams → Integrations → App Store Connect | nama integrasi | **`askrindo-app-store-connect`** (harus persis; sudah dirujuk `codemagic.yaml`). Butuh Issuer ID + Key ID + `.p8` dari App Store Connect → Users and Access → Integrations |
| Environment variables, group `mbis-prod` | `API_URL` | URL backend produksi, mis. `https://mbis.askrindo.co.id` (**tanpa** akhiran `/api`) |
| " | `APP_ENV` | `prod` |
| Environment variables, group `mbis-android-keystore` (**centang Secure**) | `KEYSTORE_B64` | Isi upload keystore `.jks` yang di-base64. Windows: `certutil -encode mbis.jks mbis.b64` lalu buang baris `-----BEGIN/END-----` |
| " | `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD` | Sesuai keystore yang dibuat |

> Membuat API key App Store Connect butuh role **Admin/Account Holder** — kalau Anda
> masih Developer, mintakan ke pemegang akun sekalian saat minta kenaikan role.

### 1b. `GoogleService-Info.plist` — cara membuatnya sendiri

Berkas ini **tidak bisa ditulis tangan**: isinya (`GOOGLE_APP_ID`, `API_KEY`,
`GCM_SENDER_ID`) diterbitkan Firebase saat app didaftarkan. Tapi **Anda bisa membuatnya
sendiri** lewat Firebase Console, asalkan punya akses ke proyeknya.

Proyek Firebase yang sudah dipakai Android: **`mbis-38aa0`** (project number `436844402963`),
berisi dua app Android (`com.askrindo.mbis.mobile` dan `...staging`). **Belum ada app iOS** —
itu yang perlu ditambahkan. Kalau Anda belum punya akses, minta ke siapa pun yang dulu
menyiapkan sisi Android.

1. [console.firebase.google.com](https://console.firebase.google.com) → pilih proyek **`mbis-38aa0`**
   (jangan bikin proyek baru — nanti Android & iOS terpisah)
2. **Project settings** → tab **General** → **Your apps** → **Add app** → **iOS**
3. **Apple bundle ID**: `com.askrindo.mbis.mobile` — harus sama persis dengan
   `PRODUCT_BUNDLE_IDENTIFIER`. App nickname bebas, mis. `M-BIS iOS`
4. Klik **Register app** → **Download GoogleService-Info.plist**
5. Simpan ke **`ios/Runner/GoogleService-Info.plist`** (sejajar `Info.plist`).
   Lewati langkah "add Firebase SDK/initialization" di wizard — `firebase_core` sudah
   menanganinya lewat Flutter
6. **Daftarkan ke target Xcode.** Sama seperti privacy manifest, menaruh berkas di folder
   saja tidak cukup. Tanpa Mac, tambahkan 4 baris berikut ke
   `ios/Runner.xcodeproj/project.pbxproj` (ID di bawah sudah dicek unik):

   ```
   # a) di section PBXBuildFile, sejajar entri Assets.xcassets:
   A1D3E5F70A1B2C3D4E5F6003 /* GoogleService-Info.plist in Resources */ = {isa = PBXBuildFile; fileRef = A1D3E5F70A1B2C3D4E5F6004 /* GoogleService-Info.plist */; };

   # b) di section PBXFileReference:
   A1D3E5F70A1B2C3D4E5F6004 /* GoogleService-Info.plist */ = {isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "GoogleService-Info.plist"; sourceTree = "<group>"; };

   # c) di children grup Runner (97C146F01CF9000F007C117D):
   A1D3E5F70A1B2C3D4E5F6004 /* GoogleService-Info.plist */,

   # d) di files PBXResourcesBuildPhase target Runner (97C146EC1CF9000F007C117D):
   A1D3E5F70A1B2C3D4E5F6003 /* GoogleService-Info.plist in Resources */,
   ```

   ⚠️ Lakukan **setelah** berkasnya benar-benar ada. Mendaftarkan berkas yang belum ada
   membuat build Xcode gagal.

7. **APNs key** (tanpa ini push tetap mati walau plist sudah ada):
   Apple Developer → **Keys** → `+` → centang **Apple Push Notifications service (APNs)** →
   unduh `.p8` (**hanya sekali**) → Firebase Console → Project settings → **Cloud Messaging** →
   app iOS → **APNs Authentication Key** → unggah `.p8` + Key ID + Team ID
8. Pastikan capability **Push Notifications** aktif pada App ID `com.askrindo.mbis.mobile`

> `GoogleService-Info.plist` tidak masuk `.gitignore` — perlakuannya sama dengan
> `android/app/google-services.json` yang memang sudah ter-commit.

Masih kurang:

| Item | Status | Akibat bila dibiarkan |
|---|---|---|
| `ios/Runner/GoogleService-Info.plist` | ❌ belum ada | **Push notification mati di iOS** sampai langkah §1b dikerjakan. Aplikasi tetap bisa dibuild & jalan (inisialisasi Firebase sudah di-guard) |

Yang **sudah aman** (terverifikasi):

- Bundle id `com.askrindo.mbis.mobile` (iOS & Android konsisten) — bukan lagi `com.example`
- Ikon 1024×1024 **RGB tanpa alpha** (alpha = ditolak otomatis Apple)
- Deskripsi izin sudah ada & berbahasa Indonesia: lokasi, kamera, galeri
- `IPHONEOS_DEPLOYMENT_TARGET = 13.0`, versi `1.0.0+1` (wajar untuk rilis pertama)
- `UIBackgroundModes`: `remote-notification`, `fetch`

## 2. Daftar bundle id di Apple Developer

1. developer.apple.com → **Certificates, Identifiers & Profiles** → **Identifiers** → `+`
2. **App IDs** → **App**, Description: `M-BIS`, Bundle ID (Explicit): `com.askrindo.mbis.mobile`
3. Centang Capabilities yang dipakai: **Push Notifications** (FCM)
4. Untuk push: **Keys** → `+` → **Apple Push Notifications service (APNs)** → unduh `.p8`
   (hanya bisa diunduh **sekali**) → unggah ke Firebase Console → Project Settings → Cloud Messaging

## 3. Buat app record di App Store Connect

> Butuh role **App Manager+** (lihat §0a).

appstoreconnect.apple.com → **Apps** → `+` → **New App**:

- Platform: iOS
- Nama: `M-BIS` *(harus unik se-App Store; siapkan alternatif mis. `M-BIS Askrindo`)*
- Bahasa utama: Indonesian
- Bundle ID: `com.askrindo.mbis.mobile`
- SKU: bebas & internal, mis. `MBIS-IOS-001`

## 4. Signing

Dengan **automatic signing** di Xcode (paling mudah): buka `ios/Runner.xcworkspace`, tab
**Signing & Capabilities**, pilih Team Askrindo, centang *Automatically manage signing*.

Untuk CI (Codemagic/Actions) perlu diekspor manual:
- **Distribution Certificate** (`.p12` + password)
- **Provisioning Profile** tipe *App Store* untuk `com.askrindo.mbis.mobile`
- Atau **App Store Connect API key** (`.p8` + Key ID + Issuer ID) — lebih disarankan, tidak kedaluwarsa tiap tahun

Simpan semuanya sebagai **secret CI**, jangan pernah di-commit (`.gitignore` sudah menutup `secrets/`).

## 5. Build & unggah

```bash
flutter build ipa --release \
  --dart-define=API_URL=https://<host-produksi>/api
```

Hasil: `build/ios/archive/Runner.xcarchive` → unggah via **Xcode Organizer** atau
**Transporter**, atau dari CI:

```bash
xcrun altool --upload-app -f build/ios/ipa/*.ipa \
  --apiKey "$APP_STORE_KEY_ID" --apiIssuer "$APP_STORE_ISSUER_ID"
```

> Base URL wajib lewat `--dart-define` (aturan `externalize-config`) — jangan hardcode.

## 6. Isian App Store Connect

- [ ] **URL kebijakan privasi** — wajib, harus bisa diakses publik. Koordinasi dengan TI/Legal Askrindo
- [ ] **Kuesioner App Privacy** — app ini mengumpulkan: **lokasi presisi** (GPS kunjungan),
      **nama & NIP** (identifier), **foto** (dokumen/kunjungan), **kontak PIC nasabah**.
      Semuanya **linked to the user's identity**. Deklarasikan jujur — salah isi = ditolak
- [ ] **Akun demo untuk reviewer** — App Review **pasti** tersandung tembok login.
      Sediakan NIP + password aktif, dan tulis di *App Review Information → Notes* bahwa
      aplikasi ini untuk pegawai internal Askrindo
- [ ] **Screenshot** — iPhone 6,9" wajib. Screenshot iPad **tidak diperlukan** karena
      target sudah dibatasi iPhone saja (§1)
- [ ] **Export compliance** — HTTPS standar = exempt; dijawab otomatis bila §1 (`ITSAppUsesNonExemptEncryption=false`) sudah dipasang
- [ ] Kategori (mis. Business), rating usia, teks promosi, *what's new*

## 7. Urutan yang disarankan

1. Minta kenaikan role → **App Manager** (sekalian minta dibuatkan **API key App Store
   Connect** kalau Anda tak berwenang membuatnya) *(blocker, urus paling awal)*
2. Tanya TI: Apple Business Manager sudah ada? → tentukan rute distribusi (§0c)
3. Merge branch **`chore/prep-rilis-ios`** (prasyarat repo §1 sudah selesai di sana)
4. Kerjakan §1b: daftarkan app iOS di Firebase `mbis-38aa0` → `GoogleService-Info.plist`
   + APNs key
5. Isi nilai Codemagic sesuai §1a (integrasi ASC + group `mbis-prod`)
6. Daftar bundle id di Apple Developer (§2)
7. Buat app record (§3) → signing (§4) → unggah build pertama (§5)
8. **TestFlight internal dulu** — uji di perangkat nyata sebelum submit apa pun
9. Lengkapi §6 → submit sesuai rute yang dipilih

## 8. Android (sebagai pembanding)

Sisi Android jauh lebih siap: `applicationId com.askrindo.mbis.mobile`, flavor `prod`/`staging`,
konfigurasi keystore rilis dengan fallback ke debug, dan `google-services.json` sudah ada.
Yang kurang hanya keystore rilis asli + akun Play Console.
