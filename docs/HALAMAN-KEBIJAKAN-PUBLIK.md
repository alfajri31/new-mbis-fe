# Halaman Kebijakan Publik — Hapus Akun & Kebijakan Privasi

Google Play mensyaratkan dua halaman web yang dapat dibuka **tanpa memasang
aplikasi**, dengan sertifikat TLS yang sah:

1. **Permintaan penghapusan akun** — URL-nya dilampirkan di formulir Data safety.
2. **Kebijakan privasi** — tautannya juga wajib dapat dibuka dari dalam aplikasi.

Dokumen ini menjelaskan yang **sudah dikerjakan di repo** dan yang **masih harus
dikerjakan di sisi server**.

> **Domain kerja: `mbis.askrindo.co.id`** (ditetapkan 27 Juli 2026, sementara).
> Semua URL di dokumen ini memakainya. Ganti di satu tempat kalau web M-BIS
> akhirnya tayang di domain lain — URL-nya hanya hidup di variabel Codemagic dan
> di Play Console, tidak ada yang di-hardcode di kode.
>
> ✅ **Diperbarui 31 Juli 2026 — sertifikat TLS sudah sah** (Sectigo, wildcard
> `*.askrindo.co.id`, berlaku s/d 11 Apr 2027), diverifikasi dari luar jaringan
> kantor. Peringatan lama soal sertifikat *self-signed* **sudah tidak berlaku**.
>
> ✅ **Diperbarui 3 Agustus 2026 — aplikasinya sudah tayang.** Backend menjawab di
> `/v2` (`/v2/actuator/health` → `200 {"status":"UP"}`) dan **web sudah punya
> alamat publik sendiri di `/app`**. Catatan lama "backend belum dideploy" di §3
> sudah tidak berlaku.
>
> ⚠️ **Halamannya pindah dari backend ke frontend** pada tanggal yang sama, dan
> bentuknya kembali menjadi **HTML statis**. Lihat §1 & 2.

---

## 1 & 2. Kedua halaman kebijakan — HTML statis di repo ini (3 Agustus 2026)

| | Kebijakan privasi | Permintaan hapus akun |
|---|---|---|
| Naskah | `lib/src/legal/kebijakan_privasi_content.dart` | `lib/src/legal/hapus_akun_content.dart` |
| Layar (in-app) | `presentation/screens/kebijakan_privasi_screen.dart` | `presentation/screens/hapus_akun_screen.dart` |
| Berkas HTML publik (turunan) | `web/kebijakan-privasi.html` | `web/hapus-akun.html` |
| **URL publik (prod)** | `https://mbis.askrindo.co.id/app/kebijakan-privasi` | `https://mbis.askrindo.co.id/app/hapus-akun` |
| URL publik (staging) | `https://mbis.askrindo.net/kebijakan-privasi` | `https://mbis.askrindo.net/hapus-akun` |
| Rute Flutter publik | `/kebijakan-privasi` | `/hapus-akun` |
| Rute dalam aplikasi | `/profil/privasi/kebijakan` (+ salinan shell Agen) | dibuka dari Privasi & Akun dan dari kebijakan bagian 11 |

Tata letak versi in-app dirender `presentation/widgets/policy_view.dart`; rute dan
konstantanya di `lib/src/legal/legal_routes.dart`.

### Kenapa HTML statis lagi, dan kenapa di frontend

Dua asumsi lama patah sekaligus:

| | 30 Juli (halaman ditaruh di backend) | 3 Agustus (kenyataan prod) |
|---|---|---|
| Alamat publik web | tidak ada — web di IP privat | **ada**: proxy host memetakan `/app/` ke web (`:3024`) |
| Cukupkah rute Flutter? | — | **tidak**, lihat di bawah |

**Alasan pindah ke frontend:** web sudah punya alamat publik sendiri, jadi tidak ada
lagi sebab menyeberangkan naskah ke repo backend. Halamannya kini satu tempat dengan
sumbernya, dan generator tidak lagi butuh repo tetangga ter-checkout.

