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
REM APK = jalur uji internal, jadi URL kebijakan/hapus akun opsional di sini.
REM Untuk rilis ke Play pakai scripts\build-aab.bat yang mewajibkan semuanya terisi.
flutter build apk --release --flavor %FLAVOR% ^
  --dart-define=API_URL=%API_URL% ^
  --dart-define=APP_ENV=%APP_ENV% ^
  --dart-define=PRIVACY_POLICY_URL=%PRIVACY_POLICY_URL% ^
  --dart-define=ACCOUNT_DELETION_URL=%ACCOUNT_DELETION_URL% ^
  --dart-define=PRIVACY_CONTACT_EMAIL=%PRIVACY_CONTACT_EMAIL%
endlocal
