# assets/ssl — rantai sertifikat untuk certificate pinning

Direktori ini menampung rantai sertifikat (PEM / fullchain) yang dipakai
mekanisme pinning di `lib/src/network/ssl_pinning.dart`.

**Saat ini kosong, dan pinning nonaktif.** Aplikasi berjalan normal tanpa berkas
apa pun di sini.

---

## Kapan berkas ini diperlukan

Hanya ketika pinning dinyalakan, yaitu saat build disertai
`--dart-define=SSL_PINNED_HOSTS=...`. Tanpa dart-define tersebut, direktori ini
tidak pernah dibaca.

## Target yang direncanakan

| Item | Nilai |
|---|---|
| Host produksi | `mbis.askrindo.co.id` |
| Berkas yang diharapkan | `assets/ssl/askrindo-fullchain-2026-2027.crt` |

Nama berkas tersebut sudah menjadi nilai bawaan `SSL_CERT_ASSET`, sehingga hanya
`SSL_PINNED_HOSTS` yang perlu diisi saat menyalakan pinning.

Perintah build produksi setelah berkas tersedia:

```bash
flutter build appbundle --release --flavor prod \
  --dart-define=API_URL=https://mbis.askrindo.co.id \
  --dart-define=SSL_PINNED_HOSTS=mbis.askrindo.co.id
```

## Cara menambahkan

1. Peroleh rantai sertifikat **lengkap** (leaf + seluruh intermediate) dari host
   yang akan dikunci. Dapat diambil langsung dari server:

   ```bash
   openssl s_client -showcerts -servername mbis.askrindo.co.id \
     -connect mbis.askrindo.co.id:443 </dev/null \
     | sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p' \
     > askrindo-fullchain-2026-2027.crt
   ```

2. Simpan pada direktori ini. Gunakan nama lain hanya bila disertai
   `--dart-define=SSL_CERT_ASSET=assets/ssl/<nama>.crt`.

3. Pastikan `pubspec.yaml` mendaftarkan direktori ini pada bagian `assets:`
   (sudah dilakukan).

4. Verifikasi bahwa sertifikat benar-benar mencakup host tujuan. Nilai `CN` saja
   tidak cukup — yang menentukan adalah Subject Alternative Name:

   ```bash
   openssl x509 -in askrindo-fullchain-2026-2027.crt -noout \
     -subject -issuer -dates -ext subjectAltName
   ```

   Ini pemeriksaan wajib, bukan formalitas. Rancangan awal menyebut sertifikat
   ber-`CN=askrindo.co.id`, sedangkan host tujuan adalah `mbis.askrindo.co.id`.
   Nama domain induk **tidak** otomatis mencakup subdomain: keluaran
   `subjectAltName` harus memuat `*.askrindo.co.id` atau `mbis.askrindo.co.id`
   secara eksplisit. Bila tidak, handshake akan gagal setelah pinning menyala.

5. Periksa apakah domain menyajikan sertifikat yang sama dari dalam dan luar
   jaringan kantor. `mbis.askrindo.co.id` tercatat memakai split-horizon DNS
   (`10.10.1.242` dari kantor, `9.154.64.93` dari internet publik — lihat
   `docs/HALAMAN-KEBIJAKAN-PUBLIK.md`). Bila kedua jalur menyajikan sertifikat
   berbeda, pinning ke salah satunya akan memutus koneksi pengguna pada jalur
   yang lain — gejalanya "aplikasi jalan di kantor, gagal di lapangan".

   ```bash
   # Bandingkan sidik jari dari kedua jalur
   openssl s_client -servername mbis.askrindo.co.id -connect 10.10.1.242:443 \
     </dev/null 2>/dev/null | openssl x509 -noout -fingerprint -sha256
   openssl s_client -servername mbis.askrindo.co.id -connect 9.154.64.93:443 \
     </dev/null 2>/dev/null | openssl x509 -noout -fingerprint -sha256
   ```

## Hal yang perlu diperhatikan

**Rantai wajib lengkap.** Trust store dipersempit sehingga hanya berkas ini yang
menjadi trust anchor. Bila intermediate tidak disertakan, handshake gagal.

**Staging dan produksi umumnya berbeda.** Staging pada Coolify memakai sertifikat
yang diterbitkan otomatis oleh reverse proxy, sedangkan produksi pada server
internal memakai sertifikat korporat. Satu berkas belum tentu melayani keduanya;
gunakan `SSL_CERT_ASSET` untuk memisahkan bila perlu.

**Perhatikan masa berlaku.** Setelah sertifikat kedaluwarsa, aplikasi terpasang
yang mem-pin sertifikat tersebut tidak dapat lagi terhubung sampai pengguna
memperbarui aplikasi. Catat tanggal kedaluwarsa dan jadwalkan rilis sebelum
tanggal tersebut.

**Berkas ini bukan rahasia.** Sertifikat server bersifat publik dan disajikan ke
setiap klien yang terhubung. Aman untuk disimpan dalam kontrol versi.