**Alasan tetap HTML, bukan rute Flutter saja:** aplikasi web ini dibangun sebagai
**SPA WasmGC**. Pengambil HTTP yang tidak menjalankan JS/WASM — **pemeriksa otomatis
Google Play** dan mesin pencari — hanya menerima cangkang `index.html` (±5,6 KB) tanpa
satu kata pun naskah kebijakan. Halaman yang tampil kosong bagi mereka dianggap sama
saja dengan tidak ada kebijakan. Ini persis yang tidak diperhitungkan keputusan
27 Juli di bawah, yang menimbang hanya reviewer manusia dengan browser sungguhan.

**Naskahnya tetap satu:**

| Berkas | Peran |
|---|---|
| `lib/src/legal/*_content.dart` | **satu-satunya sumber naskah** |
| `tool/policy_html.dart` | renderer HTML, memakai `parseInline` yang sama dengan aplikasi |
| `tool/gen_policy_html.dart` | CLI: `dart run tool/gen_policy_html.dart` |
| `web/*.html` | **berkas turunan** — berbanner "JANGAN DIEDIT TANGAN" |
| `test/src/legal/policy_html_drift_test.dart` | gagal bila HTML di `web/` ≠ hasil render naskah |
| `nginx.conf` | blok `location =` memetakan URL bersih (tanpa `.html`) ke berkasnya |

Test drift-nya kini **selalu berjalan**, termasuk di CI — dulu di-skip karena berkasnya
ada di repo backend tetangga yang tidak ikut ter-checkout.

**Rute Flutter publik TIDAK dihapus.** Tombol di layar Privasi & Akun memanggilnya lewat
`context.push`, jadi navigasi di dalam aplikasi tetap merender naskah dari Dart — terbaca
luring dan tanpa muat ulang halaman. Yang berubah hanya penyajian saat URL-nya **dimuat
langsung**: nginx menjawabnya dengan HTML statis sebelum aplikasi sempat jalan.

### Backend sudah tidak terlibat

Dihapus 3 Agustus 2026 dari `be-new-mbis` **dan** `MBIS-backend`:

| Yang dihapus | Dulu perannya |
|---|---|
| `src/main/resources/legal/*.html` | berkas turunan yang disajikan backend |
| `controller/LegalPageController.java` | menyajikan `/kebijakan-privasi` & `/hapus-akun` |
| `LEGAL_PAGE_PATHS` di `SecurityConfig` | mem-`permitAll` kedua path di semua profil |
| `e2e/LegalPageE2ETest.java` | menjaga keduanya tetap publik |

Komentar penanda ditinggalkan di `SecurityConfig` supaya tidak ditambahkan kembali.

### Kenapa bukan HTML statis (keputusan 27 Juli 2026 — SUDAH DIBATALKAN, disimpan sebagai riwayat)

> Keputusan di bawah dibatalkan dua kali: 30 Juli (halaman HTML dihidupkan lagi di
> backend) dan 3 Agustus (dipindah ke frontend). Yang terlewat dari penalarannya:
> "dapat dibuka tanpa memasang aplikasi" juga berlaku bagi **pengambil otomatis**
> yang tidak menjalankan JS/WASM, bukan hanya reviewer manusia dengan browser.
> Disimpan supaya alasannya tidak diputar ulang untuk ketiga kalinya.

Semula keduanya berkas HTML statis di `web/`, disajikan blok `location =` di
nginx. Halaman kebijakan privasi bahkan **dibangkitkan** dari naskah Dart oleh
`tool/gen_kebijakan_privasi.dart`, lengkap dengan test yang menolak lulus kalau
HTML-nya tidak lagi cocok.

Semua itu dibuang. Google mensyaratkan URL-nya **dapat dibuka tanpa memasang
aplikasi dan tanpa login** — bukan mensyaratkan bentuknya HTML. Rute Flutter yang
dikecualikan dari gerbang auth sudah memenuhi syarat itu, dan dengan satu jalur
render tidak ada lagi salinan kedua yang bisa menyimpang. Generator, berkas HTML,
blok nginx, dan test drift-nya jadi tidak diperlukan.

Yang dibayar: pembaca menunggu unduhan bundel web (`main.dart.js` ~5 MB atau
canvaskit ~7 MB, ter-gzip lebih kecil) sebelum teksnya tampil, dibanding ~21 KB
kalau statis. Build web punya fallback `main.dart.js`, jadi browser tanpa WasmGC
tidak berakhir di layar kosong.

