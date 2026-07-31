@echo off
REM ============================================================================
REM Build AAB rilis untuk Google Play (flavor prod).
REM
REM   scripts\build-aab.bat https://mbis.askrindo.co.id/v2
REM
REM Nilai wajib lain dibaca dari environment variable supaya tidak ikut ter-commit:
REM   PRIVACY_POLICY_URL     - halaman kebijakan privasi (wajib Play)
REM   ACCOUNT_DELETION_URL   - halaman permintaan hapus akun (wajib Play)
REM   PRIVACY_CONTACT_EMAIL  - opsional, email unit yang memproses permintaan
REM
REM Script ini SENGAJA menolak build kalau ada yang kosong: kelalaian konfigurasi
REM jauh lebih murah ketahuan di sini daripada setelah AAB ditolak review.
REM ============================================================================
setlocal
set API_URL=%1

if "%API_URL%"=="" (
  echo [build-aab] GAGAL: API_URL wajib diisi sebagai argumen pertama.
  echo             Contoh: scripts\build-aab.bat https://mbis.askrindo.co.id/v2
  exit /b 1
)

echo %API_URL% | findstr /I /C:"http://" >nul
if not errorlevel 1 (
  echo [build-aab] GAGAL: API_URL memakai HTTP polos. Build prod menolak cleartext.
  exit /b 1
)

if "%PRIVACY_POLICY_URL%"=="" (
  echo [build-aab] GAGAL: PRIVACY_POLICY_URL belum di-set.
  echo             Google Play mewajibkan tautan kebijakan privasi dapat dibuka
  echo             dari dalam aplikasi. Lihat docs\RILIS-ANDROID.md section 2.
  exit /b 1
)

if "%ACCOUNT_DELETION_URL%"=="" (
  echo [build-aab] GAGAL: ACCOUNT_DELETION_URL belum di-set.
  echo             Google Play mewajibkan halaman permintaan hapus akun yang bisa
  echo             diakses tanpa memasang aplikasi. Lihat docs\RILIS-ANDROID.md section 2.
  exit /b 1
)

findstr /B /C:"const bool kebijakanMasihDraf = true;" "%~dp0..\lib\src\legal\kebijakan_privasi_content.dart" >nul
if not errorlevel 1 (
  echo [build-aab] GAGAL: kebijakan privasi masih berstatus DRAF.
  echo             Naskahnya terbundel di aplikasi dan tayang di /kebijakan-privasi,
  echo             jadi build ini akan menerbitkan naskah yang belum disahkan Legal.
  echo             Setelah disahkan: setel kebijakanMasihDraf = false dan isi
  echo             tanggalBerlaku di lib\src\legal\kebijakan_privasi_content.dart.
  exit /b 1
)

if not exist "%~dp0..\android\key.properties" (
  echo [build-aab] GAGAL: android\key.properties tidak ada.
  echo             Tanpa itu AAB ditandatangani debug key dan ditolak Play Console.
  echo             Lihat docs\RILIS-ANDROID.md section 1.
  exit /b 1
)

flutter build appbundle --release --flavor prod ^
  --dart-define=API_URL=%API_URL% ^
  --dart-define=APP_ENV=prod ^
  --dart-define=PRIVACY_POLICY_URL=%PRIVACY_POLICY_URL% ^
  --dart-define=ACCOUNT_DELETION_URL=%ACCOUNT_DELETION_URL% ^
  --dart-define=PRIVACY_CONTACT_EMAIL=%PRIVACY_CONTACT_EMAIL%

if errorlevel 1 exit /b 1

echo.
echo [build-aab] Selesai. Langkah berikutnya (docs\RILIS-ANDROID.md section 4):
echo             1. Simpan mapping.txt: build\app\outputs\mapping\prodRelease\mapping.txt
echo             2. Verifikasi 16 KB page size pada berkas .so di dalam AAB
echo             3. Pasang AAB ke device asli lewat bundletool, jangan upload sebelum diuji
endlocal
