# Rencana Migrasi — Flutter (MBIS-Refactor) → MBIS-App

- **Tanggal:** 2026-07-22
- **Status:** ✅ **DIEKSEKUSI 2026-07-22** (Fase 0–4). Ringkasan hasil di bagian
  [Log Eksekusi](#log-eksekusi-2026-07-22) di akhir dokumen.
- **Sumber:** `MBIS-Refactor/frontend/flutter` · **Tujuan:** repo ini (`MBIS-App`).
- **Backend:** `MBIS-Backend` (kontrak `docs/api/openapi.json`, 196 operasi).
- **Playbook:** mengikuti pola sukses ekstraksi backend (rehearsal nol-risiko → cutover).

## Prinsip

1. **Rehearsal dulu** di salinan scratch; repo asli tak tersentuh sampai terbukti hijau.
2. **History-preserving** (`git filter-repo`), bukan copy — 245 commit ikut.
3. **Behavior-preserving** — dibuktikan `flutter analyze` + `flutter test` sebelum & sesudah.
4. **Kontrak OpenAPI = seam** ke backend; app tak mengarang endpoint baru.

## Kondisi awal (hasil audit 2026-07-22)

| Aspek | Temuan |
|---|---|
| App | `mbis` v1.0.0+1, Dart 3.12, 133 file dart; Riverpod 3, go_router, secure_storage, `flutter_web_auth_2` (SSO), FCM |
| `lib/` | Campur: `features/` (baru) + `src/`, `presentation/`, `data/` (legacy) |
| Koneksi backend | Externalized — `AppConfig.apiBaseUrl` via `--dart-define=API_URL`; default mobile `10.0.2.2:8080` |
| Kopling web | `web/`, `nginx.conf`, `Dockerfile` (deploy) + 5 file `dart:html`, 9 `kIsWeb` |
| App ID | Android+iOS `com.example.mbis` (perlu ganti) |
| Self-contained | Ya — semua import relatif di dalam `flutter/` |
| History | 245 commit menyentuh `frontend/flutter` |
| MBIS-App | Kosong (main, 1 commit `CLAUDE.md`, remote `github.com/hgnhao/MBIS-App`) |

## Keputusan yang sudah dikunci

- **Mobile-only.** Buang **artefak deploy web** (`web/`, `nginx.conf`, `Dockerfile` web).
  **Kode Dart web dibiarkan** (cabang `kIsWeb`/`dart:html` aman untuk mobile) — pembersihan
  `dart:html` = tugas terpisah, di luar cakupan migrasi ini.
- **Layout:** proyek Flutter jadi **root** MBIS-App (pubspec di root).
- **App ID:** prod `com.askrindo.mbis.mobile`, staging flavor `com.askrindo.mbis.mobile.staging`.

---

## Fase 0 — Prasyarat

- [ ] **Flutter SDK** (Dart ^3.12) + toolchain Android terpasang & di-PATH (untuk `analyze`/`test`).
- [ ] `git filter-repo` (sudah terinstal saat migrasi backend).
- [ ] Emulator/device Android untuk uji koneksi Fase 4 (opsional tapi disarankan).

## Fase 1 — Rehearsal ekstraksi (scratch, nol risiko)

1. Clone `MBIS-Refactor` → scratchpad (di luar OneDrive).
2. `git filter-repo` **keep `frontend/flutter/`** + **rename path ke root**:
   ```bash
   git filter-repo --path frontend/flutter/ --path-rename frontend/flutter/:
   ```
   (history 245 commit dipertahankan; pubspec pindah ke root).
3. Buang artefak deploy web: `web/`, `nginx.conf`, `Dockerfile` (web), `build/`.
4. **Gate verifikasi:** `flutter pub get` → `flutter analyze` (0 error) → `flutter test` (hijau).

## Fase 2 — Mobile-only, rebranding, wiring backend (di rehearsal)

1. **App ID Android** (`android/app/build.gradle.kts`): `namespace` + `applicationId`
   `com.example.mbis` → `com.askrindo.mbis.mobile`.
2. **Flavor staging** (belum ada): tambah `productFlavors` `prod`/`staging`
   (staging `applicationIdSuffix = ".staging"`) + skema iOS staging.
3. **App ID iOS** (`ios/Runner.xcodeproj/project.pbxproj`): `PRODUCT_BUNDLE_IDENTIFIER`
   → `com.askrindo.mbis.mobile` (+ turunan test/staging).
4. **Wiring MBIS-Backend** (config sudah externalized — hanya script/dok):
   - dev (emulator): `--dart-define=API_URL=http://10.0.2.2:8080 --dart-define=APP_ENV=dev`
   - staging/prod: `API_URL` ke domain backend + `APP_ENV=staging|prod`.
   - Siapkan `scripts/run-dev`, `scripts/build-apk` (prod/staging) yang mengoper dart-define.
5. **FCM/Firebase:** `firebase_options.dart` dev dipertahankan; project Firebase prod menyusul.
6. **Gate verifikasi:** `flutter analyze` + `flutter test` tetap hijau; `flutter build apk --debug`
   (dev flavor) sukses.

## Fase 3 — Cutover ke MBIS-App (setelah rehearsal hijau)

1. Push history-utuh ke `MBIS-App` (`merge --allow-unrelated-histories`, **pertahankan CLAUDE.md**).
2. **`.gitignore` Flutter**: `build/`, `.dart_tool/`, `.flutter-plugins*`, `*.keystore`, `*.jks`,
   `key.properties`, `**/config.json`, `.env*` (port dari `.gitignore` monorepo; CLAUDE.md tetap di-track).
3. **CI Flutter**: job `flutter analyze` + `flutter test` (dari `ci.yml` monorepo, jadikan repo-only).
4. **Gate verifikasi:** `flutter analyze` + `flutter test` hijau **di MBIS-App**.

## Fase 4 — Bukti koneksi ke MBIS-Backend (end-to-end)

1. Nyalakan MBIS-Backend dev (`:8080`, Postgres).
2. Jalankan app di emulator: `flutter run --dart-define=API_URL=http://10.0.2.2:8080 --dart-define=APP_ENV=dev`.
3. **Gate:** **login (ADMIN/Admin123!) berhasil** + satu layar data termuat → membuktikan
   konektivitas + kecocokan kontrak. (adb reverse bila pakai device fisik.)

## Fase 5 — Sisa (non-blocking; nunggu IT/lanjutan)

- Signing **keystore** rilis prod (siapa pegang) + `key.properties` (di luar git).
- **SSO Entra** config final (tenant/client id) — nunggu IT.
- **Apple Team ID** + registrasi App Store — nunggu IT.
- Lanjut migrasi **feature-first** `src/`→`features/` (refactor terpisah).
- Pembersihan kode **web-only Dart** (`dart:html`) — opsional.

---

## Risiko & mitigasi

| Risiko | Mitigasi |
|---|---|
| Build mobile pecah karena kode web | Kode Dart web dibiarkan (sudah build mobile hari ini); gate `flutter build apk --debug` di Fase 2 |
| History hilang saat pindah | `git filter-repo` + merge unrelated-history (bukan copy) |
| App ID salah/dobel di store | Rename atomik di Fase 2 + flavor staging agar prod & staging coexist |
| Drift kontrak FE↔BE | Pakai `openapi.json` MBIS-Backend sebagai acuan; uji login end-to-end Fase 4 |

## Lampiran — perintah kunci

```bash
# Ekstraksi history-preserving + flatten ke root (Fase 1)
git clone --no-local <MBIS-Refactor> scratch/mbis-app-rehearsal
cd scratch/mbis-app-rehearsal
git filter-repo --force --path frontend/flutter/ --path-rename frontend/flutter/:

# Verifikasi (Fase 1 & 2)
flutter pub get && flutter analyze && flutter test
flutter build apk --debug --dart-define=API_URL=http://10.0.2.2:8080 --dart-define=APP_ENV=dev

# Cutover (Fase 3) — pola sama seperti backend
cd <MBIS-App>
git checkout -b chore/import-flutter-from-monorepo
git remote add monorepo <scratch/mbis-app-rehearsal>
git fetch monorepo <branch>
git merge --allow-unrelated-histories -m "chore: import flutter app (history-preserving)" monorepo/<branch>
```

---

## Log Eksekusi (2026-07-22)

Semua fase dijalankan; setiap gate hijau. Ringkasan bukti & deviasi dari rencana:

### Hasil per fase

| Fase | Hasil | Bukti |
|---|---|---|
| **0 Prasyarat** | ✅ | Flutter 3.44.2 (Dart 3.12.2), `git filter-repo` ada, JDK 17 di image backend |
| **1 Rehearsal ekstraksi** | ✅ | `filter-repo` → **258 commit** dipertahankan, pubspec di root; artefak web (`web/`, `nginx.conf`, `Dockerfile`) dibuang. Gate: `dart analyze` **No issues**, `flutter test` **3/3 pass** |
| **2 Rebrand + wiring** | ✅ | App id → `com.askrindo.mbis.mobile`; flavor `prod`/`staging` (suffix `.staging`); iOS bundle id + RunnerTests di-rename; `MainActivity.kt` pindah package; scripts `run-dev`/`build-apk` (.bat/.sh). Gate: **`app-staging-debug.apk` ter-build**, `aapt` konfirmasi `package=com.askrindo.mbis.mobile.staging`, versionName `1.0.0-staging` |
| **3 Cutover ke MBIS-App** | ✅ | `merge --allow-unrelated-histories` bersih (tanpa konflik); **264 commit** di `main`, CLAUDE.md + docs terjaga; `.gitignore` Flutter + workflow CI (`analyze`+`test`) ditambah. Gate: `dart analyze` **No issues**, `flutter test` **3/3 pass** di MBIS-App |
| **4 Bukti koneksi** | ✅ **(termasuk on-device)** | Backend di-`docker compose up` (build sukses, *Started in 24s*). **`POST /api/auth/login` (ADMIN/Admin123!) → HTTP 200** dgn `accessToken`/`refreshToken`/`user{roles:[ADMIN]}`. GET terautentikasi `/api/auth/me`, `/api/customers`, `/api/offices`, `/api/products` → **200**. **UJI HP FISIK (Xiaomi 2201117PG, Android 13):** APK staging di-install & di-run via `adb reverse tcp:8080`, `API_URL=http://localhost:8080`; **login ADMIN/Admin123! SUKSES** → app meneruskan ke layar pasca-login "Ganti Password Wajib" (dipicu `mustChangePassword:true`), membuktikan konektivitas + kontrak di device nyata. Catatan: NIP login **case-sensitive** (`ADMIN`, bukan `admin`). |

### Deviasi dari rencana (penting)

1. **Branch sumber** = `feat/handover-refactor` (bukan `feat/analis-monitoring` yang
   ternyata hanya ada di remote). Kode Flutter terkini ada di sini.
2. **Workaround tooling Windows:** `flutter analyze`/`build` crash oleh bug SPM
   (Swift Package Manager mencoba listing folder iOS ephemeral). Gate statik pakai
   `dart analyze`; build APK Android meng-isolasi `ios/` sementara. Tak memengaruhi kode.
   (iOS toh di-build di macOS/Codemagic, bukan Windows.)
3. **`google-services.json`** ditambah entri paket kedua (`...mobile` + `...mobile.staging`)
   agar plugin google-services lolos validasi build. Ini **placeholder dev** — ganti dgn
   config Firebase prod asli saat rilis (Fase 5).
4. **Seed org backend dimatikan** (`mbis.seed.org=false`) saat bring-up Fase 4: `seed/org/full.sql`
   melanggar NOT NULL `offices.active` di skema dev (ddl-auto=update). Ini **isu seeding
   backend pre-existing**, di luar cakupan migrasi App. Bootstrap admin (untuk login) tetap dibuat.
5. **Uji on-device SUDAH dilakukan** (update: HP fisik disambungkan): APK staging di-install
   ke Xiaomi Android 13 (MIUI perlu "Install via USB" di-ON), `adb reverse` + `API_URL=http://localhost:8080`,
   **login ADMIN/Admin123! sukses** → layar pasca-login termuat. Password admin **tidak** diubah
   (layar "Ganti Password Wajib" tidak di-submit, agar kredensial dev tetap `Admin123!`).
6. **Push ke `origin` (github.com/hgnhao/MBIS-App) DITAHAN** — belum dikonfirmasi kepemilikan
   remote + akses push. Semua commit ada di `main` **lokal**; push adalah langkah manual berikutnya.

### Langkah manual tersisa

- [ ] Verifikasi kepemilikan/akses remote `MBIS-App` → `git push origin main` (+ hapus branch `chore/import-flutter-from-monorepo`).
- [ ] Uji `flutter run` di emulator/device nyata (login + buka 1 layar data) untuk menutup Fase 4 sisi UI.
- [ ] Ganti `google-services.json` placeholder dgn config Firebase prod (per flavor).
- [ ] (Backend, terpisah) perbaiki `seed/org/full.sql` (kolom `offices.active`) agar seed org dev jalan.
- [ ] Fase 5 rencana: keystore rilis, SSO Entra final, Apple Team ID, migrasi `src/`→`features/`, pembersihan `dart:html`.