**URL-nya tidak berubah**, jadi nilai di Play Console dan Codemagic tetap sama.

### Pagar yang menjaganya

- **Pengecualian gerbang auth** ada di `redirect` `lib/src/router.dart`, memakai
  `rutePublikLegal`. Kalau hilang, kedua URL memulangkan reviewer ke layar login —
  kegagalan yang sunyi, karena aplikasi tetap jalan.
  `test/src/legal/rute_publik_test.dart` menjaganya, sekaligus memastikan
  pengecualiannya **tidak kebablasan** (rute bisnis harus tetap dipagari).
- **`nginx.conf` WAJIB punya blok `location =`** untuk kedua path — itulah yang
  memetakan URL bersih ke berkas `.html`-nya, dan yang membuat isinya terbaca
  pengambil otomatis. Tautan silang di dalam naskah (`href="hapus-akun"`) juga
  bergantung pada bentuk tanpa akhiran ini. Komentar panjang di berkasnya
  menjelaskan ini, termasuk kenapa peringatan lama "jangan tambahkan blok ini"
  sudah tidak berlaku.
- **Drift test** (`policy_html_drift_test.dart`) menolak lulus bila `web/*.html`
  tidak lagi sama dengan hasil render naskah Dart. Ini yang mencegah versi publik
  diam-diam tertinggal saat Legal merevisi naskah.
- **Status draf** kebijakan (`kebijakanMasihDraf`) memunculkan spanduk peringatan
  dan memblokir `scripts/build-aab.*`. Sekarang `false` — disahkan Legal,
  berlaku 3 Agustus 2026.

### Yang tersisa (di luar repo)

1. Codemagic → `mbis-prod`:

   ```
   PRIVACY_POLICY_URL   = https://mbis.askrindo.co.id/app/kebijakan-privasi
   ACCOUNT_DELETION_URL = https://mbis.askrindo.co.id/app/hapus-akun
   ```

   ⚠️ Prefiksnya **`/app`**, bukan `/v2`. `/v2` adalah backend, dan sejak 3 Agustus
   backend tidak lagi menyajikan halaman ini — nilai lama akan 401.

   Keduanya hanya dipakai untuk kolom Play Console dan tombol "buka versi web" —
   bukan satu-satunya jalan pengguna membaca kebijakan.
2. Isi URL yang sama di Play Console (kebijakan privasi + Data deletion URL).
3. **Deploy ulang web** supaya `web/*.html` dan `nginx.conf` yang baru ikut terbawa.
   Sebelum itu, kedua URL `/app/...` masih dijawab SPA fallback (200, tapi kosong
   bagi pengambil otomatis).

### Yang SENGAJA tidak ikut dari draft ke halaman terbit

`draft-kebijakan-privasi.md` ditujukan ke Legal/IT, jadi memuat bagian yang bukan
untuk pembaca kebijakan. Yang dibuang saat memindahkannya — **tinjau daftar ini**,
kalau ada yang seharusnya tetap ada, tambahkan ke berkas naskah:

| Dibuang | Alasan |
|---|---|
| Blok 【CATATAN IT】 dan 【ISI: ...】 | Instruksi kerja internal, bukan pernyataan ke subjek data |
| §8 "Catatan teknis jujur: belum ada penghapusan otomatis" | Ditujukan ke pelaksana, bukan ke pembaca |
| §9 daftar "langkah yang belum diterapkan" (cert pinning, Play Integrity, anti-screenshot) | Kebijakan privasi tidak lazim memerinci kontrol keamanan yang belum ada |
| §11 paragraf "Data yang tetap disimpan" yang kedua | Duplikat di draft; versi pertama yang lebih lengkap dipertahankan |
| Lampiran teknis Data Safety | Bahan pengisian formulir Play Console. Tetap di `DATA-SAFETY.md` |

Catatan SSO di §3.1 **dipertahankan**, ditulis ulang sebagai pernyataan publik.

