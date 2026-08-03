#!/usr/bin/env bash
# =============================================================================
# Build IPA PRODUKSI (obfuscated) — padanan iOS dari scripts/build_apk_prod.sh,
# dengan dart-define yang sama persis, termasuk SSL pinning.
#
#   scripts/build_ipa_prod.sh
#   scripts/build_ipa_prod.sh https://mbis.askrindo.co.id/v2   # override API_URL
#
# Penandatanganan (pilih salah satu, lewat environment variable):
#   EXPORT_METHOD=ad-hoc|development|app-store|enterprise   (bawaan: ad-hoc)
#   EXPORT_OPTIONS_PLIST=/path/ExportOptions.plist          (menang atas EXPORT_METHOD)
#   SKIP_CODESIGN=1   -> `flutter build ios --no-codesign`, menghasilkan .app
#                        (BUKAN .ipa) untuk memeriksa kompilasi tanpa sertifikat
#
# Bundle id: com.askrindo.mbis.mobile. Untuk unggah ke TestFlight pakai
# codemagic.yaml (workflow ios-release) yang sudah memegang sertifikat App Store.
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Flutter yang di-pin .fvmrc, bukan yang kebetulan ada di PATH. Lihat _flutter.sh.
source "$REPO_ROOT/scripts/_flutter.sh"

[[ "$(uname -s)" == "Darwin" ]] || {
  echo "[build-ipa-prod] GAGAL: build iOS hanya bisa di macOS ber-Xcode." >&2
  exit 1
}
command -v xcodebuild >/dev/null 2>&1 || {
  echo "[build-ipa-prod] GAGAL: xcodebuild tidak ditemukan. Pasang Xcode + command line tools." >&2
  exit 1
}

# Prefix /v2 wajib: domain mbis.askrindo.co.id dibagi per path oleh reverse proxy
# (/v2 -> backend v2, /app -> web). Tanpa prefix, request nyasar ke backend v1
# dan seluruh app kena 403. Kode fitur menempel '/api/...' sendiri.
API_URL="${1:-${API_URL:-https://mbis.askrindo.co.id/v2}}"

[[ "$API_URL" != http://* ]] || {
  echo "[build-ipa-prod] GAGAL: API_URL memakai HTTP polos. Build prod menolak cleartext." >&2
  exit 1
}

# Certificate pinning (lib/src/network/ssl_pinning.dart).
#
# BUKAN pengerasan opsional: mbis.askrindo.co.id mengirim sertifikat leaf SAJA —
# intermediate Sectigo R36 dan R46 tidak ikut. Browser dan curl menutupi itu
# dengan menjemput issuer lewat AIA; Dart/BoringSSL tidak. Build tanpa rantai
# bundled gagal `CERTIFICATE_VERIFY_FAILED` sejak layar login.
#
# Catatan khusus iOS: gejalanya lebih mudah menipu di sini. Simulator memakai
# Keychain macOS yang MENJEMPUT issuer lewat AIA, jadi build tanpa pinning bisa
# tampak sehat di simulator lalu gagal di perangkat asli. Jangan jadikan
# simulator sebagai bukti.
#
# Set SSL_PINNED_HOSTS="" secara eksplisit untuk mematikan.
API_HOST="$(sed -E 's#^[a-z]+://##; s#[/:?].*$##' <<<"$API_URL")"
case "$API_HOST" in
  *askrindo.co.id) SSL_PINNED_HOSTS="${SSL_PINNED_HOSTS-$API_HOST}" ;;
  *)               SSL_PINNED_HOSTS="${SSL_PINNED_HOSTS-}" ;;
esac

# `tr -d '\r'` wajib: pubspec.yaml berakhiran CRLF, jadi tanpa ini APP_VERSION
# membawa carriage return dan nama direktori symbols ikut mengandung \r —
# flutter lalu gagal dengan pesan yang menampilkan diri sendiri secara terpotong.
APP_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | tr -d '\r')"
SYMBOLS_DIR="symbols/ios-production-${APP_VERSION}"

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

SKIP_CODESIGN="${SKIP_CODESIGN:-0}"
EXPORT_METHOD="${EXPORT_METHOD:-ad-hoc}"

