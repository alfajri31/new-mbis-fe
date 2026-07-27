// Cross-platform "open these bytes" entry point.
//
// On web it opens the file in a new browser tab (so PDFs/images preview using
// the browser's native viewer). On other platforms it returns false so the
// caller can fall back to an in-app preview or a message.
//
// Guard on dart.library.js_interop (NOT dart.library.html): the app is built
// with `flutter build web --wasm`, and under WasmGC `dart:html` is unavailable
// so `dart.library.html` is false — which would wrongly select the native stub
// and call path_provider on web (MissingPluginException). js_interop is true on
// both dart2js and dart2wasm, so web always gets the web implementation.
export 'file_opener_stub.dart' if (dart.library.js_interop) 'file_opener_web.dart';
