# syntax=docker/dockerfile:1

# ---------------------------------------------------------------------------
# Stage 1: Build the Flutter web bundle.
# Pin FLUTTER_VERSION to the newest image cirruslabs actually publishes. The team's
# local SDK is 3.44.3 (Dart 3.12.2), but cirruslabs lags patch releases and only has
# 3.44.0 (Dart 3.12.0) so far — so we pin 3.44.0 and lower the app's Dart floor to
# ^3.12.0 (see pubspec.yaml). Bump both back to 3.44.3 once cirruslabs publishes it:
#   docker manifest inspect ghcr.io/cirruslabs/flutter:3.44.3
# ---------------------------------------------------------------------------
ARG FLUTTER_VERSION=3.44.0
FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION} AS build
WORKDIR /app

# Maps use free OpenStreetMap tiles — no API key needed.

# Resolve dependencies first for layer caching.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Microsoft Entra SSO (public identifiers — safe to bake into the client bundle).
# Supply at build time, e.g. Coolify build args or:
#   docker build --build-arg ENTRA_TENANT_ID=... --build-arg ENTRA_CLIENT_ID=...
# Left empty by default -> the "Masuk dengan Microsoft" button is simply hidden and
# the app falls back to local login. The web redirect is always <origin>/auth.html,
# so no redirect URI is passed here.
ARG ENTRA_TENANT_ID=
ARG ENTRA_CLIENT_ID=

# Base URL backend. KOSONG = perilaku lama: web memanggil '/api' di origin-nya sendiri dan
# nginx (stage 2) mem-proxy-nya ke backend, sehingga ganti domain tidak perlu rebuild. Itu
# yang masih dipakai staging (mbis.askrindo.net) dan wajib tetap begitu.
#
# PROD memakai topologi lain: API publik di https://mbis.askrindo.co.id/v2 sementara web
# dilayani terpisah di IP privat — beda origin, jadi bundle harus tahu alamat penuh API:
#   docker build --build-arg API_URL=https://mbis.askrindo.co.id/v2 ...
# TANPA akhiran '/api' dan tanpa garis miring di akhir; kode fitur menempelkan '/api/...'
# sendiri. Konsekuensi yang tidak boleh dilupakan: begitu ini diisi, backend WAJIB
# mengizinkan origin web di MBIS_CORS_ALLOWED_ORIGINS — kalau tidak seluruh web kena 403
# padahal aplikasi HP tetap normal. Lihat docs/MIGRASI-DOMAIN-PROD-V2.md.
#
# Sengaja diletakkan SETELAH `flutter pub get`: nilainya berubah tiap ganti target, dan
# ARG di atas COPY pubspec akan membatalkan cache dependensi setiap kali.
ARG API_URL=

# --wasm: compile Dart to WasmGC (skwasm renderer) instead of JavaScript. The app
# runs as compiled WebAssembly -> no multi-MB main.dart.js to parse/JIT on the main
# thread (that was ~4.4s of CPU at first load), and skwasm is a smaller renderer
# (~1.5MB gz) than CanvasKit (~2.2MB gz). The build still emits main.dart.js as an
# automatic fallback, so browsers without WasmGC (older Safari/Chrome) keep working
# unchanged -> this is a pure progressive enhancement. NOTE: serving requires the
# .mjs MIME fix in nginx.conf; no COOP/COEP needed (single-threaded skwasm).
#
# --no-web-resources-cdn: self-host the renderer (skwasm/canvaskit .wasm/.js) from
# our own nginx instead of pulling from gstatic.com on every cold start -> removes a
# third-party DNS+TLS round-trip and lets the files be compressed & hard-cached.
RUN flutter build web --wasm --release --no-web-resources-cdn \
    --dart-define=API_URL=$API_URL \
    --dart-define=ENTRA_TENANT_ID=$ENTRA_TENANT_ID \
    --dart-define=ENTRA_CLIENT_ID=$ENTRA_CLIENT_ID

# Pre-compress the static bundle ONCE, here at build time, and drop dead weight.
# nginx then serves the .gz siblings via `gzip_static on` (stage 2) instead of
# re-gzipping the 3+MB wasm on EVERY cold visitor — the old on-the-fly `gzip`
# did that per request, burning VPS CPU and delaying TTFB. Doing it once also
# lets us use max compression (gzip -9) for free.
#   - Delete *.symbols: skwasm/canvaskit debug symbol maps (~8MB) that the
#     browser never fetches at runtime — pure image bloat that slows deploys.
#   - Only compress text/wasm/font assets; skip png/webp/ico (already compressed).
RUN find build/web -type f -name '*.symbols' -delete && \
    find build/web -type f \( -name '*.js' -o -name '*.mjs' -o -name '*.wasm' \
        -o -name '*.css' -o -name '*.json' -o -name '*.svg' -o -name '*.ttf' \
        -o -name '*.otf' \) -exec gzip -9 -k {} \;

# ---------------------------------------------------------------------------
# Stage 2: Serve the static bundle with nginx and reverse-proxy /api -> backend.
# ---------------------------------------------------------------------------
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
# Use 127.0.0.1 (not localhost): our custom nginx.conf only `listen 80` (IPv4),
# and the base image's IPv6-default script is skipped because the conf differs —
# so `localhost` resolving to ::1 first would make the probe fail and Coolify/Traefik
# mark the container unhealthy ("no available server") even though nginx is serving.
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://127.0.0.1:80/ >/dev/null 2>&1 || exit 1
