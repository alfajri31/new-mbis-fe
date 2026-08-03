#!/usr/bin/env bash
# Menentukan biner Flutter yang dipakai script build — hasilnya di array $FLUTTER.
#
# Di-`source`, bukan dijalankan. Pemakaian:
#   source "$(dirname "${BASH_SOURCE[0]}")/_flutter.sh"
#   "${FLUTTER[@]}" build apk ...
#
# Kenapa ada: `flutter` di PATH belum tentu versi yang di-pin repo. Mesin dev di
# sini memakai FVM dengan default global 3.38.9 (Dart 3.10.8), sedangkan .fvmrc
# meminta 3.44.3 — memanggil `flutter` langsung berhenti di
# "Because mbis requires SDK version ^3.12.0, version solving failed", setelah
# `flutter clean` terlanjur menghapus hasil build sebelumnya.
#
# Urutan: symlink .fvm/flutter_sdk (paling pasti, sudah menunjuk versi ter-pin) →
# `fvm flutter` (bila .fvmrc ada tapi SDK-nya belum ter-install) → `flutter` PATH.

_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -n "${FLUTTER_BIN:-}" ]]; then
  # Jalan keluar eksplisit: mesin CI dengan SDK di lokasi tetap, dan uji kering
  # script build (FLUTTER_BIN menunjuk stub yang hanya mencetak argumennya).
  FLUTTER=("$FLUTTER_BIN")
elif [[ -x "$_repo_root/.fvm/flutter_sdk/bin/flutter" ]]; then
  FLUTTER=("$_repo_root/.fvm/flutter_sdk/bin/flutter")
elif [[ -f "$_repo_root/.fvmrc" ]] && command -v fvm >/dev/null 2>&1; then
  # SDK ter-pin belum di-install; `fvm flutter` mengunduhnya lebih dulu.
  FLUTTER=(fvm flutter)
else
  FLUTTER=(flutter)
fi

# Peringatan bila versi yang terpakai beda dari .fvmrc. Tidak menghentikan build:
# perbedaan patch sering tidak berpengaruh, dan menolak build karena itu lebih
# mengganggu daripada memberi tahu. Kegagalan sungguhan tetap muncul di pub get.
if [[ -f "$_repo_root/.fvmrc" ]]; then
  _pinned="$(sed -nE 's/.*"flutter"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$_repo_root/.fvmrc")"
  _aktif="$("${FLUTTER[@]}" --version 2>/dev/null | sed -nE 's/^Flutter ([0-9.]+).*/\1/p' | head -1)"
  if [[ -n "$_pinned" && -n "$_aktif" && "$_pinned" != "$_aktif" ]]; then
    echo "[flutter] PERINGATAN: memakai Flutter $_aktif, .fvmrc meminta $_pinned." >&2
    echo "          Jalankan: fvm install $_pinned && fvm use $_pinned" >&2
  fi
fi

unset _repo_root _pinned _aktif
