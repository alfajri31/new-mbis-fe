#!/usr/bin/env bash
# Jalankan app di emulator Android terhadap MBIS-Backend lokal (dev).
# Emulator Android memetakan host lewat 10.0.2.2. Untuk device fisik jalankan
# `adb reverse tcp:8080 tcp:8080` lalu set MBIS_API_URL=http://localhost:8080.
set -euo pipefail
API_URL="${MBIS_API_URL:-http://10.0.2.2:8080}"
flutter run --flavor staging \
  --dart-define=API_URL="$API_URL" \
  --dart-define=APP_ENV=dev
