# Topologi prod: API di `mbis.askrindo.co.id/v2`, web di IP privat

> Status: **kode repo sudah disesuaikan; deployment & item di luar repo belum.**
> Staging (`mbis.askrindo.net`, dilayani di root, web+API satu origin) **tidak berubah
> sedikit pun** — semua perubahan di bawah berperilaku persis seperti sebelumnya saat
> variabel barunya dibiarkan kosong. Revisi 2026-07-30.

> ⚠️ **Revisi ini membalik dokumen sebelumnya.** Versi pertama menaruh **web** di `/v2`
> dan backend di hostname sendiri. Keputusan baru: **`/v2` adalah BACKEND**, dan web
> dilayani terpisah di **IP privat** (jaringan internal). Kalau Anda pernah membaca versi
> lama: rencana base-href `/v2/`, varian `nginx.conf` per target, dan redirect URI SSO
> `/v2/auth.html` **semuanya batal** — web tetap dilayani di root alamatnya sendiri.

## 0. Ringkasan keputusan

| Hal | Nilai |
|---|---|
| **API prod** | `https://mbis.askrindo.co.id/v2` → endpoint jadi `https://mbis.askrindo.co.id/v2/api/...` |
| **Web prod** | Dilayani di **IP privat** (jaringan internal). Alamat pastinya **belum ditentukan** — lihat §7. |
| Prefix `/v2` | **Diteruskan utuh** ke container backend, tidak dipotong proxy. Backend karena itu harus tahu ia hidup di bawah `/v2`. |
| Tetangga | `/v1` dipakai **aplikasi lain**; domain dibagi per prefix. Root bukan wilayah kita. |
| Staging | `https://mbis.askrindo.net/` di root, web+API satu origin. **Tidak boleh ikut berubah.** |
| Aplikasi HP | Memanggil `https://mbis.askrindo.co.id/v2` — sama seperti web, lewat `--dart-define=API_URL`. |

Karena staging tetap di root sementara prod di bawah `/v2`, prefix itu **wajib jadi
variabel environment**, bukan nilai yang di-hardcode. Kalau di-hardcode, staging patah
begitu perubahan di-merge. Itu yang membentuk seluruh bentuk perubahan di §2.

## 1. Empat konsekuensi yang menentukan

### 1.1 Backend hidup di bawah prefix → `context-path`, dan itu menggeser SEMUANYA

Karena `/v2` diteruskan utuh, backend menerima `/v2/api/auth/login`, bukan
`/api/auth/login`. Tanpa penyesuaian, **setiap endpoint balas 404**.

Solusinya `server.servlet.context-path` (§2.1). Yang perlu diketahui: prefix itu
menggeser **seluruh** path, termasuk yang bukan `/api` —

- `/actuator/health*` → `/v2/actuator/health*` (probe Docker/Coolify ikut berubah)
- `/v3/api-docs`, `/swagger-ui.html` → ikut di bawah `/v2` (mati di prod, tapi relevan bila staging suatu saat memakai prefix)

Sebaliknya, yang **tidak** bergeser: `requestMatchers(...)` di `SecurityConfig` dan
`@RequestMapping` di controller — Tomcat sudah memotong context-path sebelum keduanya
dicocokkan. Jadi aturan otorisasi tetap ditulis `/api/...` seperti sekarang.

**Jebakan yang sudah diperbaiki:** filter yang membaca `request.getRequestURI()` mentah
melihat path **berikut** context-path, sehingga cocok-mencocok terhadap `/api/...` diam-diam
gagal. Dua filter terkena, keduanya penting dan keduanya gagal **tanpa error, log, atau
tes merah** (§2.2).

### 1.2 Web beda origin dari API → CORS berubah dari opsional jadi WAJIB

Selama ini web dan API berbagi satu alamat (nginx mem-proxy `/api` di origin yang sama dan
**membuang header `Origin`**), sehingga browser tidak menganggapnya lintas-origin dan CORS
tidak pernah dibutuhkan. Begitu web di IP privat memanggil `mbis.askrindo.co.id`, browser
memberlakukan CORS.

