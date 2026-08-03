#!/usr/bin/env bash
# =============================================================================
# Build AAB rilis untuk Google Play (flavor prod).
#
#   scripts/build-aab.sh https://mbis.askrindo.co.id/v2
#
# Nilai wajib lain dibaca dari environment variable supaya tidak ikut ter-commit:
#   PRIVACY_POLICY_URL     - halaman kebijakan privasi (wajib Play)
#   ACCOUNT_DELETION_URL   - halaman permintaan hapus akun (wajib Play)
#   PRIVACY_CONTACT_EMAIL  - opsional, email unit yang memproses permintaan
#
# Script ini SENGAJA menolak build kalau ada yang kosong: kelalaian konfigurasi
# jauh lebih murah ketahuan di sini daripada setelah AAB ditolak review.
# =============================================================================
set -euo pipefail

# Flutter yang di-pin .fvmrc, bukan yang kebetulan ada di PATH. Lihat _flutter.sh.
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_flutter.sh"

API_URL="${1:-}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { echo "[build-aab] GAGAL: $1" >&2; exit 1; }

[[ -n "$API_URL" ]] || fail "API_URL wajib diisi sebagai argumen pertama.
            Contoh: scripts/build-aab.sh https://mbis.askrindo.co.id/v2"

[[ "$API_URL" != http://* ]] || fail "API_URL memakai HTTP polos. Build prod menolak cleartext."

[[ -n "${PRIVACY_POLICY_URL:-}" ]] || fail "PRIVACY_POLICY_URL belum di-set.
            Google Play mewajibkan tautan kebijakan privasi dapat dibuka dari
            dalam aplikasi. Lihat docs/RILIS-ANDROID.md §2."

[[ -n "${ACCOUNT_DELETION_URL:-}" ]] || fail "ACCOUNT_DELETION_URL belum di-set.
            Google Play mewajibkan halaman permintaan hapus akun yang bisa
            diakses tanpa memasang aplikasi. Lihat docs/RILIS-ANDROID.md §2."

POLICY_SRC="$REPO_ROOT/lib/src/legal/kebijakan_privasi_content.dart"
! grep -q '^const bool kebijakanMasihDraf = true;' "$POLICY_SRC" || fail \
"Kebijakan privasi masih berstatus DRAF.
            Naskahnya terbundel di aplikasi dan tayang di /kebijakan-privasi,
            jadi build ini akan menerbitkan naskah yang belum disahkan Legal —
            lengkap dengan spanduk 'DRAF' yang akan dilihat reviewer.
            Setelah Legal mengesahkan: setel kebijakanMasihDraf = false dan isi
            tanggalBerlaku di
              lib/src/legal/kebijakan_privasi_content.dart"

[[ -f "$REPO_ROOT/android/key.properties" ]] || fail "android/key.properties tidak ada.
            Tanpa itu AAB ditandatangani debug key dan ditolak Play Console.
            Lihat docs/RILIS-ANDROID.md §1."

# Host yang trust store-nya dipersempit ke assets/ssl (lib/src/network/ssl_pinning.dart).
#
# Wajib untuk rilis Play, bukan pilihan: `mbis.askrindo.co.id` mengirim sertifikat
# leaf SAJA — intermediate Sectigo R36 dan R46 tidak ikut. Browser dan `curl`
# menutupi itu dengan menjemput issuer lewat AIA; Dart/BoringSSL tidak. AAB tanpa
# rantai bundled akan gagal `CERTIFICATE_VERIFY_FAILED: unable to get local issuer
# certificate` di HP pengguna sejak layar login, walau server terlihat sehat dari
# laptop. Berkas di assets/ssl memasok rantai yang hilang itu.
#
# Set SSL_PINNED_HOSTS="" secara eksplisit hanya bila server sudah dipastikan
# mengirim fullchain dan pinning memang ingin dilepas.
API_HOST="$(sed -E 's#^[a-z]+://##; s#[/:?].*$##' <<<"$API_URL")"
case "$API_HOST" in
  *askrindo.co.id) SSL_PINNED_HOSTS="${SSL_PINNED_HOSTS-$API_HOST}" ;;
  *)               SSL_PINNED_HOSTS="${SSL_PINNED_HOSTS-}" ;;
esac

# Preflight: buktikan rantai bundled memvalidasi sertifikat host tujuan sebelum
# AAB dibuat. Berbeda dari gerbang lain di script ini, kegagalannya TIDAK
# menghentikan build — mesin rilis belum tentu punya rute ke host produksi, dan
# menolak rilis karena jaringan build lebih merugikan daripada peringatan ini.
if [[ -n "$SSL_PINNED_HOSTS" ]] && command -v openssl >/dev/null 2>&1; then
  CERT_ASSET="$REPO_ROOT/assets/ssl/askrindo-fullchain-2026-2027.crt"
  if PROBE="$(openssl s_client -servername "$API_HOST" -connect "$API_HOST:443" \
       -CAfile "$CERT_ASSET" -verify_return_error </dev/null 2>&1)"; then
    echo "[build-aab] pinning: rantai bundled cocok untuk $API_HOST"
  elif grep -q "verify error" <<<"$PROBE"; then
    echo "[build-aab] PERINGATAN: sertifikat $API_HOST TIDAK divalidasi oleh" >&2
    echo "            assets/ssl/askrindo-fullchain-2026-2027.crt. AAB ini akan" >&2
    echo "            gagal handshake saat login di HP pengguna. Perbarui berkas" >&2
    echo "            rantai sebelum mengunggah ke Play Console." >&2
  else
    echo "[build-aab] pinning: $API_HOST tak terjangkau dari mesin ini, preflight dilewati" >&2
  fi
fi

"${FLUTTER[@]}" build appbundle --release --flavor prod \
  --dart-define=API_URL="$API_URL" \
  --dart-define=APP_ENV=prod \
  --dart-define=SSL_PINNED_HOSTS="$SSL_PINNED_HOSTS" \
  --dart-define=PRIVACY_POLICY_URL="$PRIVACY_POLICY_URL" \
  --dart-define=ACCOUNT_DELETION_URL="$ACCOUNT_DELETION_URL" \
  --dart-define=PRIVACY_CONTACT_EMAIL="${PRIVACY_CONTACT_EMAIL:-}"

cat <<'EOF'

[build-aab] Selesai. Langkah berikutnya (docs/RILIS-ANDROID.md §4):
            1. Simpan mapping.txt: build/app/outputs/mapping/prodRelease/mapping.txt
            2. Verifikasi 16 KB page size pada berkas .so di dalam AAB
            3. Pasang AAB ke device asli lewat bundletool, jangan upload sebelum diuji
EOF
