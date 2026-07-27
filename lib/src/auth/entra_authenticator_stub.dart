/// Native (Android/iOS/desktop) placeholder for the Entra browser step. Capturing
/// the OAuth redirect on native needs a deep-link handler (custom scheme), which
/// isn't wired yet — so SSO is web-only for now and this throws if ever reached.
/// The login button is hidden on non-web platforms (see EntraAuthService), so this
/// is a belt-and-suspenders guard rather than a code path users can hit.
Future<String?> openEntraAuthWindow(String authUrl, String redirectUri) {
  throw UnsupportedError('SSO Microsoft saat ini hanya tersedia di web.');
}
