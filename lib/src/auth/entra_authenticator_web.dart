import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Opens Microsoft sign-in in a popup and resolves with the full callback URL that
/// `web/auth.html` posts back (`…/auth.html?code=…&state=…`), or `null` if the user
/// closes the popup first.
///
/// WASM-safe: uses only package:web (no `dart:html`), so it compiles under
/// `flutter build web --wasm`. [redirectUri] is unused here (Microsoft already has
/// it from the authorize URL); it's kept for signature parity with the native stub.
Future<String?> openEntraAuthWindow(String authUrl, String redirectUri) {
  final completer = Completer<String?>();
  final origin = web.window.location.origin;

  final popup = web.window.open(authUrl, 'mbis_entra_sso', 'width=520,height=640');

  Timer? poll;
  JSFunction? listener;

  void finish(String? value) {
    if (completer.isCompleted) return;
    poll?.cancel();
    if (listener != null) {
      web.window.removeEventListener('message', listener);
    }
    completer.complete(value);
  }

  void onMessage(web.Event event) {
    final message = event as web.MessageEvent;
    // Only trust messages from our own origin (auth.html), not the Microsoft popup.
    if (message.origin != origin) return;
    final data = message.data;
    if (data == null) return;
    final decoded = data.dartify();
    if (decoded is Map && decoded['mbis-sso'] is String) {
      final url = decoded['mbis-sso'] as String;
      try {
        popup?.close();
      } catch (_) {}
      finish(url);
    }
  }

  listener = onMessage.toJS;
  web.window.addEventListener('message', listener);

  // The postMessage may never arrive if the user just closes the popup — poll for it.
  poll = Timer.periodic(const Duration(milliseconds: 500), (_) {
    if (popup == null || popup.closed) {
      finish(null);
    }
  });

  return completer.future;
}
