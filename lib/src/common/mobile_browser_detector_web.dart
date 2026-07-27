import 'package:web/web.dart' as web;

/// True when the browser's User-Agent string looks like a phone (Android or
/// iPhone/iPod — iPad deliberately excluded, it behaves like a small desktop).
/// See mobile_browser_detector.dart for why this is a soft nudge, not security.
bool isMobileBrowserUserAgent() {
  final ua = web.window.navigator.userAgent.toLowerCase();
  return ua.contains('android') || ua.contains('iphone') || ua.contains('ipod');
}
