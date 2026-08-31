// Apakah halaman berjalan di *secure context* browser.
//
// Penting karena `flutter_secure_storage` v10 di web memakai `crypto.subtle`, dan
// browser hanya menyediakannya pada origin tepercaya (HTTPS, atau `localhost`).
// Di luar itu paketnya melempar:
//
//     Unsupported operation: FlutterSecureStorageWeb only works in secure contexts.
//
// Server dev kantor diakses lewat `http://<ip>:<port>` tanpa TLS, jadi kondisi ini
// nyata di sana — lihat `createSessionStore` di `session_store.dart`.
//
// Guard-nya `dart.library.js_interop` (BUKAN `dart.library.html`): build web memakai
// `flutter build web --wasm`, dan `dart:html` tidak tersedia di WasmGC. Pola yang
// sama dipakai `common/mobile_browser_detector.dart`.
export 'secure_context_stub.dart'
    if (dart.library.js_interop) 'secure_context_web.dart';
