// Soft check for "is this web page being viewed from a phone browser".
//
// NOT a security boundary: User-Agent is trivially spoofable (Chrome DevTools'
// device toolbar, browser extensions, curl -A, ...) with no server-side way to
// verify it. It only deters casual desktop use of the visit check-in flow while
// the native app isn't ready on every platform (see pipeline_detail_screen.dart);
// it does NOT restore the anti-fraud guarantee `Geolocator.isMocked` gives on
// native (add_activity_screen.dart) — that check has no browser equivalent.
//
// Guard on dart.library.js_interop (NOT dart.library.html): builds run
// `flutter build web --wasm`, and dart:html is unavailable under WasmGC.
export 'mobile_browser_detector_stub.dart'
    if (dart.library.js_interop) 'mobile_browser_detector_web.dart';
