# assets/ssl — rantai sertifikat untuk certificate pinning

Direktori ini menampung rantai sertifikat (PEM / fullchain) yang dipakai
mekanisme pinning di `lib/src/network/ssl_pinning.dart`.

**Pinning WAJIB menyala untuk build yang menuju `mbis.askrindo.co.id`** — dan
alasannya bukan keamanan saja. Baca bagian berikut sebelum mematikannya.

`scripts/build-apk.*`, `scripts/build-aab.*`, dan `codemagic.yaml` kini mengisi
`SSL_PINNED_HOSTS` otomatis dari host `API_URL`, terbatas pada domain
`askrindo.co.id`.

---

## ⚠️ Server prod mengirim rantai TIDAK LENGKAP — pinning yang menambalnya

**Terverifikasi 3 Agustus 2026** terhadap `https://mbis.askrindo.co.id/v2`.

`mbis.askrindo.co.id` menyajikan **sertifikat leaf saja**. Intermediate *Sectigo
Public Server Authentication CA DV R36* dan *Root R46* tidak ikut dikirim,
padahal keduanya dibutuhkan untuk menyambung leaf ke root *USERTrust RSA* yang
ada di trust store perangkat.

Browser, `curl`, dan `openssl` di macOS menutupi lubang itu dengan menjemput
sertifikat issuer lewat **AIA** (URL di ekstensi *Authority Information Access*).
**Dart/BoringSSL tidak melakukannya.** Akibatnya:

| Klien | Hasil |
|---|---|
| `curl https://mbis.askrindo.co.id/v2/` | `HTTP 401`, `ssl_verify_result=0` — OS menjemput issuer sendiri |
| `openssl s_client` (trust store sistem saja) | `verify error:num=20:unable to get local issuer certificate` → `Verify return code: 21` |
| `openssl s_client -CAfile askrindo-fullchain-2026-2027.crt` | `Verify return code: 0 (ok)` |
| Flutter **tanpa** pinning | Gagal `HandshakeException: CERTIFICATE_VERIFY_FAILED` saat login |
| Flutter **dengan** pinning ke berkas ini | Berhasil — rantai bundled memasok intermediate yang hilang |

Inilah sebabnya aplikasi lama (`mb-mbis`) berjalan mulus dengan berkas `.crt`
yang **sama persis**: `lib/core/network/ssl_config.dart` di sana selalu memuat
rantai ini sejak start (`strict` menyala untuk staging & produksi), sehingga
intermediate-nya selalu tersedia. Repo ini sempat mengirim `SSL_PINNED_HOSTS`
kosong — jadi berjalan murni dengan trust store sistem, dan gagal.

Fingerprint SHA-256 leaf di server identik dengan leaf pada berkas ini
(`6B:A6:B0:D3:99:0C:26:3C:…:3B:1B:AB:D1`), jadi tidak ada ketidakcocokan
sertifikat — murni rantai yang tidak lengkap.

**Perbaikan ideal tetap di sisi server:** konfigurasikan reverse proxy / WAF agar
mengirim fullchain (leaf + R36 + R46), bukan leaf saja. Setelah itu klien tanpa
pinning pun terhubung. Sampai itu terjadi, pinning bukan sekadar pengerasan —
ia satu-satunya yang membuat aplikasi bisa login.

### Catatan pengamatan transien

Pada probe pertama hari yang sama, `10.10.1.242:443` sempat menyajikan
sertifikat **bawaan pabrik FortiWEB** (`CN=FortiWEB, O=Fortinet Inc.`,
self-signed, `verify=18`) untuk semua varian SNI, lalu kembali normal beberapa
menit kemudian. Kalau gejala itu muncul lagi, pinning **akan** menolaknya — dan
memang seharusnya begitu. Jangan menambahkan sertifikat FortiWEB tersebut ke
berkas rantai: private key sertifikat bawaan FortiWeb identik pada semua unit
dan beredar di firmware publik, sehingga menjadikannya trust anchor berarti siapa
pun yang memiliki firmware itu dapat memalsukan koneksi ke aplikasi.

`mbis.askrindo.co.id` juga memakai split-horizon DNS: `10.10.1.242` dari jaringan
kantor, `9.154.64.93` dari internet publik. Pastikan kedua jalur menyajikan
sertifikat yang sama sebelum rilis.

Kegagalan verifikasi kini muncul sebagai `TlsTrustException`
(`lib/src/network/ssl_pinning.dart`) dengan pesan "sertifikat server tidak
tepercaya", bukan `CERTIFICATE_VERIFY_FAILED` mentah yang mudah disalahartikan
sebagai server mati. Uraian teknisnya tercetak ke log lewat
`TlsTrustException.details`.

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

`scripts/build-aab.*`, `scripts/build-apk.*`, dan `codemagic.yaml` mengisinya
sendiri dari host `API_URL` selama host itu berakhiran `askrindo.co.id`:

```bash
scripts/build-aab.sh https://mbis.askrindo.co.id/v2
# → --dart-define=SSL_PINNED_HOSTS=mbis.askrindo.co.id
```

Setara bila dijalankan manual:

```bash
flutter build appbundle --release --flavor prod \
  --dart-define=API_URL=https://mbis.askrindo.co.id/v2 \
  --dart-define=SSL_PINNED_HOSTS=mbis.askrindo.co.id
```

Untuk mematikan (hanya bila server sudah dipastikan mengirim fullchain):
`SSL_PINNED_HOSTS="" scripts/build-aab.sh ...` pada shell, atau
`set SSL_PINNED_HOSTS=off` pada Windows.

### Menguji hipotesis rantai di mesin pengembang

macOS **tidak bisa** dipakai untuk membuktikan kegagalannya: Secure Transport
menjemput sertifikat issuer lewat AIA dan menyimpannya di Keychain, sehingga
`curl` maupun `dart:io` di Mac tetap berhasil walau server hanya mengirim leaf.
Yang mereproduksi kondisi Android/iOS adalah verifikasi tanpa AIA:

```bash
# Gagal — hanya root store, tanpa penjemputan issuer (perilaku perangkat)
openssl s_client -servername mbis.askrindo.co.id \
  -connect mbis.askrindo.co.id:443 </dev/null 2>&1 | grep "Verify return code"

# Berhasil — rantai bundled memasok intermediate yang hilang
openssl s_client -servername mbis.askrindo.co.id \
  -connect mbis.askrindo.co.id:443 \
  -CAfile assets/ssl/askrindo-fullchain-2026-2027.crt </dev/null 2>&1 \
  | grep "Verify return code"
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