**Enkripsi at-rest — diputuskan 27 Juli 2026: biarkan apa adanya.** §9 tidak
menyatakan apa pun soal enkripsi penyimpanan, dan itu disengaja. Yang benar-benar
ada hanya bcrypt untuk kolom kata sandi (itu *hashing*, bukan enkripsi data);
kolom NIK, NPWP, nomor KTP, dan nomor rekening tersimpan sebagai teks biasa.
Klaim kebijakan lama "data sensitif dienkripsi di level database" **tidak
disalin** — menyatakan pengamanan yang tidak ada adalah jenis kalimat yang paling
mudah dipatahkan saat audit. Diam soal ini tidak melanggar apa pun: UU PDP
mewajibkan pengamanan yang memadai, bukan pengungkapan detail teknisnya.

---

## 3. Sertifikat TLS `mbis.askrindo.co.id` — SUDAH BERES (31 Juli 2026)

**Pemeriksaan ulang 31 Juli 2026, dari luar jaringan kantor (hotspot seluler,
IP publik 114.8.207.165) — sertifikatnya sudah sah:**

| Yang diperiksa | Hasil |
|---|---|
| Resolusi DNS (resolver seluler & 8.8.8.8) | `9.154.64.93` — **sama**, alamat publik |
| Port 443 dari internet publik | terbuka |
| Penerbit sertifikat | **Sectigo Public Server Authentication CA DV R36** — CA tepercaya |
| Subject / SAN | `CN=askrindo.co.id`, SAN `askrindo.co.id` + `*.askrindo.co.id` (mencakup `mbis.`) |
| Masa berlaku | 11 Mar 2026 → 11 Apr 2027 (aktif, sisa ±254 hari) |
| Validasi rantai | lolos tanpa galat (`SslPolicyErrors = None`) |

Wildcard `*.askrindo.co.id` mencakup `mbis.askrindo.co.id`, jadi tidak ada lagi
halaman peringatan browser. **Blocker TLS pada temuan 27 Juli (lihat di bawah)
tidak berlaku lagi.**

> **Perpanjangan:** sertifikatnya wildcard milik korporat dan jatuh tempo
> 11 April 2027. Tidak ada perpanjangan otomatis ala Let's Encrypt di sini —
> pastikan tim infra memasukkannya ke pengingat, karena kedaluwarsa akan
> mematikan URL kebijakan **dan** seluruh API sekaligus.

### Deployment — sudah beres (3 Agustus 2026)

Catatan 31 Juli "backend belum ada di domain itu" **sudah tidak berlaku**.
Pemeriksaan 3 Agustus 2026:

| Permintaan | Hasil |
|---|---|
| `GET /v2/actuator/health` | `200` `{"status":"UP","groups":["liveness","readiness"]}` — sidik jari M-BIS |
| `GET /v2/api/visits?pipelineId=x` | `401` `{"message":"Authentication required"}` — M-BIS, terproteksi |
| `GET /actuator/health` (tanpa `/v2`) | `403` — masih aplikasi tetangga pemilik `/v1` |
| `GET /app/` | `200` `text/html` — cangkang aplikasi web |
| `GET /app/favicon.png` | `200` `image/png` — membuktikan proxy **membuang** prefix `/app` |
| `GET /app/auth.html` | `200`, 1025 B — berkas asli dari `web/`, bukan cangkang |

Dua hal penting yang dibuktikan pemeriksaan itu:

1. **Proxy host membuang prefix `/app`** sebelum meneruskan ke nginx kita. Karena
   itu blok nginx ditulis `location = /kebijakan-privasi`, bukan `/app/kebijakan-privasi`.
2. **Berkas di `web/` tersaji apa adanya** di bawah `/app/` — jalur yang sama persis
   dengan `auth.html`, jadi `kebijakan-privasi.html` tidak butuh perlakuan khusus.

### ✅ `/app` terbukti terekspos publik (3 Agustus 2026)

Diverifikasi ulang dari **hotspot seluler pribadi**, di luar jaringan kantor.
Sertifikat lolos **tanpa** `-k`, dan resolusinya ke alamat publik:

| Permintaan | Hasil | IP |
|---|---|---|
| `GET /v2/actuator/health` | `200` JSON aktuator | `9.154.64.93` |
| `GET /app/` | `200` `text/html` | `9.154.64.93` |
| `GET /app/kebijakan-privasi` | `200` `text/html` | `9.154.64.93` |
| `GET /app/hapus-akun` | `200` `text/html` | `9.154.64.93` |
| `GET /v2/kebijakan-privasi` | `401` JSON — salinan backend memang sudah mati | `9.154.64.93` |

