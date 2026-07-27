@echo off
REM Jalankan app di emulator Android terhadap MBIS-Backend lokal (dev).
REM Emulator Android memetakan host lewat 10.0.2.2. Untuk device fisik, jalankan
REM `adb reverse tcp:8080 tcp:8080` lalu ganti API_URL ke http://localhost:8080.
REM Override API_URL: set MBIS_API_URL sebelum memanggil script ini.
setlocal
if "%MBIS_API_URL%"=="" set MBIS_API_URL=http://10.0.2.2:8080
flutter run --flavor staging ^
  --dart-define=API_URL=%MBIS_API_URL% ^
  --dart-define=APP_ENV=dev
endlocal
