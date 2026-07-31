# Inventaris Data Safety — M-BIS Mobile

Bahan untuk mengisi **Play Console → App content → Data safety**. Disusun dari
dependency nyata di `pubspec.yaml` dan permission di `AndroidManifest.xml`, bukan
dari asumsi.

> Ketidakcocokan antara deklarasi di form dan perilaku aplikasi adalah salah satu
> penyebab suspend paling umum. Kalau ada fitur baru yang mengumpulkan data,
> perbarui tabel ini **sebelum** rilis, bukan sesudah.

Terakhir diperiksa terhadap kode: 27 Juli 2026.

---

## 1. Ke mana data mengalir

| Tujuan | Lewat apa | Catatan |
|---|---|---|
| Backend M-BIS (infrastruktur penyedia di Indonesia) | `http` → `API_URL` | Semua data bisnis. Penyedia bertindak sebagai pemroses, bukan pihak ketiga penerima. **Jangan tulis "on-premise"** — hosting masih Coolify/VPS, pindah ke lingkungan Askrindo menyusul, dan klaim itu sengaja dibuang dari kebijakan privasi (§5). Deklarasi yang bertabrakan dengan kebijakan sendiri adalah temuan yang mudah |
| Google (Firebase Cloud Messaging) | `firebase_core`, `firebase_messaging` | Token perangkat **+ isi notifikasi**, yang memuat nama orang (mis. `AgentLicenseScheduler`) dan tampil di lockscreen |
| Google (Firebase Crashlytics) | `firebase_crashlytics` | Jejak crash, model perangkat, versi OS, dan **id akun saja** — lihat `core/observability/crash_reporter.dart`. Hanya aktif di build rilis |
| Microsoft (Entra ID) | `EntraAuthService` (HTTPS ke `login.microsoftonline.com`) | Hanya saat SSO dipakai; login utama tetap NIP + password lokal |
| **Google (Gemini)** | **Backend**, bukan aplikasi — `AssistantService` → `generativelanguage.googleapis.com` | **Lihat §2a.** Aliran data terbesar ke luar negeri |
| OpenStreetMap Foundation | `flutter_map` → `tile.openstreetmap.org` | Ubin peta. Server melihat **IP** dan koordinat ubin yang diminta |

Tidak ada Firebase Analytics, tidak ada SDK iklan, tidak ada SDK atribusi.
Crashlytics **ada** sejak 27 Juli 2026 (dinyalakan bersamaan dengan minify R8). Permission `AD_ID` dibuang eksplisit di manifest — jadi jawab
**"Tidak"** untuk semua pertanyaan iklan/tracking.

---

## 2a. Asisten AI — aliran data ke penyedia LLM

Fitur ini berjalan **di backend**, jadi tidak terlihat dari `pubspec.yaml` aplikasi —
tapi tetap harus dideklarasikan karena dipicu dari dalam aplikasi (layar Asisten AI).

Sumber: `AssistantContextService.buildUserPrompt()` di MBIS-Backend.

| | |
|---|---|
| **Dikirim** | Nama nasabah, bentuk badan usaha, kategori entitas, status BUMN, alamat, catatan kunjungan, katalog produk |
| **Tidak pernah dikirim** | NIK, NPWP, NIB, telepon, email, nomor rekening, dokumen unggahan |
| **Tujuan** | `generativelanguage.googleapis.com` (Google Gemini) — di luar Indonesia. Anthropic **tidak** dipakai; `approved-providers` dikunci ke `GEMINI` |
| **Pencarian web** | Aktivitas bawaan "Riset perusahaan di web" memakai `AiDataSource.WEB_SEARCH` → nama nasabah masuk ke kueri mesin pencari. Alamat **ditahan** khusus pada run jenis ini |
| **Pagar yang ada** | `approved-providers=GEMINI` (penyedia lain ditolak saat admin mencoba mengaktifkannya), kuota harian per user (`AiUsageGuard`) |
| **Status default** | `MBIS_ASSISTANT_ENABLED=false`; **akan diaktifkan di produksi** (keputusan 2026-07-27), jadi deklarasikan sebagai fitur aktif |

Ini satu-satunya aliran yang layak dijawab **"Shared = Ya"** di form Data safety,
karena data nasabah diserahkan ke sistem pihak ketiga untuk diproses.

---

## 2. Tabel per SDK

