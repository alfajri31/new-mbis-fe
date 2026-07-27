// Web file opener. Selected by file_opener.dart's conditional export when
// dart.library.js_interop is available (dart2js AND dart2wasm). Uses
// package:web + dart:js_interop instead of dart:html so it compiles under
// `flutter build web --wasm` (dart:html is unavailable in WasmGC builds).
// Signatures mirror file_opener_stub.dart so callers behave the same everywhere.
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Synchronously opens a blank browser tab and returns a handle to it.
///
/// MUST be called directly inside the user-gesture handler (e.g. onTap), BEFORE
/// any `await`. Safari/iOS only allows window.open() during a real user gesture;
/// opening a tab AFTER an awaited fetch is treated as a programmatic pop-up and
/// silently blocked (Chrome desktop is lenient and allows it, which is why it
/// worked there but not on iPhone). We open the empty tab now and redirect it to
/// the blob URL once the bytes arrive.
Object? openPendingTab() => web.window.open('', '_blank');

/// Renders [bytes] using the browser's native viewer (PDF/image) in a new tab.
///
/// If [pending] (from [openPendingTab]) is supplied, that already-open tab is
/// redirected to the blob URL — this is what makes it work on Safari/iOS. Without
/// it, falls back to a fresh window.open (fine on lenient browsers like Chrome).
/// [fileName] is unused on web (the browser viewer titles the tab) but kept for
/// signature parity with the native implementation.
Future<bool> openBytes(List<int> bytes, String mimeType, String fileName, {Object? pending}) async {
  final data = Uint8List.fromList(bytes).toJS;
  final blob = web.Blob(<JSAny>[data].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  // `pending` is null or a Window from openPendingTab(); avoid `is` on JS interop
  // types (unreliable under WASM) and cast the known non-null case instead.
  if (pending != null) {
    (pending as web.Window).location.href = url;
  } else {
    web.window.open(url, '_blank');
  }
  // Revoke shortly after so the new tab has time to load it.
  Future.delayed(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  return true;
}

/// Closes a tab opened with [openPendingTab] — e.g. when the fetch failed, so the
/// user isn't left staring at a blank tab.
void closePendingTab(Object? pending) {
  if (pending != null) (pending as web.Window).close();
}

/// Forces a save-as download of [bytes] as [fileName] via an anchor with the
/// `download` attribute — unlike [openBytes], the browser saves the file instead
/// of trying to render it (needed for CSV, which would show as raw text in-tab).
/// No pending-tab dance required: anchor clicks aren't pop-ups, so Safari allows
/// them after an await.
Future<bool> downloadBytes(List<int> bytes, String mimeType, String fileName) async {
  final data = Uint8List.fromList(bytes).toJS;
  final blob = web.Blob(<JSAny>[data].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName;
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  Future.delayed(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
  return true;
}