echo "==========================================="
echo "  Building MBIS Production IPA"
echo "  versi     : ${APP_VERSION}"
echo "  API_URL   : ${API_URL}"
echo "  pinning   : ${SSL_PINNED_HOSTS:-(mati)}"
if [[ "$SKIP_CODESIGN" == "1" ]]; then
  echo "  signing   : DILEWATI (hasil .app, bukan .ipa)"
elif [[ -n "${EXPORT_OPTIONS_PLIST:-}" ]]; then
  echo "  signing   : ${EXPORT_OPTIONS_PLIST}"
else
  echo "  signing   : --export-method ${EXPORT_METHOD}"
fi
echo "==========================================="

# Preflight: buktikan rantai bundled memvalidasi sertifikat host tujuan sebelum
# build. Sengaja PERINGATAN, bukan penghentian — mesin build belum tentu punya
# rute ke host tujuan, dan menolak build karena itu lebih mengganggu daripada
# gejala yang diperingatkan.
if [[ -n "$SSL_PINNED_HOSTS" ]] && command -v openssl >/dev/null 2>&1; then
  CERT_ASSET="$REPO_ROOT/assets/ssl/askrindo-fullchain-2026-2027.crt"
  if PROBE="$(openssl s_client -servername "$API_HOST" -connect "$API_HOST:443" \
       -CAfile "$CERT_ASSET" -verify_return_error </dev/null 2>&1)"; then
    echo "[build-ipa-prod] pinning: rantai bundled cocok untuk $API_HOST"
  elif grep -q "verify error" <<<"$PROBE"; then
    echo "[build-ipa-prod] PERINGATAN: sertifikat $API_HOST TIDAK divalidasi oleh" >&2
    echo "                assets/ssl/askrindo-fullchain-2026-2027.crt. Build ini akan" >&2
    echo "                gagal handshake saat login. Perbarui berkas rantai, atau" >&2
    echo "                build ulang dengan SSL_PINNED_HOSTS=\"\"." >&2
  else
    echo "[build-ipa-prod] pinning: $API_HOST tak terjangkau dari mesin ini, preflight dilewati" >&2
  fi
fi

"${FLUTTER[@]}" clean
"${FLUTTER[@]}" pub get

# CocoaPods menyusun ulang Pods setelah `flutter clean`; `pod install` dijalankan
# otomatis oleh flutter saat build, jadi tidak dipanggil di sini.
mkdir -p "$SYMBOLS_DIR"

# TANPA --flavor: skema flavor hanya ada di Android (prod/staging di
# android/app/build.gradle.kts). Sisi iOS cuma punya skema `Runner`, jadi
# --flavor prod akan gagal "The Xcode project does not define custom schemes".
# Ini perbedaan nyata dari build_apk_prod.sh, bukan kelalaian.
if [[ "$SKIP_CODESIGN" == "1" ]]; then
  # Jalur pemeriksaan tanpa sertifikat: menghasilkan .app di
  # build/ios/iphoneos/Runner.app, bukan .ipa. Tidak bisa dipasang ke perangkat
  # tanpa ditandatangani ulang lewat Xcode.
  "${FLUTTER[@]}" build ios --release --no-codesign \
    "${DEFINES[@]}" \
    --obfuscate --split-debug-info="$SYMBOLS_DIR"
  ARTIFACT="build/ios/iphoneos/Runner.app  (belum ditandatangani)"
else
  EXPORT_ARGS=()
  if [[ -n "${EXPORT_OPTIONS_PLIST:-}" ]]; then
    [[ -f "$EXPORT_OPTIONS_PLIST" ]] || {
      echo "[build-ipa-prod] GAGAL: EXPORT_OPTIONS_PLIST tidak ditemukan: $EXPORT_OPTIONS_PLIST" >&2
      exit 1
    }
    EXPORT_ARGS+=("--export-options-plist=$EXPORT_OPTIONS_PLIST")
  else
    EXPORT_ARGS+=("--export-method" "$EXPORT_METHOD")
  fi

  "${FLUTTER[@]}" build ipa --release \
    "${DEFINES[@]}" \
    "${EXPORT_ARGS[@]}" \
    --obfuscate --split-debug-info="$SYMBOLS_DIR"
  ARTIFACT="build/ios/ipa/*.ipa"
fi

echo ""
echo "==========================================="
echo "  Build complete!"
echo "  Artefak : ${ARTIFACT}"
echo "  Symbols : ${SYMBOLS_DIR}  (simpan — tanpa ini stack trace crash tak terbaca)"
echo "==========================================="
