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
> Yang tersisa: **backend M-BIS belum dideploy di domain itu** — semua path masih
> dijawab aplikasi lain dengan 403. Rinciannya di §3.

---

## 1 & 2. Kedua halaman kebijakan — SELESAI, keduanya rute Flutter publik

| | Kebijakan privasi | Permintaan hapus akun |
|---|---|---|
| Naskah | `lib/src/legal/kebijakan_privasi_content.dart` | `lib/src/legal/hapus_akun_content.dart` |
| Layar | `presentation/screens/kebijakan_privasi_screen.dart` | `presentation/screens/hapus_akun_screen.dart` |
| URL publik (disajikan backend) | `https://mbis.askrindo.co.id/v2/kebijakan-privasi` | `https://mbis.askrindo.co.id/v2/hapus-akun` |
| Rute Flutter publik (in-app + web internal) | `/kebijakan-privasi` | `/hapus-akun` |
| Rute dalam aplikasi | `/profil/privasi/kebijakan` (+ salinan shell Agen) | dibuka dari Privasi & Akun dan dari kebijakan bagian 11 |

Tata letak keduanya dirender `presentation/widgets/policy_view.dart`; rute dan
konstantanya di `lib/src/legal/legal_routes.dart`.

### HTML kembali dipakai — untuk alamat publik (31 Juli 2026)

Keputusan 27 Juli di bawah **masih berlaku untuk versi in-app**, tapi tidak lagi cukup untuk
alamat publik. Alasannya bukan berubah pikiran, melainkan asumsinya patah:

| | 27 Juli | 30 Juli (topologi prod ditetapkan) |
|---|---|---|
| Web M-BIS | diasumsikan punya alamat publik | hanya di **IP privat** jaringan internal |
| Backend | — | satu-satunya komponen **publik** (`/v2`) |

Rute Flutter publik tidak bisa dibuka reviewer kalau webnya sendiri tidak punya alamat publik.
Karena itu kedua halaman kini **juga** disajikan backend sebagai HTML:

| | URL publik (prod) |
|---|---|
| Kebijakan privasi | `https://mbis.askrindo.co.id/v2/kebijakan-privasi` |
| Permintaan hapus akun | `https://mbis.askrindo.co.id/v2/hapus-akun` |

Prefix `/v2` ikut `MBIS_CONTEXT_PATH`; di staging & lokal (context-path kosong) URL-nya di root.

**Naskahnya tetap satu.** Yang dihindari keputusan 27 Juli adalah *salinan kedua yang bisa
menyimpang* — dan itu tetap dihindari:

| Berkas | Peran |
|---|---|
| `lib/src/legal/*_content.dart` | **satu-satunya sumber naskah** (tidak berubah) |
| `tool/policy_html.dart` | renderer HTML, memakai `parseInline` yang sama dengan aplikasi |
| `tool/gen_policy_html.dart` | CLI: `dart run tool/gen_policy_html.dart` |
| `MBIS-backend/.../resources/legal/*.html` | **berkas turunan** — berbanner "JANGAN DIEDIT TANGAN" |
| `test/src/legal/policy_html_drift_test.dart` | gagal bila HTML di backend ≠ hasil render naskah |
| `MBIS-backend/.../LegalPageController.java` | menyajikannya; gagal-cepat saat boot bila berkasnya hilang |

Test drift-nya **melewat** bila repo backend tidak ada di sebelah (CI satu repo), dan **berjalan**
di mesin pengembang tempat kedua repo bersebelahan — yaitu tempat naskah sebenarnya diubah.
Sudah diuji dengan sengaja mengubah HTML di backend: test-nya gagal seperti seharusnya.

Kedua path di-`permitAll` di `SecurityConfig` untuk **semua profil termasuk prod** — kebalikan
dari Swagger yang justru ditutup di prod. `LegalPageE2ETest` menjaganya, sekaligus memastikan
endpoint bisnis tetap 401.