Backend default-nya **menolak semua** lintas-origin (`CorsConfig.java:43-47`, daftar kosong
= tolak semua). Kalau `MBIS_CORS_ALLOWED_ORIGINS` tidak diisi, **web mati total di prod
(semua 403) sementara aplikasi HP tetap normal** — aplikasi native tidak terkena CORS. Gejala
"HP jalan, web tidak" itu menyesatkan dan mahal didiagnosis, jadi perlakukan sebagai blocker
rilis, bukan penyetelan akhir.

Bentuk nilainya: **skema + host + port**, `https://` atau `http://` sesuai kenyataan,
**tanpa path** dan tanpa garis miring akhir. Contoh: `http://10.20.30.40:8081`.
Origin memang tidak pernah memuat path — menuliskan `/v2` di sini membuat kecocokan gagal.

Preflight `OPTIONS` akan muncul otomatis (request membawa `Authorization`). Sudah diizinkan
di `CorsConfig.java:52`, jadi tidak ada pekerjaan tambahan — cukup diketahui saat membaca log.

### 1.3 ⚠️ Web di IP privat WAJIB HTTPS — kalau HTTP polos, login tidak jalan sama sekali

Ini konsekuensi terbesar dari "web dibuka di IP privat", dan tidak ada hubungannya dengan
`/v2`. Browser menganggap `http://<ip>` sebagai **insecure context**, dan beberapa API yang
dipakai aplikasi ini hanya hidup di secure context (HTTPS, atau `localhost`):

| API | Dipakai untuk | Akibat di `http://<ip>` |
|---|---|---|
| **Web Crypto** (`crypto.subtle`) | `flutter_secure_storage` menyimpan token sesi | **`UnsupportedError` dilempar** — terverifikasi di `flutter_secure_storage_web-2.1.1/lib/flutter_secure_storage_web.dart:25-34`, ada `if (window.isSecureContext)` eksplisit. Sesi tidak bisa disimpan → **login tidak berfungsi**. |
| **Geolocation** | Ambil titik kunjungan & pemilih lokasi (`lib/src/location/`, `add_activity_screen.dart`) | Diblokir browser; fitur lokasi mati di web. |
| **Service worker** | Cache aset Flutter | Tidak ter-register; aplikasi tetap jalan, hanya kehilangan cache. |

Jadi: **sediakan HTTPS untuk web internal** (nama DNS internal + sertifikat internal, atau
sertifikat untuk IP dari CA internal). Sertifikat publik tidak bisa diterbitkan untuk IP
privat, jadi ini pekerjaan tim infra/PKI. Kalau tidak memungkinkan, web prod praktis tidak
bisa dipakai — dan itu perlu diketahui **sebelum** deploy, bukan sesudah.

### 1.4 SSO Microsoft Entra hampir pasti tidak bisa dipakai di web prod

`entra_auth_service.dart:45` memakai `'${Uri.base.origin}/auth.html'`. Karena web dilayani di
**root** alamatnya sendiri (bukan sub-path), **kodenya sudah benar** dan tidak perlu diubah —
berbeda dari rencana revisi lama.

Yang jadi masalah: redirect URI harus didaftarkan **persis** di App Registration Entra, dan
Microsoft **hanya menerima `https://`** untuk tipe SPA (kecuali `http://localhost`). Alamat
IP privat juga bukan sesuatu yang wajar didaftarkan di sana. Konsekuensinya:

- Tanpa HTTPS + nama host internal yang terdaftar → **tombol "Masuk dengan Microsoft" tidak
  akan berfungsi di prod**, sementara login lokal tetap jalan.
- Kalau SSO memang ditargetkan untuk prod, web internal butuh **nama DNS + HTTPS**, dan URI
  `https://<host-web-internal>/auth.html` harus didaftarkan IT.

Ini keputusan produk, bukan pekerjaan kode — perlu dijawab (§7).

### 1.5 Halaman publik Play Store kehilangan alamat publik

Dua URL ini terdaftar di **Google Play Console + Data safety form** dan wajib bisa dibuka
siapa pun tanpa memasang aplikasi (`docs/HALAMAN-KEBIJAKAN-PUBLIK.md:31`):

- `https://mbis.askrindo.co.id/kebijakan-privasi`
- `https://mbis.askrindo.co.id/hapus-akun`

Keduanya rute **Flutter Web**. Dengan topologi baru, web hanya ada di jaringan internal dan
root domain milik aplikasi `/v1` — artinya **tidak ada satu pun alamat publik** yang menyajikan
halaman itu. Tautan mati di Data safety form berisiko kena penolakan review Play.

