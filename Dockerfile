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
# PROD memakai topologi lain: satu domain dibagi per prefix path oleh reverse proxy host
# (/etc/nginx/sites-available/mbis), BUKAN per hostname —
#   https://mbis.askrindo.co.id/v2/    -> backend v2 kita (:3023), prefix DIBUANG proxy
#   https://mbis.askrindo.co.id/app/   -> web ini (:3024), prefix DIBUANG proxy
# Karena itu bundle prod wajib tahu prefix API-nya:
#   docker build --build-arg API_URL=https://mbis.askrindo.co.id/v2 ...
# TANPA akhiran '/api' dan tanpa garis miring di akhir; kode fitur menempelkan '/api/...'
# sendiri (root-absolute), sehingga hasilnya https://mbis.askrindo.co.id/v2/api/...
#
# Kalau ARG ini dibiarkan KOSONG saat build prod, bundle memanggil '/api/...' di root
# domain -> proxy host mencocokkannya ke `location /` -> nyasar ke BACKEND V1 dan seluruh
# aplikasi kena 403. Itu bukan masalah CORS; gejalanya mirip tapi penyebabnya routing.
#
# CORS TIDAK diperlukan di topologi ini: web (/app) dan API (/v2) berbagi origin yang
# sama (skema+host+port identik), jadi browser tidak memperlakukannya lintas-origin dan
# MBIS_CORS_ALLOWED_ORIGINS tidak perlu diisi. Ini berbeda dari rencana awal di
# docs/MIGRASI-DOMAIN-PROD-V2.md yang menaruh web di IP privat (beda origin -> CORS wajib);
# rencana itu tidak jadi dipakai.
#
# Nilai yang sama dipakai aplikasi Android/iOS (`--dart-define=API_URL`), jadi jangan
# ubah prefix '/v2' tanpa memperhitungkan APK yang sudah terpasang di HP pengguna.
#
# Sengaja diletakkan SETELAH `flutter pub get`: nilainya berubah tiap ganti target, dan
# ARG di atas COPY pubspec akan membatalkan cache dependensi setiap kali.
#
# Default `/v2` = topologi PROD (lihat penjelasan panjang di atas). Jenkinsfile menimpanya
# per-branch: `main` mengirim URL prod absolut, `testing` mengirim NILAI KOSONG supaya
# staging kembali ke same-origin dan blok /api/ di nginx.conf yang mem-proxy ke backend.
ARG API_URL=/v2

# Prefix path tempat bundle dilayani, HARUS diakhiri garis miring.
# PROD: `/app/` karena reverse proxy host membagi satu domain per prefix path.
# STAGING/DEV: `/` karena bundle dilayani di root origin-nya sendiri.
# Salah nilai di sini = index.html memuat main.dart.js dari path yang tidak ada -> layar putih,
# tanpa error di log nginx selain 404 aset.
ARG BASE_HREF=/app/

# `dev` | `staging` | `prod` — dibaca AppConfig.env (lib/src/config/app_config.dart).
ARG APP_ENV=prod

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
    --base-href "$BASE_HREF" \
    --dart-define=APP_ENV=$APP_ENV \
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

# nginx.conf is an envsubst TEMPLATE (see its header). The stock nginx entrypoint renders
# /etc/nginx/templates/*.template into /etc/nginx/conf.d/ on every start, so the backend the
# /api/ proxy points at is a CONTAINER env var — changing it is a `docker service update
# --env-add`, not a rebuild of the whole Flutter bundle.
#
# NGINX_ENVSUBST_FILTER restricts substitution to names starting with MBIS_. Without it,
# envsubst would also expand nginx's own $host / $uri / $backend into empty strings and the
# container would crash-loop on a syntax error at startup.
ENV NGINX_ENVSUBST_FILTER=^MBIS_

# Defaults reproduce the previously hard-coded target, so a plain `docker build && docker run`
# with no env behaves exactly as before. Dev overrides both (the backend there is a compose
# container reachable only through the host's published port).
ENV MBIS_BACKEND_HOST=mbis-backend
ENV MBIS_BACKEND_PORT=3023

COPY nginx.conf /etc/nginx/templates/default.conf.template

# Drop the image's stock config. If rendering ever fails, nginx should have no config at all
# and refuse to start — far louder than silently serving the nginx welcome page in place of
# the app, which looks like a broken deploy of OUR bundle.
RUN rm -f /etc/nginx/conf.d/default.conf

COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 80
# Use 127.0.0.1 (not localhost): our custom nginx.conf only `listen 80` (IPv4),
# and the base image's IPv6-default script is skipped (it finds no stock default.conf) —
# so `localhost` resolving to ::1 first would make the probe fail and Coolify/Traefik
# mark the container unhealthy ("no available server") even though nginx is serving.
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -qO- http://127.0.0.1:80/ >/dev/null 2>&1 || exit 1
