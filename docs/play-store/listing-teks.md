# Teks Listing Play Store — siap salin

Angka di kurung = jumlah karakter (batas Play Console). Semua di bawah batas.
Karena aplikasi **internal** (bukan untuk publik umum), teks sengaja jujur soal itu
supaya tidak memicu pertanyaan reviewer. Silakan sesuaikan gaya bila divisi mau.

---

## Nama aplikasi (maks 30)

Pilih salah satu:

- `M-BIS Askrindo`  (14) ← rekomendasi
- `M-BIS — Askrindo`  (16)
- `M-BIS`  (5)

> Sekarang terisi "MBIS". Disarankan pakai tanda hubung "M-BIS" agar konsisten
> dengan tampilan di dalam aplikasi (splash, login, profil semuanya "M-BIS").

---

## Deskripsi singkat (maks 80)

```
Aplikasi internal pemasaran dan bisnis PT Askrindo untuk tim di lapangan.
```
(72)

Alternatif:
```
Sistem informasi pemasaran & bisnis internal PT Asuransi Kredit Indonesia.
```
(73)

---

## Deskripsi lengkap (maks 4000)

```
M-BIS (Marketing/Business Information System) adalah aplikasi INTERNAL PT Asuransi Kredit Indonesia (Persero) — Askrindo. Aplikasi ini digunakan oleh pegawai serta Agen dan Tenaga Pemasar resmi untuk mengelola aktivitas pemasaran penjaminan dan asuransi di lapangan.

Aplikasi ini BUKAN untuk masyarakat umum. Tidak ada pendaftaran mandiri — seluruh akun dibuat oleh Administrator, dan akun Agen didaftarkan oleh Relationship Manager. Anda memerlukan akun resmi Askrindo untuk masuk.

FITUR UTAMA

• Pipeline & Nasabah — Catat dan kelola calon nasabah beserta tahapan pipeline penjaminan, dari prospek hingga terbit polis.

• Kunjungan Lapangan — Rekam kunjungan nasabah lengkap dengan lokasi GPS dan foto dokumentasi. Lokasi hanya diambil saat Anda aktif merekam kunjungan.

• Target & Realisasi — Pantau pencapaian target premi terhadap realisasi, dengan rincian per kategori produk dan per bulan.

• Dashboard Kinerja — Ringkasan kinerja sesuai peran dan cakupan kantor Anda: nasional, wilayah, cabang, hingga per Relationship Manager.

• Manajemen Agen — Administrasi data keagenan, lisensi, dan perjanjian kerja sama.

• Notifikasi — Pengingat jadwal kunjungan, pengumuman, dan informasi operasional.

• Asisten AI — Bantuan analisis calon nasabah dan rekomendasi produk (opsional).

• Ekspor Laporan — Unduh data pipeline, kunjungan, dan kinerja untuk pelaporan.

PERAN PENGGUNA

Divisi Penjaminan (DPJ), Regional Office (RO), Branch Manager (BM), Kepala Unit Penjaminan (KUP), Relationship Manager (RM), Agen, dan Administrator. Setiap peran hanya dapat mengakses data sesuai kewenangan dan penempatan kantornya.

KEAMANAN & PRIVASI

• Autentikasi berbasis token dengan masa berlaku terbatas.
• Pembatasan akses per kantor dan per peran, dipaksakan di sisi server.
• Komunikasi terenkripsi HTTPS; versi produksi menolak koneksi tanpa enkripsi.
• Token disimpan pada penyimpanan terenkripsi perangkat (Android Keystore).

PENGHAPUSAN AKUN & DATA

Permintaan penghapusan akun diproses secara terverifikasi oleh Divisi Pengelolaan Jaringan, karena akun dibuat oleh Administrator (bukan pendaftaran mandiri). Langkah dan ketentuannya tersedia pada halaman permintaan penghapusan akun serta kebijakan privasi yang tertaut di listingan ini.

Dikelola oleh PT Asuransi Kredit Indonesia (Persero), Jakarta.
```

> Perkiraan ±1.900 karakter — jauh di bawah 4.000. Boleh dipangkas/ditambah.
> Jangan menyebut fitur yang belum aktif sebagai sudah ada (mis. SSO Microsoft
> masih disiapkan; sengaja tidak dicantumkan).

---

## Catatan penting untuk reviewer (bukan bagian listing)

- **App access**: aplikasi butuh login. Isi kolom "Akses aplikasi" (App access)
  dengan akun demo yang **sudah aktif di prod**:
  - NIP: `DEMO001`
  - Password: `Demo#2026.` — ⚠️ **ADA titik di akhir**, jangan sampai tertinggal
  - Role RM, data terisolasi (tanpa PII), tanpa paksa ganti sandi.
  - JANGAN pakai akun ADMIN (cakupan global = risiko PII).
- **Data safety**: isian formulir mengikuti `docs/DATA-SAFETY.md`.
