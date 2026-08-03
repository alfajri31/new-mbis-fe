#!/usr/bin/env bash
# Build APK rilis. Argumen: $1 = flavor (staging|prod), $2 = API_URL backend.
# Contoh: scripts/build-apk.sh staging https://mbis-staging.askrindo.co.id
#         scripts/build-apk.sh prod    https://mbis.askrindo.co.id/v2
set -euo pipefail

# Flutter yang di-pin .fvmrc, bukan yang kebetulan ada di PATH. Lihat _flutter.sh.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_flutter.sh"
FLAVOR="${1:-staging}"
API_URL="${2:-}"
if [[ -z "$API_URL" ]]; then
  echo "[build-apk] API_URL wajib diisi untuk build rilis" >&2
  exit 1
fi
if [[ "$FLAVOR" == "prod" ]]; then APP_ENV=prod; else APP_ENV=staging; fi

# Host yang trust store-nya dipersempit ke assets/ssl (lib/src/network/ssl_pinning.dart).
#
# Ini BUKAN sekadar pengerasan opsional. `mbis.askrindo.co.id` mengirim sertifikat
# leaf SAJA — intermediate Sectigo R36 dan R46 tidak ikut. Browser menutupi itu
# dengan menjemput issuer lewat AIA; Dart/BoringSSL tidak. Akibatnya build tanpa
# rantai bundled gagal `CERTIFICATE_VERIFY_FAILED: unable to get local issuer
# certificate` saat login, sedangkan `curl` di mesin yang sama tampak lancar
# karena OS-nya menjemput issuer sendiri. Berkas di assets/ssl memasok rantai itu.
#
# Auto-isi dibatasi ke domain askrindo.co.id: mem-pin host lain (mis. staging di
# Coolify) ke rantai Askrindo justru memutus koneksi yang tadinya sehat.
# Set SSL_PINNED_HOSTS="" secara eksplisit untuk mematikan.
API_HOST="$(sed -E 's#^[a-z]+://##; s#[/:?].*$##' <<<"$API_URL")"
case "$API_HOST" in
  *askrindo.co.id) SSL_PINNED_HOSTS="${SSL_PINNED_HOSTS-$API_HOST}" ;;
  *)               SSL_PINNED_HOSTS="${SSL_PINNED_HOSTS-}" ;;
esac

# Preflight: buktikan rantai bundled benar-benar memvalidasi sertifikat host ini
# SEBELUM APK dibuat. Domain askrindo.co.id tidak menjamin sertifikat yang sama —
# staging di Coolify menerbitkan sertifikatnya sendiri, dan mem-pin host itu ke
# rantai Sectigo akan menghasilkan APK yang gagal login di setiap perangkat.
#
# Sengaja PERINGATAN, bukan penghentian: build sering berjalan di mesin yang tidak
# punya rute ke host tujuan (CI, jaringan lain), dan menolak build karena itu jauh
# lebih mengganggu daripada gejala yang diperingatkan.
if [[ -n "$SSL_PINNED_HOSTS" ]] && command -v openssl >/dev/null 2>&1; then
  CERT_ASSET="$(dirname "${BASH_SOURCE[0]}")/../assets/ssl/askrindo-fullchain-2026-2027.crt"
  if PROBE="$(openssl s_client -servername "$API_HOST" -connect "$API_HOST:443" \
       -CAfile "$CERT_ASSET" -verify_return_error </dev/null 2>&1)"; then
    echo "[build-apk] pinning: rantai bundled cocok untuk $API_HOST"
  elif grep -q "verify error" <<<"$PROBE"; then
    echo "[build-apk] PERINGATAN: sertifikat $API_HOST TIDAK divalidasi oleh" >&2
    echo "            assets/ssl/askrindo-fullchain-2026-2027.crt. APK ini akan" >&2
    echo "            gagal handshake saat login. Perbarui berkas rantai, atau" >&2
    echo "            build ulang dengan SSL_PINNED_HOSTS=\"\" untuk melepas pinning." >&2
  else
    echo "[build-apk] pinning: $API_HOST tak terjangkau dari mesin ini, preflight dilewati" >&2
  fi
fi
# APK = jalur uji internal, jadi URL kebijakan/hapus akun opsional di sini
# (kosong → layar Privasi & Akun menampilkan snackbar "belum dikonfigurasi").
# Untuk rilis ke Play pakai scripts/build-aab.sh, yang mewajibkan semuanya terisi.
"${FLUTTER[@]}" build apk --release --flavor "$FLAVOR" \
  --dart-define=API_URL="$API_URL" \
  --dart-define=APP_ENV="$APP_ENV" \
  --dart-define=SSL_PINNED_HOSTS="$SSL_PINNED_HOSTS" \
  --dart-define=PRIVACY_POLICY_URL="${PRIVACY_POLICY_URL:-}" \
  --dart-define=ACCOUNT_DELETION_URL="${ACCOUNT_DELETION_URL:-}" \
  --dart-define=PRIVACY_CONTACT_EMAIL="${PRIVACY_CONTACT_EMAIL:-}"
