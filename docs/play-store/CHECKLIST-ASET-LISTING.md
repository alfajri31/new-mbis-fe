# Checklist Aset Listing Play Store — status & lokasi berkas

Semua path relatif dari akar repo `fe-new-mbis/`. ✅ = siap dipakai, ✍️ = perlu
tindakan Anda.

## Aset teks

| Kolom Play Console | Status | Ambil dari |
|---|---|---|
| Nama aplikasi (maks 30) | ✅ dibuat | [`docs/play-store/listing-teks.md`](listing-teks.md) — rekomendasi **M-BIS Askrindo** (sekarang terisi "MBIS") |
| Deskripsi singkat (maks 80) | ✅ dibuat | `listing-teks.md` |
| Deskripsi lengkap (maks 4000) | ✅ dibuat | `listing-teks.md` |

## Aset visual umum

| Kolom | Status | Berkas |
|---|---|---|
| Ikon aplikasi 512×512 (PNG, ≤1 MB) | ✅ | [`docs/play-store/icon-512.png`](icon-512.png) |
| Gambar fitur 1024×500 | ✅ dibuat | [`docs/play-store/feature-graphic-1024x500.png`](feature-graphic-1024x500.png) |
| Video (YouTube) | — | opsional, dilewati |

## Screenshot ponsel (min 2, ideal ≥4 untuk promosi)

Semua **data demo palsu** (akun DEMO001, kantor demo) — **tanpa PII nyata**. Diambil
dari HP asli, status bar bersih. **Tersedia 2 varian**, keduanya 9:16 (1350×2400):

| Folder | Isi | Untuk |
|---|---|---|
| **`screenshots-desain/`** ⭐ | Versi marketing: latar gradien brand + headline per fitur + bingkai perangkat | **Rekomendasi diunggah ke Play Store** |
| `screenshots/` | Screenshot polos, patuh 9:16 (margin latar app) | Kalau ingin tampilan mentah tanpa desain |

> Screenshot mentah 1080×2400 (rasio 2,22:1) sudah **dihapus** — rasionya melebihi
> batas Play Store sehingga tidak pernah bisa dipakai. Bila suatu saat perlu lagi,
> ambil ulang dari perangkat.

| # | Layar | Berkas desain |
|---|---|---|
| 0 | Login / intro brand | [`screenshots-desain/00-login.png`](screenshots-desain/00-login.png) |
| 1 | Dashboard — "Pantau Kinerja" | [`screenshots-desain/01-dashboard.png`](screenshots-desain/01-dashboard.png) |
| 2 | Daftar nasabah — "Kelola Nasabah" | [`screenshots-desain/02-daftar-nasabah.png`](screenshots-desain/02-daftar-nasabah.png) |
| 3 | Detail nasabah — "Profil Lengkap" | [`screenshots-desain/03-detail-nasabah.png`](screenshots-desain/03-detail-nasabah.png) |
| 4 | Detail pipeline — "Lacak Pipeline" | [`screenshots-desain/04-detail-pipeline.png`](screenshots-desain/04-detail-pipeline.png) |
| 5 | GPS kunjungan — "Kunjungan Terverifikasi" | [`screenshots-desain/05-gps-kunjungan.png`](screenshots-desain/05-gps-kunjungan.png) |
| 6 | Tools — "Alat Bantu Lapangan" | [`screenshots-desain/06-tools.png`](screenshots-desain/06-tools.png) |

> **Aspek rasio.** Layar HP asli 1080×2400 = **2,22:1**, melebihi batas Play Store
> (maks 9:16 = 1,78:1) → berisiko ditolak. Semua versi desain & polos sudah **9:16
> (1350×2400)**, aman.
>
> **Desainnya dibangkitkan skrip** (warna & font brand M-BIS). Untuk mengubah
> headline/warna, sesuaikan blok `CAP` di skrip pembuatnya dan jalankan ulang —
> atau minta saya.

## Screenshot tablet (7" & 10") — dari web M-BIS (layout lebar)

Diambil dari **Flutter Web** (viewport 1920×1080, layout desktop/tablet dengan
side-nav), login **DEMO001**, data demo, **tanpa PII**. Web tidak punya status/gesture
bar sistem, jadi tak ada yang perlu di-crop. Desain **landscape 2560×1440 (16:9)** —
valid untuk tablet 7" (320–3840px) maupun 10" (1080–7680px).

| # | Layar | Berkas desain |
|---|---|---|
| 1 | Dashboard | [`screenshots-tablet/01-dashboard.png`](screenshots-tablet/01-dashboard.png) |
| 2 | Daftar nasabah | [`screenshots-tablet/02-daftar-nasabah.png`](screenshots-tablet/02-daftar-nasabah.png) |
| 3 | Detail nasabah | [`screenshots-tablet/03-detail-nasabah.png`](screenshots-tablet/03-detail-nasabah.png) |
| 4 | GPS kunjungan (peta) | [`screenshots-tablet/04-gps-kunjungan.png`](screenshots-tablet/04-gps-kunjungan.png) |
| 5 | Tools | [`screenshots-tablet/05-tools.png`](screenshots-tablet/05-tools.png) |

Versi asli 1920×1080 tanpa desain sudah dihapus — yang di atas sudah final. Untuk kolom
tablet **7" dan 10"**, gunakan berkas yang sama (rasio & ukuran memenuhi keduanya).

## Yang MASIH perlu tindakan Anda ✍️

| Item | Kenapa | Tindakan |
|---|---|---|
| ~~**Akun demo DEMO001 di PROD**~~ ✅ | Reviewer login pakai DEMO001 di prod | **SUDAH ADA & aktif di prod** (diverifikasi). Isi kolom **App access**: NIP `DEMO001`, password **`Demo#2026.`** (⚠️ **ADA titik di akhir**), role RM, tanpa paksa ganti sandi |
| **URL kebijakan & hapus akun** | ✅ sudah live & terverifikasi | `https://mbis.askrindo.co.id/app/kebijakan-privasi` & `/app/hapus-akun` |
| Video, Chromebook, XR | opsional | dilewati |

## Catatan

- **Nama aplikasi**: pertimbangkan ubah "MBIS" → "M-BIS Askrindo" agar konsisten
  dengan tampilan di aplikasi.
- Screenshot ini dibuat dari **build debug menunjuk backend lokal** (UI identik
  dengan rilis; `debugShowCheckedModeBanner=false` jadi tanpa ribbon). Begitu
  DEMO001 hidup di prod, boleh diganti dengan screenshot dari aplikasi rilis bila
  mau — tapi yang ini sudah layak pakai.
