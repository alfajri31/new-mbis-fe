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