### ~~SELESAI (31 Juli 2026) — halaman ikut disajikan backend~~ — DIGANTI 3 Agustus 2026

> Solusi 31 Juli menaruh kedua halaman di **backend** (`/v2/kebijakan-privasi`,
> `/v2/hapus-akun`) karena saat itu web direncanakan hanya hidup di IP privat.
> **Premis itu tidak jadi kenyataan**: proxy host memetakan `/app/` ke aplikasi web,
> jadi web punya alamat publik sendiri. Halamannya dipindahkan kembali ke frontend
> dan salinan backend dihapus. URL `/v2/...` kini **401** — jangan dipakai lagi.

### SELESAI (3 Agustus 2026) — halaman kembali ke frontend, sebagai HTML statis

URL yang berlaku:

- `https://mbis.askrindo.co.id/app/kebijakan-privasi`
- `https://mbis.askrindo.co.id/app/hapus-akun`

Perhatikan prefix **`/app`** (web), bukan `/v2` (backend) dan bukan root (milik aplikasi
`/v1`). **Nilai di Play Console dan Codemagic harus memakai bentuk di atas.**

Bentuknya **HTML statis di `web/`**, bukan sekadar rute Flutter: aplikasi web ini SPA
WasmGC, sehingga pengambil HTTP yang tidak menjalankan JS/WASM — termasuk pemeriksa
otomatis Google Play — hanya menerima cangkang `index.html` tanpa naskah kebijakan.
nginx memetakan URL bersih tanpa akhiran `.html` lewat blok `location =`.

Naskahnya **tidak diduplikasi**: HTML-nya dibangkitkan dari sumber Dart yang sama dengan
yang dirender aplikasi (`dart run tool/gen_policy_html.dart` → `web/*.html`), dan
`test/src/legal/policy_html_drift_test.dart` menolak lulus bila berkas di `web/` tidak
lagi sama dengan naskahnya. Rute Flutter publik tetap ada dan tetap dipakai untuk navigasi
in-app (terbaca luring). Rinciannya di [`HALAMAN-KEBIJAKAN-PUBLIK.md`](HALAMAN-KEBIJAKAN-PUBLIK.md).

> **Masih bergantung pada TLS.** Ini hanya berhasil kalau `mbis.askrindo.co.id` menyajikan
> sertifikat dari CA tepercaya ke internet publik. Selama sertifikatnya masih *self-signed*
> (temuan 27 Juli), reviewer tetap melihat halaman peringatan dan halamannya dianggap tidak ada
> — di URL mana pun. Lihat `HALAMAN-KEBIJAKAN-PUBLIK.md` §3.

`scripts/build-aab.*` tetap menolak build prod bila `PRIVACY_POLICY_URL`/`ACCOUNT_DELETION_URL`
kosong, jadi kelalaian mengisinya akan ketahuan saat build — bukan setelah rilis.

## 2. Yang sudah diubah di repo

Semua berperilaku **identik dengan sebelumnya** bila variabel barunya kosong, jadi aman
di-merge lebih dulu tanpa menyentuh staging.

### 2.1 Backend: prefix jadi variabel environment

`backend/src/main/resources/application.yml` — `server.servlet.context-path:
${MBIS_CONTEXT_PATH:}`. Prod mengisi `/v2`; staging & lokal membiarkannya kosong.
Wajib diawali `/` dan **tanpa** garis miring akhir (Tomcat menolak `/v2/`).

### 2.2 Backend: dua filter yang tadinya akan mati diam-diam

Keduanya kini mencocokkan path **setelah** context-path dipotong
(`UrlPathHelper.defaultInstance.getPathWithinApplication`):

| Berkas | Kalau tidak diperbaiki |
|---|---|
| `security/LoginRateLimitFilter.java` | `/v2/api/auth/login` tidak lagi cocok `/api/auth/login` → **rem brute-force login mati total**. Regresi keamanan tanpa gejala. |
| `security/AssistantRequestSizeFilter.java` | Pagar ukuran body endpoint AI berhenti berlaku → body raksasa lolos ke model (biaya token + tekanan memori). |

Ditahan tes regresi baru: `LoginRateLimitFilterTest#stillLimitsUnderContextPath`
(13/13 tes berkas itu hijau).

