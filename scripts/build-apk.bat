@echo off
REM Build APK rilis. Argumen: %1 = flavor (staging^|prod), %2 = API_URL backend.
REM Contoh: scripts\build-apk.bat staging https://mbis-staging.askrindo.co.id
REM         scripts\build-apk.bat prod    https://mbis.askrindo.co.id/v2
setlocal
set FLAVOR=%1
set API_URL=%2
if "%FLAVOR%"=="" set FLAVOR=staging
if "%API_URL%"=="" (
  echo [build-apk] API_URL wajib diisi untuk build rilis & exit /b 1
)
if /I "%FLAVOR%"=="prod" ( set APP_ENV=prod ) else ( set APP_ENV=staging )

REM Host yang trust store-nya dipersempit ke assets\ssl (lib\src\network\ssl_pinning.dart).
REM BUKAN pengerasan opsional: mbis.askrindo.co.id mengirim sertifikat leaf SAJA,
REM intermediate Sectigo R36/R46 tidak ikut. Browser dan curl menjemput issuer lewat
REM AIA, Dart tidak — jadi build tanpa rantai bundled gagal handshake saat login.
REM Auto-isi dibatasi ke domain askrindo.co.id supaya host staging tidak ikut dikunci.
REM Untuk mematikan: set SSL_PINNED_HOSTS=off sebelum menjalankan script ini.
REM Blok ini SENGAJA di luar `if (...)` berkurung: variabel yang di-set di dalam
REM kurung baru terbaca setelah bloknya selesai (cmd mengembangkan %VAR% saat baris
REM di-parse, bukan saat dijalankan), sehingga versi berkurung akan mengirim
REM SSL_PINNED_HOSTS kosong tanpa pesan galat apa pun.
if defined SSL_PINNED_HOSTS goto :pin_siap
echo %API_URL% | findstr /I /C:"askrindo.co.id" >nul || goto :pin_siap
for /f "tokens=2 delims=/" %%h in ("%API_URL%") do set SSL_PINNED_HOSTS=%%h
:pin_siap
if /I "%SSL_PINNED_HOSTS%"=="off" set SSL_PINNED_HOSTS=
REM APK = jalur uji internal, jadi URL kebijakan/hapus akun opsional di sini.
REM Untuk rilis ke Play pakai scripts\build-aab.bat yang mewajibkan semuanya terisi.
flutter build apk --release --flavor %FLAVOR% ^
  --dart-define=API_URL=%API_URL% ^
  --dart-define=APP_ENV=%APP_ENV% ^
  --dart-define=SSL_PINNED_HOSTS=%SSL_PINNED_HOSTS% ^
  --dart-define=PRIVACY_POLICY_URL=%PRIVACY_POLICY_URL% ^
  --dart-define=ACCOUNT_DELETION_URL=%ACCOUNT_DELETION_URL% ^
  --dart-define=PRIVACY_CONTACT_EMAIL=%PRIVACY_CONTACT_EMAIL%
endlocal
