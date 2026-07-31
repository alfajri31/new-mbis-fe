# Keamanan Transport (TLS) — Certificate Pinning

Dokumen ini menjelaskan mekanisme certificate pinning pada aplikasi M-BIS: cara
kerjanya, cara menyalakannya, batasannya per platform, serta perlindungan
pengganti untuk kanal yang tidak dapat menerapkan pinning.

| | |
|---|---|
| **Status** | Kerangka terpasang, **pinning nonaktif** |
| **Implementasi** | `lib/src/network/ssl_pinning.dart` beserta dua berkas pendampingnya |
| **Aset** | `assets/ssl/` — lihat [README direktori tersebut](../assets/ssl/README.md) |
| **Cakupan** | Android dan iOS. Web tidak didukung — lihat [§4](#4-batasan-platform) |

---

## Daftar Isi

1. [Ringkasan](#1-ringkasan)
2. [Model Ancaman](#2-model-ancaman)
3. [Arsitektur](#3-arsitektur)
4. [Batasan Platform](#4-batasan-platform)
5. [Perlindungan Kanal Web](#5-perlindungan-kanal-web)
6. [Konfigurasi](#6-konfigurasi)
7. [Prasyarat Sebelum Diaktifkan](#7-prasyarat-sebelum-diaktifkan)
8. [Prosedur Perpanjangan Sertifikat](#8-prosedur-perpanjangan-sertifikat)
9. [Keputusan Desain](#9-keputusan-desain)
10. [Pemecahan Masalah](#10-pemecahan-masalah)

---

## 1. Ringkasan

Secara bawaan, aplikasi mempercayai sekitar 150 Certificate Authority publik yang
terpasang pada sistem operasi. Certificate pinning mempersempit kepercayaan
tersebut menjadi satu rantai sertifikat tertentu, sehingga sertifikat yang
diterbitkan CA lain ditolak pada tahap handshake TLS — sebelum satu byte
permintaan terkirim.

Mekanisme ini telah disiapkan namun **belum diaktifkan**. Tanpa
`--dart-define=SSL_PINNED_HOSTS`, aplikasi berperilaku identik dengan kondisi
sebelum mekanisme ini ditambahkan.

Penundaan aktivasi bersifat disengaja. Sertifikat lingkungan staging (Coolify)
dan produksi (server internal) berbeda, dan konfigurasi produksi belum final.
Mengunci aplikasi ke sertifikat yang masih berpotensi berubah menimbulkan risiko
pemutusan layanan pada perangkat yang telah terpasang, yang hanya dapat
dipulihkan melalui pembaruan aplikasi.

---

## 2. Model Ancaman

### 2.1 Yang dimitigasi

Penerbitan sertifikat tidak sah untuk domain Askrindo oleh CA publik — baik
karena CA tersebut disusupi, keliru melakukan validasi, maupun tunduk pada
paksaan pihak ketiga. Tanpa pinning, sertifikat semacam itu diterima aplikasi
sebagai sah dan memungkinkan penyadapan lalu lintas terenkripsi.

### 2.2 Yang tidak dimitigasi

| Ancaman | Keterangan |
|---|---|
| Kompromi pada server | Pinning memverifikasi identitas server, bukan integritasnya |
| Perangkat yang di-root atau di-jailbreak | Pemilik perangkat dapat memodifikasi berkas aplikasi |
| Analisis lalu lintas | Metadata koneksi tetap terlihat |
| Serangan pada kanal web | Lihat [§4](#4-batasan-platform) |

### 2.3 Risiko yang ditimbulkan

Pinning memindahkan risiko, bukan menghilangkannya. Ketergantungan pada satu
rantai sertifikat berarti perubahan pada rantai tersebut — perpanjangan dengan CA
berbeda, pergantian penyedia, atau kedaluwarsa — memutus koneksi seluruh
perangkat yang telah terpasang sampai pengguna memperbarui aplikasi.

Konsekuensi ini harus diterima secara sadar dan dikelola melalui prosedur pada
[§8](#8-prosedur-perpanjangan-sertifikat).

---

## 3. Arsitektur

### 3.1 Berkas

| Berkas | Peran |
|---|---|
| `lib/src/network/ssl_pinning.dart` | Konfigurasi dan klien HTTP bersama. Bebas dari dependensi platform |
| `lib/src/network/ssl_pinning_io.dart` | Implementasi Android dan iOS, menggunakan `dart:io` |
| `lib/src/network/ssl_pinning_stub.dart` | Implementasi Web — tanpa pinning |

Pemilihan implementasi dilakukan melalui *conditional import* pada berkas pertama.
Pemisahan ini diperlukan karena `dart:io` tidak tersedia di browser; tanpa
pemisahan tersebut, build web gagal dikompilasi.

### 3.2 Penegakan

Penegakan bertumpu pada `SecurityContext(withTrustedRoots: false)`. Trust store
bawaan sistem dikeluarkan sepenuhnya untuk host yang dikunci, sehingga hanya
rantai sertifikat yang disertakan dalam aplikasi yang menjadi trust anchor.

### 3.3 Perutean per host

Pinning diterapkan **per host**, bukan secara global. Ketentuan ini bersifat wajib
karena aplikasi menghubungi empat pihak dengan otoritas sertifikat berbeda:

| Host | Fungsi | Perlakuan |
|---|---|---|
| `mbis.askrindo.co.id` | REST API M-BIS | Trust store terbatas |
| `nominatim.openstreetmap.org` | Pencarian dan konversi alamat | CA sistem |
| `api.frankfurter.dev` | Kurs mata uang | CA sistem |
| `login.microsoftonline.com` | SSO Microsoft Entra ID | CA sistem |

Penggantian trust store secara global akan memutus ketiga layanan terakhir.
Kelas `_HostRoutingClient` merutekan setiap permintaan ke klien yang sesuai
berdasarkan host tujuan.

### 3.4 Klien bersama

`AppHttpClient.instance` menyediakan satu instans `http.Client` untuk seluruh
aplikasi. Sebelumnya setiap `ApiClient` membuat klien tersendiri, yang berarti
connection pool TLS dibangun ulang pada setiap layar dan pinning hanya berlaku
pada kelas yang kebetulan diperbarui.

---

## 4. Batasan Platform

| Platform | Pinning | Keterangan |
|---|---|---|
| Android | Didukung | Aktif saat dikonfigurasi |
| iOS | Didukung | Aktif saat dikonfigurasi |
| Web | **Tidak didukung** | Lihat penjelasan di bawah |

Certificate pinning tidak dapat diterapkan pada browser. `SecurityContext` dan
`HttpClient` berasal dari `dart:io` yang tidak tersedia, dan verifikasi TLS
sepenuhnya berada dalam kendali browser tanpa titik sisip bagi aplikasi.

> Keterbatasan ini bukan berasal dari Flutter. Browser pernah menyediakan
> mekanisme setara bernama HTTP Public Key Pinning (HPKP). Google Chrome
> menghapusnya pada 2018 karena kesalahan konfigurasi menyebabkan sejumlah situs
> tidak dapat diakses pengunjungnya sendiri dalam jangka waktu lama tanpa jalur
> pemulihan. Platform web secara sengaja menempuh pendekatan berbeda.

Implementasi stub mengembalikan klien HTTP standar dan mencatat pesan informatif
apabila konfigurasi pinning tetap disertakan pada build web. Perilaku ini
disengaja agar satu perintah build dapat menggunakan dart-define yang sama untuk
seluruh target.

---

## 5. Perlindungan Kanal Web

Karena pinning tidak tersedia di browser, perlindungan setara diterapkan pada
lapis DNS dan server. Ketiga langkah berikut berada di luar repositori aplikasi
dan memerlukan koordinasi dengan tim infrastruktur.

### 5.1 CAA record — prioritas tertinggi

Data DNS yang membatasi CA mana saja yang berhak menerbitkan sertifikat untuk
domain Askrindo:

```
askrindo.co.id.  IN  CAA  0 issue "sectigo.com"
```

| Aspek | Certificate pinning | CAA record |
|---|---|---|
| Melindungi kanal web | Tidak | Ya |
| Melindungi Android dan iOS | Ya | Ya |
| Memerlukan rilis aplikasi | Setiap pergantian sertifikat | Tidak pernah |
| Memiliki batas kedaluwarsa | Ya | Tidak |
| Upaya penerapan | Perubahan kode dan rilis tiga platform | Satu data DNS |

CAA memblokir penerbitan sertifikat tidak sah pada sumbernya, sehingga menutup
ancaman yang sama dengan cakupan lebih luas dan risiko operasional lebih rendah.
Apabila hanya satu langkah yang dapat dilakukan, langkah ini yang paling
bernilai.

### 5.2 Certificate Transparency monitoring

Seluruh sertifikat yang diterbitkan CA publik wajib dicatat pada log terbuka.
Berlangganan notifikasi atas domain Askrindo memungkinkan deteksi penerbitan
tidak sah dalam hitungan jam. Layanan pemantauan tersedia tanpa biaya, antara
lain melalui crt.sh dan Cloudflare.

### 5.3 HTTP Strict Transport Security

Header `Strict-Transport-Security` memaksa browser menggunakan HTTPS sehingga
koneksi tidak dapat diturunkan ke HTTP.

> **Status saat ini.** Header ini **belum ada** pada `nginx.conf`. Demikian pula
> `Content-Security-Policy`. Selain itu, tiga header keamanan yang telah
> didefinisikan pada level `server` — `X-Content-Type-Options`,
> `X-Frame-Options`, dan `Referrer-Policy` — tidak terkirim pada dokumen HTML.
> Penyebabnya, blok `location = /index.html` memiliki direktif `add_header`
> tersendiri, dan Nginx menghentikan pewarisan `add_header` dari level atas
> ketika sebuah `location` mendefinisikannya. Karena SPA fallback menyajikan
> `/index.html`, seluruh halaman aplikasi tidak menerima header tersebut.

---

## 6. Konfigurasi

Seluruh konfigurasi diteruskan melalui `--dart-define`. Tidak terdapat nama host
maupun lintasan berkas yang ditanam pada kode.

| Variabel | Nilai bawaan | Keterangan |
|---|---|---|
| `SSL_PINNED_HOSTS` | Kosong | Daftar host dipisah koma. Kosong berarti pinning nonaktif |
| `SSL_CERT_ASSET` | `assets/ssl/askrindo-fullchain-2026-2027.crt` | Lintasan aset rantai sertifikat |

### 6.1 Contoh penggunaan

```bash
# Produksi — setelah berkas sertifikat tersedia
flutter build appbundle --release --flavor prod \
  --dart-define=API_URL=https://mbis.askrindo.co.id \
  --dart-define=SSL_PINNED_HOSTS=mbis.askrindo.co.id

# Beberapa host sekaligus
--dart-define=SSL_PINNED_HOSTS=mbis.askrindo.co.id,mbis-staging.askrindo.co.id

# Berkas sertifikat berbeda
--dart-define=SSL_CERT_ASSET=assets/ssl/staging-chain.crt
```

### 6.2 Perilaku gagal-tertutup

Apabila `SSL_PINNED_HOSTS` terisi namun aset sertifikat tidak dapat dimuat,
`AppHttpClient.initialize()` melemparkan `StateError` pada saat startup.

Perilaku ini dipilih secara sadar. Keberadaan aset bersifat deterministik pada
saat build, sehingga kesalahan konfigurasi pasti terdeteksi pada peluncuran
pertama build mana pun dan tidak mungkin mencapai pengguna tanpa terdeteksi.
Alternatifnya — menonaktifkan pinning secara diam-diam — menghasilkan build
rilis yang tampak normal namun tanpa perlindungan sama sekali.

### 6.3 Integrasi dengan skrip build

`scripts/build-aab.sh` **belum** menyertakan dart-define pinning. Penambahan
dilakukan bersamaan dengan masuknya berkas sertifikat; menambahkannya lebih awal
akan menyebabkan seluruh build rilis gagal akibat perilaku pada [§6.2](#62-perilaku-gagal-tertutup).

---

## 7. Prasyarat Sebelum Diaktifkan

Seluruh butir berikut harus terpenuhi sebelum pinning dinyalakan pada build
produksi.

### 7.1 Jalur akses perangkat lapangan

Produksi direncanakan berada pada server internal perusahaan, sementara
Relationship Manager dan Agen mengakses aplikasi dari jaringan seluler di luar
kantor. Perlu dipastikan mekanisme yang menjembatani keduanya — reverse proxy
pada DMZ, VPN, atau publikasi langsung — karena mekanisme tersebut menentukan
sertifikat mana yang sesungguhnya diterima aplikasi.

> Sumber unduhan aplikasi (Google Play atau App Store) tidak memengaruhi hal ini.
> Yang menentukan adalah jaringan tempat perangkat berada saat digunakan.

### 7.2 Konsistensi sertifikat antar jalur

Berdasarkan `docs/HALAMAN-KEBIJAKAN-PUBLIK.md`, domain `mbis.askrindo.co.id`
menggunakan split-horizon DNS:

| Sumber resolusi | Alamat |
|---|---|
| Jaringan kantor | `10.10.1.242` — alamat privat RFC1918 |
| Resolver publik | `9.154.64.93` — alamat publik |

Apabila kedua jalur menyajikan sertifikat berbeda, pinning terhadap salah satunya
memutus koneksi pengguna pada jalur lain. Gejalanya sulit didiagnosis: aplikasi
berfungsi di kantor namun gagal di lapangan, atau sebaliknya.

Verifikasi dilakukan dengan membandingkan sidik jari sertifikat dari kedua
alamat — perintah tersedia pada [`assets/ssl/README.md`](../assets/ssl/README.md).

### 7.3 Sertifikat diterbitkan CA resmi

Dokumen yang sama mencatat sertifikat domain tersebut sebagai **self-signed**.
Selama kondisi ini berlaku:

- CAA record dan Certificate Transparency tidak berlaku, karena tidak melibatkan CA
- Browser menampilkan peringatan keamanan pada kanal web
- Halaman kebijakan privasi tidak dapat diakses reviewer Google Play

Penggantian dengan sertifikat dari CA resmi merupakan prasyarat, dan nilainya
lebih besar dibandingkan pinning itu sendiri.

### 7.4 Cakupan Subject Alternative Name

Rancangan awal merujuk sertifikat dengan `CN=askrindo.co.id`, sedangkan host
tujuan adalah `mbis.askrindo.co.id`. Nama domain induk tidak otomatis mencakup
subdomain. Keluaran `subjectAltName` harus memuat `*.askrindo.co.id` atau
`mbis.askrindo.co.id` secara eksplisit.

---

## 8. Prosedur Perpanjangan Sertifikat

Nama berkas bawaan memuat rentang tahun (`askrindo-fullchain-2026-2027.crt`).
Setiap perpanjangan menghasilkan berkas dengan nama berbeda.

1. Peroleh rantai sertifikat baru secara lengkap, termasuk seluruh intermediate.
2. Verifikasi masa berlaku dan cakupan SAN.
3. Simpan pada `assets/ssl/`.
4. Perbarui nilai bawaan `SSL_CERT_ASSET` pada `ssl_pinning.dart`, atau
   sertakan `--dart-define=SSL_CERT_ASSET` pada perintah build.
5. Terbitkan versi aplikasi baru sebelum sertifikat lama kedaluwarsa.

> **Perencanaan rilis.** Perangkat yang masih menjalankan versi lama akan
> kehilangan konektivitas setelah sertifikat yang di-pin kedaluwarsa. Jadwalkan
> rilis dengan tenggang memadai, dan catat tanggal kedaluwarsa pada kalender
> operasional.

Kelalaian memperbarui lintasan aset menyebabkan build gagal pada saat startup —
bukan berjalan tanpa proteksi — sesuai [§6.2](#62-perilaku-gagal-tertutup).

---

## 9. Keputusan Desain

### 9.1 Menggunakan `package:http`, bukan `dio`

Aplikasi telah menggunakan `package:http`. Menambahkan `dio` semata-mata untuk
pinning akan menghadirkan dua klien HTTP dalam satu basis kode, atau menuntut
penulisan ulang `ApiClient` secara menyeluruh.

**Konsekuensi.** Rancangan awal menerapkan dua lapis: pembatasan trust anchor,
serta pemeriksaan bahwa sertifikat leaf diterbitkan oleh intermediate tertentu.
Lapis kedua memerlukan kait `validateCertificate` yang hanya tersedia pada `dio`;
`package:http` tidak menyediakan mekanisme untuk memeriksa sertifikat peer pada
handshake yang berhasil.

Dampaknya terbatas. Pembatasan trust anchor ke satu rantai telah menutup ancaman
utama. Penyempitan tambahan ke satu intermediate mempersempit permukaan serangan
lebih jauh, namun dengan biaya berupa dependensi tambahan.

### 9.2 Pinning pada tingkat rantai, bukan sidik jari sertifikat

Sertifikat leaf tidak dikunci berdasarkan hash. Perpanjangan rutin oleh CA yang
sama karenanya tidak memutus aplikasi versi lama.

Nilai SPKI SHA-256 dari rancangan awal dicatat berikut ini untuk keperluan audit
dan kemungkinan migrasi ke pinning berbasis SPKI. **Nilai-nilai ini belum
diverifikasi terhadap sertifikat produksi** karena berkas terkait belum tersedia.

```
leaf         IcKQSQbpsy431D5xm5dFgx9YceurOcoX7pXM9WFJoOM=
Sectigo R36  a9khLOZJxlnJyrxstg/P+seiDCm+Yf3OsrXyFocBaI0=
Sectigo R46  Douxi77vs4G+Ib/BogbTFymEYq0QSFXwSgVCaZcI09Q=
USERTrust    x4QzPSC810K5/cMjb05Qm4k3Bw5zBn4lTdO/nEW/Td4=
```

### 9.3 Nonaktif secara bawaan

Diaktifkan melalui dart-define, bukan menyala secara otomatis. Konfigurasi
staging dan produksi berbeda, dan konfigurasi produksi belum final. Pendekatan
opt-in memungkinkan mekanisme ini masuk ke basis kode tanpa mengubah perilaku
lingkungan mana pun.

---

## 10. Pemecahan Masalah

### Aplikasi gagal start dengan `StateError` menyebut aset sertifikat

`SSL_PINNED_HOSTS` terisi namun berkas pada `SSL_CERT_ASSET` tidak ditemukan.
Pastikan berkas tersedia pada `assets/ssl/` dan direktori tersebut terdaftar pada
bagian `assets:` di `pubspec.yaml`. Untuk menonaktifkan pinning, kosongkan
`SSL_PINNED_HOSTS`.

### Permintaan ke API gagal dengan galat handshake setelah pinning diaktifkan

Kemungkinan penyebab, berurutan:

1. Rantai sertifikat tidak lengkap — intermediate tidak disertakan
2. SAN tidak mencakup host tujuan (lihat [§7.4](#74-cakupan-subject-alternative-name))
3. Host menyajikan sertifikat berbeda dari yang di-pin (lihat [§7.2](#72-konsistensi-sertifikat-antar-jalur))
4. Sertifikat telah kedaluwarsa

### Pencarian alamat, kurs, atau SSO berhenti berfungsi

Menandakan pinning diterapkan secara global, bukan per host. Pastikan
`SSL_PINNED_HOSTS` hanya memuat host Askrindo. Ketiga layanan tersebut
menggunakan CA publik yang tidak termasuk dalam rantai Askrindo.

### Proxy debugging tidak dapat mencegat lalu lintas

Perilaku ini sesuai rancangan — pinning memang menolak sertifikat yang
disisipkan proxy. Untuk keperluan pengembangan, jalankan build tanpa
`SSL_PINNED_HOSTS`.

### Pinning tampak tidak aktif pada build web

Sesuai rancangan. Lihat [§4](#4-batasan-platform).