### 2.3 Backend: probe kesehatan ikut prefix

`backend/Dockerfile` dan `docker-compose.yml` kini menyusun URL probe dari
`MBIS_CONTEXT_PATH`. Tanpa ini, `/actuator/health/readiness` balas 404 di prod dan container
ditandai **unhealthy selamanya** walau aplikasinya sehat — Traefik/Coolify lalu menolak
merutekan trafik ke sana.

### 2.4 Backend: env

`docker-compose.yml` meneruskan `MBIS_CONTEXT_PATH`; `backend/.env.example` memuatnya beserta
peringatan CORS yang sudah disesuaikan dengan topologi baru.

### 2.5 Frontend: build web akhirnya bisa menerima alamat API

`Dockerfile` sebelumnya **sama sekali tidak** mengoper `API_URL` (disengaja, karena web dulu
same-origin). Sekarang ada `ARG API_URL` yang diteruskan sebagai `--dart-define`. Tanpa ini,
build web prod diam-diam jatuh ke same-origin dan seluruh panggilan API gagal.

```bash
docker build --build-arg API_URL=https://mbis.askrindo.co.id/v2 ...
```

Kosongkan untuk staging → perilaku same-origin lama, tidak berubah.

### 2.6 Frontend: base URL boleh memuat path

`lib/src/config/app_config.dart` membuang garis miring di akhir `API_URL`, supaya
`.../v2/` + `/api/x` tidak jadi `.../v2//api/x` (sebagian server menganggapnya path lain dan
balas 404). Ini jadi relevan justru karena base URL sekarang memuat path, bukan host saja.

### 2.7 Frontend: contoh perintah build mobile

`scripts/build-apk.*`, `scripts/build-aab.*`, `docs/RILIS-ANDROID.md` — contoh URL prod kini
`https://mbis.askrindo.co.id/v2`. Aplikasi HP memanggil alamat yang sama dengan web.

### 2.8 Frontend: catatan di `nginx.conf`

Blok `location ^~ /api/` **tetap ada dan tidak berubah** — staging bergantung padanya. Prod
tidak memakainya (browser langsung ke backend). Jangan dihapus.

## 3. Yang harus diisi saat deploy

| Variabel | Di mana | Nilai prod |
|---|---|---|
| `MBIS_CONTEXT_PATH` | Coolify, service `mbis-backend` | `/v2` |
| `MBIS_CORS_ALLOWED_ORIGINS` | Coolify, service `mbis-backend` | Origin web internal, mis. `https://<host-web-internal>` — **tanpa `/v2`**. Kosong = web mati total. |
| `MBIS_CORS_ALLOW_ALL` | idem | tetap `false` (StartupSecretsValidator menolak boot kalau `true` di luar dev) |
| `API_URL` (build arg) | Build image web | `https://mbis.askrindo.co.id/v2` |
| `API_URL` (dart-define) | Build APK/AAB | `https://mbis.askrindo.co.id/v2` |
| `PRIVACY_POLICY_URL` | Build AAB | `https://mbis.askrindo.co.id/app/kebijakan-privasi` — prefix **`/app`**, bukan `/v2` |
| `ACCOUNT_DELETION_URL` | Build AAB | `https://mbis.askrindo.co.id/app/hapus-akun` — idem |

## 4. Yang harus dikerjakan DI LUAR repo

