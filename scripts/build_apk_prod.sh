#!/usr/bin/env bash
# =============================================================================
# Build APK PRODUKSI (obfuscated) — sama persis dengan konfigurasi run
# "MBIS Prod (mobile, SSL pinning)" di .vscode/launch.json, hanya mode rilis.
#
#   scripts/build_apk_prod.sh
#   scripts/build_apk_prod.sh https://mbis.askrindo.co.id/v2   # override API_URL
#
# APK ini untuk uji internal / distribusi manual. Untuk unggah ke Play Console
# pakai scripts/build-aab.sh, yang mewajibkan URL kebijakan privasi & hapus akun.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Flutter yang di-pin .fvmrc, bukan yang kebetulan ada di PATH. Lihat _flutter.sh.
source "$REPO_ROOT/scripts/_flutter.sh"

# Prefix /v2 wajib: domain mbis.askrindo.co.id dibagi per path oleh reverse proxy
# (/v2 -> backend v2, /app -> web). Tanpa prefix, request nyasar ke backend v1
# dan seluruh app kena 403. Kode fitur menempel '/api/...' sendiri.
API_URL="${1:-${API_URL:-https://mbis.askrindo.co.id/v2}}"

[[ "$API_URL" != http://* ]] || {
  echo "[build-apk-prod] GAGAL: API_URL memakai HTTP polos. Build prod menolak cleartext." >&2
  exit 1
}

# Certificate pinning (lib/src/network/ssl_pinning.dart).
#
# BUKAN pengerasan opsional: mbis.askrindo.co.id mengirim sertifikat leaf SAJA —
# intermediate Sectigo R36 dan R46 tidak ikut. Browser dan curl menutupi itu
# dengan menjemput issuer lewat AIA; Dart/BoringSSL tidak. APK tanpa rantai
# bundled gagal `CERTIFICATE_VERIFY_FAILED` sejak layar login, walau server
# terlihat sehat dari laptop. Rantai di assets/ssl memasok intermediate itu.
#
# Auto-isi dibatasi ke domain askrindo.co.id: mem-pin host lain ke rantai
# Askrindo justru memutus koneksi yang tadinya sehat.
# Set SSL_PINNED_HOSTS="" secara eksplisit untuk mematikan.
API_HOST="$(sed -E 's#^[a-z]+://##; s#[/:?].*$##' <<<"$API_URL")"
case "$API_HOST" in
  *askrindo.co.id) SSL_PINNED_HOSTS="${SSL_PINNED_HOSTS-$API_HOST}" ;;
  *)               SSL_PINNED_HOSTS="${SSL_PINNED_HOSTS-}" ;;
esac

# `tr -d '\r'` wajib: pubspec.yaml berakhiran CRLF, jadi tanpa ini APP_VERSION
# membawa carriage return dan nama direktori symbols ikut mengandung \r —
# flutter lalu gagal dengan pesan yang menampilkan diri sendiri secara terpotong
# ("Target file "--split-debug-info=symbols/production-1.0.0+1^M" not found").
APP_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | tr -d '\r')"
SYMBOLS_DIR="symbols/production-${APP_VERSION}"

# Dart-define disusun sebagai array, dan yang nilainya KOSONG tidak diikutkan.
# `--dart-define=FOO=` bernilai kosong membuat parser argumen flutter berhenti
# memperlakukan token berikutnya sebagai opsi, sehingga `--split-debug-info=...`
# terbaca sebagai target file. Gejalanya menunjuk ke flag yang salah, jadi
# jangan "rapikan" ini kembali menjadi daftar tetap.
DEFINES=(
  "--dart-define=API_URL=$API_URL"
  "--dart-define=APP_ENV=prod"
)
# Bentuk `if`, bukan `[[ ... ]] && ...`: di bawah `set -e` baris terakhir yang
# tesnya gagal mengembalikan status 1 dan menghentikan seluruh script.
if [[ -n "$SSL_PINNED_HOSTS" ]]; then
  DEFINES+=("--dart-define=SSL_PINNED_HOSTS=$SSL_PINNED_HOSTS")
fi
if [[ -n "${PRIVACY_POLICY_URL:-}" ]]; then
  DEFINES+=("--dart-define=PRIVACY_POLICY_URL=$PRIVACY_POLICY_URL")
fi
if [[ -n "${ACCOUNT_DELETION_URL:-}" ]]; then
  DEFINES+=("--dart-define=ACCOUNT_DELETION_URL=$ACCOUNT_DELETION_URL")
fi
if [[ -n "${PRIVACY_CONTACT_EMAIL:-}" ]]; then
  DEFINES+=("--dart-define=PRIVACY_CONTACT_EMAIL=$PRIVACY_CONTACT_EMAIL")
fi

echo "==========================================="
echo "  Building MBIS Production APK"
echo "  versi     : ${APP_VERSION}"
echo "  API_URL   : ${API_URL}"
echo "  pinning   : ${SSL_PINNED_HOSTS:-(mati)}"
echo "==========================================="

# Preflight: buktikan rantai bundled memvalidasi sertifikat host tujuan sebelum
# APK dibuat. Sengaja PERINGATAN, bukan penghentian — build sering berjalan di
# mesin tanpa rute ke host tujuan, dan menolak build karena itu lebih mengganggu
# daripada gejala yang diperingatkan.
if [[ -n "$SSL_PINNED_HOSTS" ]] && command -v openssl >/dev/null 2>&1; then
  CERT_ASSET="$REPO_ROOT/assets/ssl/askrindo-fullchain-2026-2027.crt"
  if PROBE="$(openssl s_client -servername "$API_HOST" -connect "$API_HOST:443" \
       -CAfile "$CERT_ASSET" -verify_return_error </dev/null 2>&1)"; then
    echo "[build-apk-prod] pinning: rantai bundled cocok untuk $API_HOST"
  elif grep -q "verify error" <<<"$PROBE"; then
    echo "[build-apk-prod] PERINGATAN: sertifikat $API_HOST TIDAK divalidasi oleh" >&2
    echo "                assets/ssl/askrindo-fullchain-2026-2027.crt. APK ini akan" >&2
    echo "                gagal handshake saat login. Perbarui berkas rantai, atau" >&2
    echo "                build ulang dengan SSL_PINNED_HOSTS=\"\"." >&2
  else
    echo "[build-apk-prod] pinning: $API_HOST tak terjangkau dari mesin ini, preflight dilewati" >&2
  fi
fi

"${FLUTTER[@]}" clean
"${FLUTTER[@]}" pub get
mkdir -p "$SYMBOLS_DIR"

# Flavor `prod` (bukan `production`) dan entrypoint tunggal lib/main.dart —
# repo ini tidak memakai pola main_<flavor>.dart seperti aplikasi lama.
# Lihat productFlavors di android/app/build.gradle.kts.
"${FLUTTER[@]}" build apk --release --flavor prod \
  "${DEFINES[@]}" \
  --obfuscate --split-debug-info="$SYMBOLS_DIR"

echo ""
echo "==========================================="
echo "  Build complete!"
echo "  APK     : build/app/outputs/flutter-apk/app-prod-release.apk"
echo "  Symbols : ${SYMBOLS_DIR}  (simpan — tanpa ini stack trace crash tak terbaca)"
echo "==========================================="
