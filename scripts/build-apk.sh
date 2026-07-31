#!/usr/bin/env bash
# Build APK rilis. Argumen: $1 = flavor (staging|prod), $2 = API_URL backend.
# Contoh: scripts/build-apk.sh staging https://mbis-staging.askrindo.co.id
#         scripts/build-apk.sh prod    https://mbis.askrindo.co.id/v2
set -euo pipefail
FLAVOR="${1:-staging}"
API_URL="${2:-}"
if [[ -z "$API_URL" ]]; then
  echo "[build-apk] API_URL wajib diisi untuk build rilis" >&2
  exit 1
fi
if [[ "$FLAVOR" == "prod" ]]; then APP_ENV=prod; else APP_ENV=staging; fi
# APK = jalur uji internal, jadi URL kebijakan/hapus akun opsional di sini
# (kosong → layar Privasi & Akun menampilkan snackbar "belum dikonfigurasi").
# Untuk rilis ke Play pakai scripts/build-aab.sh, yang mewajibkan semuanya terisi.
flutter build apk --release --flavor "$FLAVOR" \
  --dart-define=API_URL="$API_URL" \
  --dart-define=APP_ENV="$APP_ENV" \
  --dart-define=PRIVACY_POLICY_URL="${PRIVACY_POLICY_URL:-}" \
  --dart-define=ACCOUNT_DELETION_URL="${ACCOUNT_DELETION_URL:-}" \
  --dart-define=PRIVACY_CONTACT_EMAIL="${PRIVACY_CONTACT_EMAIL:-}"