Jadi **web punya alamat publik sendiri**, dan dasar pemindahan halaman ke frontend
terbukti benar, bukan sekadar asumsi dari komentar Dockerfile.

### Sekaligus terbukti: kenapa rute Flutter saja tidak cukup

Pemeriksaan yang sama menunjukkan masalahnya secara langsung. Ini yang **masih**
diterima pengambil otomatis di `/app/kebijakan-privasi` hari ini, sebelum perubahan
ini dideploy:

```
$ curl -s https://mbis.askrindo.co.id/app/kebijakan-privasi | grep -c "Pengendali Data"
0
$ curl -s https://mbis.askrindo.co.id/app/kebijakan-privasi | grep -c "Kebijakan Privasi"
0
$ curl -s https://mbis.askrindo.co.id/app/kebijakan-privasi | grep -iE "<title>|<base href"
  <base href="/app/">
  <title>M-BIS</title>
```

`200 OK`, 5.648 byte, judul `M-BIS`, dan **nol** kemunculan naskah kebijakan. URL-nya
"hidup" bagi pemantau uptime, tapi bagi pemeriksa Google Play halaman itu **tidak
memuat kebijakan privasi sama sekali**. Setelah deploy, permintaan yang sama harus
mengembalikan 19.360 byte berisi naskah.

### Temuan lama 27 Juli 2026 (sudah tidak berlaku — disimpan sebagai riwayat)

| Yang diperiksa | Hasil saat itu |
|---|---|
| Resolusi DNS dari jaringan kantor | `10.10.1.242` — alamat privat RFC1918 |
| Resolusi DNS dari resolver publik (8.8.8.8) | `9.154.64.93` — alamat publik |
| Sertifikat TLS | **Self-signed** — browser menampilkan halaman peringatan |

Saat itu domain memakai **split-horizon DNS** dan sertifikatnya bukan dari CA
tepercaya. Bagian sertifikat sudah diperbaiki; resolusi internal dari jaringan
kantor tidak diperiksa ulang pada 31 Juli (pengujiannya dilakukan dari luar),
tapi yang menentukan bagi reviewer Google adalah tampilan dari publik — dan itu
kini benar.

**Ini memengaruhi kebijakan privasi M-BIS versi 1 yang sudah tayang di Play Store**
(`com.mbis`), bukan hanya aplikasi baru. Reviewer Google membuka URL kebijakan
privasi dari browser biasa; sertifikat *self-signed* memunculkan peringatan merah,
dan halaman yang tidak bisa dibuka dianggap sama dengan tidak ada.

Perbaikannya ada di sisi tim infrastruktur, bukan di repo ini:

1. Terbitkan sertifikat dari CA tepercaya untuk `mbis.askrindo.co.id` (Let's Encrypt
   gratis, atau sertifikat korporat yang sudah ada).
2. Pastikan `9.154.64.93:443` benar-benar melayani dari internet publik.
3. Verifikasi dari luar jaringan kantor, bukan dari komputer kantor — resolusi
   internal akan menyembunyikan masalahnya.

> **Untuk aplikasi baru, langkah ini tidak memblokir rilis** selama kedua halaman
> kebijakan dihosting bersama aplikasi seperti §1 dan §2. Perbaikan sertifikat tetap
> perlu dikerjakan demi aplikasi v1 yang masih tayang.

---

## 4. Verifikasi yang sudah dijalankan

**Test (27 Juli 2026):** `flutter analyze` bersih, **75/75 test lulus**, termasuk
`test/src/legal/rute_publik_test.dart` yang membuktikan kedua rute terbuka tanpa
sesi, judul dokumennya benar-benar terender, tombol kembali tidak muncul di rute
publik, dan rute bisnis (`/customer`) **tetap** dilempar ke `/login`.

**nginx (27 Juli 2026 — konfigurasi saat itu, tanpa blok `location =`)** diuji dengan
image `nginx:1.27-alpine` memakai `nginx.conf` **asli** dari repo (`nginx -t` lolos).
Semua path jatuh ke SPA fallback dan membalas `200` berisi shell aplikasi. Uji itu
membuktikan tidak ada sisa blok statis yang 404 — benar untuk konfigurasi saat itu,
tapi **tidak lagi menggambarkan keadaan sekarang**: sejak 3 Agustus blok
`location = /kebijakan-privasi` dan `= /hapus-akun` sengaja ada kembali.

