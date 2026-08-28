# MBIS-App — Panduan

Aplikasi M-BIS (Flutter) — **satu codebase untuk web (website) + mobile (app)**: RM + Agen
di lapangan (mobile) dan seluruh peran (DPJ/RO/BM/KUP + operasional) via web.
Konsumsi backend lewat kontrak OpenAPI. Konteks program penuh: [`../CLAUDE.md`](../CLAUDE.md).
Skill: [`../.claude/skills/`](../.claude/skills/).

> **KEPUTUSAN TERBARU (mengganti rencana 3-repo).** Rencana website di **React/Next.js
> (MBIS-Frontend)** **DIBATALKAN**. Website memakai **Flutter Web dari repo ini**, jadi
> **App = web + mobile** (satu codebase, dua target). Struktur akhir = **2 repo**:
> `MBIS-Backend` (Spring Boot) + repo Flutter ini (frontend web + app). MBIS-Frontend (React)
> diarsipkan. Artefak web (`web/`, `Dockerfile`, `nginx.conf`) sudah **dipulihkan** dari
> monorepo pada branch **`feat/restore-flutter-web`** (menunggu tes `flutter build web` + merge).

- **Stack**: Flutter (Android/iOS/**Web**), **Riverpod** (state), **go_router**, `flutter_secure_storage` (token), `http`.
- **Sumber kode**: basis dari [`../MBIS-Refactor/frontend/flutter/`](../MBIS-Refactor/frontend/flutter/) (repo-split). Kode web-specific (`kIsWeb`/`dart:html`/`package:web`, mis. SSO PKCE) tetap ada.
- **Perlu rekonsiliasi:** repo ini sudah di-refactor (feature-first/Riverpod) & sedikit menyimpang dari `origin/staging` monorepo — mis. **`export_screen.dart`** (ada di staging) belum ada di sini. Samakan fitur yang lebih baru di staging saat web jadi acuan.
- **Arsitektur**: feature-first **layered** — `lib/features/<fitur>/{data,domain,presentation}` + `lib/core/` (network, config, router, theme, session). Detail & aturan lapis di [`../CLAUDE.md`](../CLAUDE.md) §3.
- **State management**: kode lama murni `setState` (503 pakai). Migrasi **per modul** ke Riverpod. Gunakan skill **`flutter-riverpod-feature`** untuk fitur baru & migrasi.
- **SSO**: Microsoft Entra ID (PKCE) terpasang parsial. Lihat `sso-askrindo-auth`.
- **Config**: jangan hardcode base URL/flag — lewat `core/config` + `--dart-define`. Lihat `externalize-config`.
- **CI/CD**: manual; iOS via cloud macOS (Codemagic). Bundle id `com.example.mbis` (placeholder). Lihat `ci-pipeline`.

**Pagar**: token di secure storage; PII jangan di-log; migrasi wajib behavior-preserving (UI/alur sama sebelum & sesudah).

**Penyimpanan sesi & HTTP di lingkungan internal (keputusan, 2026-08-28).** Deployment
non-prod **memakai HTTP** — server internal, diakses lewat IP (mis. dev `http://10.100.20.53:3014`),
tanpa TLS dan tanpa rencana menambahkannya. Konsekuensinya nyata: `flutter_secure_storage`
v10 di web memakai `crypto.subtle`, yang browser hanya sediakan di *secure context*
(HTTPS atau `localhost`), sehingga di origin itu login berhasil lalu **gagal saat
menyimpan sesi**. Karena itu `lib/src/auth/session_store.dart` memilih penyimpanan saat
runtime, bukan memaksa satu jalur:

- **web + bukan secure context + `APP_ENV` ∈ {`dev`,`staging`}** → `localStorage` (teks biasa);
- selain itu → secure storage, termasuk **seluruh build prod**, seluruh build native
  (Android/iOS), dan origin non-prod mana pun yang kebetulan sudah HTTPS/`localhost`.

Gerbang `APP_ENV`-nya **allowlist**, bukan `!= prod`, supaya nilai tak dikenal (salah
ketik `production`, atau `--dart-define` yang lupa dipasang — default-nya `dev`)
**gagal-tertutup**: aplikasi tetap memakai secure storage dan melempar error yang
kelihatan, bukan diam-diam menyimpan refresh token 7 hari sebagai teks biasa.

Pagar "token di secure storage" **tetap berlaku penuh untuk prod**. Jangan longgarkan
gerbang ini demi kenyamanan, dan jangan hapus pemeriksaan secure-context-nya walau kini
semua non-prod memakai HTTP: itulah yang membuat fallback **mati sendiri** begitu sebuah
origin naik ke HTTPS (atau dibuka lewat tunnel `http://localhost:<port>`), tanpa perlu
ubah kode maupun variabel baru.

> **Domain staging lama `mbis.askrindo.net` tidak berlaku sejak 2026-08-28.** Non-prod =
> server internal dev: web `http://10.100.20.53:3014`, backend `http://10.100.20.53:3013`.
> Dokumen di `docs/` yang menyebut domain itu adalah laporan bertanggal — dibiarkan apa
> adanya sebagai catatan sejarah, jangan dijadikan acuan keadaan sekarang.