| SDK / Library | Data yang dikumpulkan | Dikirim ke | Terenkripsi saat transit | Bisa dihapus pengguna | Alasan |
|---|---|---|---|---|---|
| API backend M-BIS | Identitas pegawai (nama, NIP, jabatan, kantor), data nasabah yang diinput (nama, NIK, NPWP, alamat, kontak), data pipeline & premi, lokasi kunjungan, foto/dokumen unggahan | Server Askrindo | Ya (HTTPS wajib; cleartext ditolak di build prod) | Lewat permintaan penghapusan akun | Fungsi inti aplikasi |
| `firebase_messaging` | Token perangkat FCM, model & versi OS perangkat | Google | Ya | Ya — token dihapus saat logout (`DELETE /api/devices`) | Notifikasi pipeline, tugas, pengumuman |
| `Entra ID` (SSO) | Identitas korporat (UPN/email, object id) | Microsoft | Ya | Dikelola direktori korporat | Login SSO — **belum aktif**, login memakai NIP + kata sandi |
| `geolocator` | Koordinat GPS saat pencatatan kunjungan | Server Askrindo | Ya | Ikut permintaan hapus akun (dengan pengecualian arsip) | Bukti & pemetaan kunjungan |
| `flutter_map` | Alamat IP perangkat (implisit, oleh server ubin) | OpenStreetMap Foundation | Ya | — (tidak disimpan aplikasi) | Menampilkan peta kunjungan |
| `image_picker` / `file_picker` | Foto & dokumen yang **dipilih pengguna** | Server Askrindo | Ya | Ikut permintaan hapus akun | Lampiran kunjungan & dokumen nasabah |
| `flutter_secure_storage` | Access & refresh token | Tidak dikirim ke mana pun — hanya di perangkat (Android Keystore) | — | Terhapus saat logout/uninstall | Menjaga sesi login |
| `shared_preferences` | Preferensi UI non-sensitif | Lokal | — | Terhapus saat uninstall | Kenyamanan pemakaian |
| `printing` / `pdf` | Dokumen dibuat & dirender **di perangkat** | Tidak dikirim | — | — | Ekspor proforma kalkulator premi |
| `firebase_crashlytics` | Jejak crash, model & versi OS perangkat, id akun | Google | Ya | Ya | Melacak crash build rilis yang sudah diobfuskasi R8 |

---

## 3. Kategori yang harus dicentang di form

Berdasarkan tabel di atas:

- **Personal info** — nama, email, ID pengguna, nomor telepon, alamat *(data pegawai & nasabah)*
- **Personal info — dokumen identitas** — nomor KTP & NPWP Agen, NIK/NPWP/NIB nasabah
- **Financial info** — **nomor rekening bank Agen** (pencairan komisi) + data transaksi/premi
- **Location** — lokasi presisi *(GPS kunjungan)*
- **Photos and videos** — foto *(lampiran kunjungan)*
- **Files and docs** — dokumen *(unggahan dokumen nasabah)*
- **App activity** — interaksi in-app
- **Device or other IDs** — ID perangkat *(token FCM)*
- **App info and performance** — log kerusakan *(Crashlytics)*

Untuk setiap kategori: **Collected = Ya**, **Encrypted in transit = Ya**,
**Data deletion = Ya, lewat permintaan** (lampirkan `ACCOUNT_DELETION_URL`).

**Shared = Tidak** untuk semuanya, **kecuali** data nasabah yang dikirim ke penyedia
AI (§2a) — itu **Shared = Ya**. Pengiriman ke Google/Microsoft/OSM tetap "Tidak"
karena mereka memroses untuk fungsi aplikasi, bukan untuk kepentingan sendiri.
Jangan over-declare: mendeklarasikan "shared" yang tidak terjadi sama merepotkannya
dengan menyembunyikan yang terjadi.

Semua kategori di atas **wajib** untuk fungsi aplikasi (bukan opsional), kecuali
lokasi — yang hanya diminta ketika pengguna mencatat kunjungan.

---

## 3b. Jawaban form Play Console

Jawaban yang sudah ditetapkan (ID Iklan, enkripsi transit, metode pembuatan
akun, URL penghapusan data) beserta dasar verifikasinya ada di
**`DEPLOY-PLAYSTORE.md` §J** di root umbrella — satu tempat bersama detail
login reviewer dan langkah pra-submit, supaya tidak ada dua versi yang bisa
berbeda. Dokumen ini tetap jadi sumber **inventaris**-nya (§1–§3).

---

## 4. Yang perlu diperiksa ulang tiap menambah dependency

```bash
flutter pub deps --style=compact > deps.txt
grep -n "uses-permission" android/app/src/main/AndroidManifest.xml

# Permission yang ikut dari library (setelah merge). Flutter mengalihkan direktori
# build ke ROOT repo, bukan android/app/build — jadi path-nya seperti di bawah.
# Yang dibaca adalah packaged_manifests: itu manifest final yang benar-benar
# masuk AAB, setelah tools:node="remove" diterapkan.
(cd android && ./gradlew :app:processProdReleaseManifest)
grep -o 'uses-permission android:name="[^"]*"' \
  build/app/intermediates/packaged_manifests/prodRelease/processProdReleaseManifestForPackage/AndroidManifest.xml \
  | sort -u
```

Diverifikasi 27 Juli 2026 — hasilnya 11 permission, **tanpa `AD_ID`**, sehingga
pertanyaan "Apakah aplikasi Anda menggunakan ID iklan?" di Play Console dijawab
**Tidak**. Classpath runtime juga nihil `play-services-ads-identifier`,
`firebase-analytics`, dan SDK atribusi mana pun.

Kalau muncul permission baru atau SDK baru yang mengirim data keluar, tabel §2
dan centang §3 harus diperbarui sebelum rilis berikutnya.