### Verifikasi 3 Agustus 2026 (pemindahan ke frontend)

**Kode & tes:**

| Yang diuji | Hasil |
|---|---|
| `flutter analyze` (kedua repo FE) | **exit 0**, `No issues found!` |
| `flutter test` (kedua repo FE) | **86/86 lulus** di masing-masing repo |
| `mvn test` (MBIS-backend, Postgres nyata) | **164/164 lulus**, `BUILD SUCCESS` — pembuktian penghapusan `LegalPageController` + entri `SecurityConfig` tidak mengubah perilaku lain |
| `mvn test-compile` (be-new-mbis) | exit 0 — tidak ada sisa rujukan ke `LegalPageE2ETest` yang dihapus |
| Generator di kedua repo FE | `web/kebijakan-privasi.html` (19.332 char) + `web/hapus-akun.html` (7.110 char), **identik antar repo** |
| Drift test benar-benar menjaga | disabotase dengan menambah satu komentar ke HTML → test **gagal** dengan pesan yang benar; dipulihkan generator → lulus lagi |
| Backend tidak lagi merujuk halaman kebijakan | `grep` di `src/` kedua repo BE bersih (sisa hanya komentar penanda) |

**nginx — diuji dengan `nginx.conf` ASLI dari repo** di container `nginx:1.27-alpine`
(`nginx -t` lolos), berkas `web/` dipasang sebagai root. Cangkang `index.html` = 5.661 B,
jadi ukuran respons langsung membedakan naskah dari cangkang:

| Permintaan | Hasil |
|---|---|
| `GET /kebijakan-privasi` | `200`, **19.360 B** — naskah, `grep "Pengendali Data"` → 1 |
| `GET /hapus-akun` | `200`, **7.122 B** — naskah |
| `GET /kebijakan-privasi.html` | `200`, 19.360 B — berkasnya juga tetap terjangkau langsung |
| `GET /dashboard` | `200`, 5.661 B — cangkang (SPA fallback masih benar) |
| `GET /profil/privasi/kebijakan` | `200`, 5.661 B — cangkang, seperti seharusnya |
| `GET /` | `200`, 5.661 B — cangkang |

Header pada halaman kebijakan:

```
Content-Type: text/html; charset=utf-8
Cache-Control: max-age=3600
X-Content-Type-Options: nosniff        <- pengerasan level server TETAP ikut
X-Frame-Options: SAMEORIGIN
Referrer-Policy: strict-origin-when-cross-origin
```

Header pengerasan itu ikut **karena** blok memakai `expires`, bukan `add_header`.
Bandingkan dengan `location = /index.html` yang memakai `add_header` dan karenanya
**kehilangan** ketiganya — masalah lama yang sengaja tidak ditiru di sini.

Tautan silang terverifikasi: satu-satunya `href` non-mailto di halaman kebijakan
adalah `href="hapus-akun"`, yang relatif terhadap `/app/kebijakan-privasi` mendarat
di `/app/hapus-akun`. Karakter non-ASCII juga utuh (`Profil → Privasi &amp; Akun`).

**Yang masih harus diuji setelah deploy** (butuh build & deploy ulang web):

1. URL prod sungguhan menyajikan naskah — uji dengan `curl` polos, bukan browser,
   supaya benar-benar meniru pengambil otomatis Play:

   ```bash
   curl -s https://mbis.askrindo.co.id/app/kebijakan-privasi | grep -c "Pengendali Data"
   # harus >= 1; kalau 0, yang tersaji masih cangkang SPA
   ```

   Baseline sebelum deploy sudah diukur dari hotspot seluler: hasilnya **0** (lihat
   §3). Kalau setelah deploy masih 0, berarti `web/*.html` atau `nginx.conf` yang
   baru tidak ikut terbawa ke image.

2. Navigasi in-app (Privasi & Akun → Kebijakan Privasi) tetap merender layar
   Flutter, bukan memuat ulang halaman.

Akses dari luar jaringan kantor **sudah terbukti** (§3) — itu bukan lagi item terbuka.