| # | Item | Tindakan |
|---|---|---|
| 1 | **HTTPS untuk web internal** (§1.3) | **Blocker fungsional.** Tanpa secure context, penyimpanan sesi melempar error dan login tidak jalan. Butuh nama DNS internal + sertifikat internal. |
| 2 | **CORS backend** (§1.2) | **Blocker rilis.** Isi `MBIS_CORS_ALLOWED_ORIGINS` dengan origin web. |
| 3 | **Proxy `/v2` → container backend** | Pastikan infra merutekan `mbis.askrindo.co.id/v2/*` ke container `mbis-backend:8080` **tanpa memotong prefix** (sesuai konfirmasi 2026-07-30) dan mengizinkan `OPTIONS` (preflight) lewat. |
| 4 | **App Registration Entra** (§1.4) | Hanya bila SSO ditargetkan untuk prod: daftarkan `https://<host-web-internal>/auth.html` sebagai redirect SPA. `http://` + IP tidak diterima Microsoft. |
| 5 | **Halaman publik Play** (§1.5) | Alamatnya sudah ditetapkan: `/app/kebijakan-privasi` & `/app/hapus-akun`. Tersisa: pastikan `/app` terekspos publik (uji dari luar jaringan kantor), deploy ulang web, lalu isi Play Console + Data safety form. |
| 6 | **Sertifikat TLS `mbis.askrindo.co.id`** | Dianggap aman per 2026-07-30 (SAN mencakup host ini) — **belum diverifikasi langsung**, cek ulang sebelum rilis. |
| 7 | **`SSL_PINNED_HOSTS`** (opsional) | Kalau pinning dinyalakan, isi **`mbis.askrindo.co.id`** — host BACKEND yang dihubungi aplikasi, **host saja tanpa `/v2`** (pencocokannya `Uri.host`, `ssl_pinning.dart:74-78`; menulis path mematikan pinning diam-diam). Kabar baiknya: berkas bundled `assets/ssl/askrindo-fullchain-2026-2027.crt` memang rantai `askrindo.co.id`, jadi host ini yang paling mungkin cocok tanpa aset baru. |

## 5. Yang TIDAK terpengaruh

Didaftarkan supaya tidak ada yang dikerjakan sia-sia; semua diverifikasi terhadap kode.

| Komponen | Kenapa aman |
|---|---|
| Seluruh kode fitur | Path-nya root-absolute (`/api/customers`, `api_customer_repository.dart:17`) dan digabung lewat satu pintu `AppConfig.apiBaseUrl`. **Tidak ada file fitur yang perlu disentuh.** |
| `--base-href` / `web/manifest.json` / `go_router` | Web tetap dilayani di **root** alamatnya sendiri. Ini yang batal dari revisi lama. |
| `entra_auth_service.dart` | `${Uri.base.origin}/auth.html` sudah benar untuk web di root (§1.4). |
| `SecurityConfig`, controller | Dicocokkan setelah context-path dipotong (§1.1). |
| Certificate pinning per-host | Berbasis host + rantai sertifikat; `/v2` adalah path, tidak pernah muncul di TLS handshake/SNI. |
| `AndroidManifest.xml`, `network_security_config.xml` | Tidak ada App Link terikat host; yang kedua hanya mengatur cleartext. |
| Staging | Semua variabel baru default kosong → perilaku lama persis. |
| `ssl_config.dart` di root umbrella | **Kode mati** — tidak diimpor siapa pun, berbasis `dio` padahal aplikasi memakai `http`. Abaikan atau hapus terpisah. |

## 6. Verifikasi sebelum rilis

1. Backend lokal dengan prefix: jalankan dengan `MBIS_CONTEXT_PATH=/v2`, lalu
   - `GET /v2/actuator/health` → 200, dan `GET /actuator/health` → 404 (bukti prefix aktif)
   - `POST /v2/api/auth/login` 6× berturut-turut dari satu IP+identifier → yang ke-6 **429**
     (bukti rem brute-force ikut pindah)
2. `mvn test` di `MBIS-backend/backend` (JDK 23 — JDK 25 gagal di lombok/javac).
3. Build web dengan `--build-arg API_URL=...`, buka lewat **HTTPS**, lalu cek berurutan:
   login lokal jalan (bukti secure context + CORS), refresh dalam-rute tidak 404, unggah foto
   kunjungan jalan (bukti `client_max_body_size` + preflight).
4. Cek log backend untuk `OPTIONS` yang dibalas 403 — tanda origin salah tulis (paling sering:
   ikut menuliskan `/v2`, atau port tidak disertakan).
5. `flutter analyze` (**cek exit code**, bukan teks "N issues found") + `flutter test`.

## 7. Yang masih terbuka

- **Alamat web prod** (IP/host + port + apakah HTTPS). Dibutuhkan untuk CORS, Entra, dan
  pengujian. Tanpa HTTPS, §1.3 jadi blocker fungsional.
- **Apakah SSO Microsoft ditargetkan untuk web prod** (§1.4).
- **Alamat publik pengganti halaman kebijakan privasi & hapus akun** (§1.5).
- Apakah pinning TLS ikut dinyalakan saat rilis prod, atau tetap mati seperti sekarang.
- Verifikasi langsung SAN sertifikat `mbis.askrindo.co.id` (§4.6).