**Rute Flutter publik TIDAK dihapus.** Versi in-app tetap dirender aplikasi, tetap terbaca luring,
dan tetap dikecualikan dari gerbang auth. Yang bertambah hanyalah alamat publik lewat backend.

### Kenapa bukan HTML statis (keputusan 27 Juli 2026 — konteks historis)

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
- **`nginx.conf` sengaja tidak punya blok `location =`** untuk kedua path. Blok
  seperti itu akan menang atas SPA fallback dan mengembalikan 404 karena berkas
  HTML-nya sudah tidak ada. Komentar di berkasnya menjelaskan ini.
- **Status draf** kebijakan (`kebijakanMasihDraf`) memunculkan spanduk peringatan
  dan memblokir `scripts/build-aab.*`. Sekarang `false` — disahkan Legal,
  berlaku 3 Agustus 2026.

### Yang tersisa (di luar repo)

1. Codemagic → `mbis-prod`:

   ```
   PRIVACY_POLICY_URL   = https://mbis.askrindo.co.id/v2/kebijakan-privasi
   ACCOUNT_DELETION_URL = https://mbis.askrindo.co.id/v2/hapus-akun
   ```

   Keduanya kini hanya dipakai untuk kolom Play Console dan tombol "buka versi
   web" — bukan lagi satu-satunya jalan pengguna membaca kebijakan.
2. Isi URL yang sama di Play Console (kebijakan privasi + Data deletion URL).
3. **Beresi TLS `mbis.askrindo.co.id` lebih dulu** (§3). Tanpa itu kedua URL gagal
   dibuka reviewer, apa pun bentuk halamannya.

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

### Yang tersisa: aplikasinya belum dideploy di sana

Sertifikatnya beres, tapi **backend M-BIS belum ada di domain itu.** Pemeriksaan
31 Juli: seluruh path (`/`, `/v1`, `/v2`, `/v2/actuator/health`,
`/v2/kebijakan-privasi`) membalas **403 dengan badan kosong**.

Itu bukan M-BIS. Sidik jarinya tidak cocok — backend M-BIS membalas `200`
`{"status":"UP",...}` di `/actuator/health` dan `401` `{"message":"Authentication
required"}` untuk endpoint terproteksi, bukan 403 kosong. Header responsnya
(`X-XSS-Protection: 0`, `X-Frame-Options: DENY`, `Cache-Control: no-store`) khas
Spring Security, jadi yang menjawab adalah **aplikasi Spring lain** — kemungkinan
besar aplikasi pemilik `/v1` — dan `/v2` belum dipetakan ke M-BIS.

Jadi langkah berikutnya murni deployment: deploy backend M-BIS dengan
`MBIS_CONTEXT_PATH=/v2` dan minta infra meneruskan `/v2` ke sana. Begitu itu
selesai, kedua URL kebijakan langsung hidup — semua prasyarat lain sudah terbukti
terpenuhi.

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

**nginx** diuji dengan image `nginx:1.27-alpine` memakai `nginx.conf` **asli** dari
repo, bukan konfigurasi sederhana buatan sendiri (`nginx -t` lolos):

| Permintaan | Hasil |
|---|---|
| `GET /kebijakan-privasi` | `200` — shell aplikasi (SPA fallback) |
| `GET /hapus-akun` | `200` — shell aplikasi |
| `GET /dashboard` | `200` — shell aplikasi |
| `GET /profil/privasi/kebijakan` | `200` — shell aplikasi |

Sejak kedua halaman jadi rute Flutter, yang benar justru **tidak ada** blok
`location =` untuk keduanya — semuanya jatuh ke SPA fallback seperti rute lain.
Uji ini yang memastikan tidak ada sisa blok statis yang mengembalikan 404.

> Uji di atas membuktikan nginx menyajikan shell aplikasinya. Yang **belum**
> diuji: browser sungguhan merender kebijakan di URL itu tanpa login. Itu perlu
> `flutter build web` lalu dibuka dari luar jaringan kantor — dan bergantung pada
> perbaikan TLS di §3.
