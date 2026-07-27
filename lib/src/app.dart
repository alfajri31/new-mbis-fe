import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import '../core/providers/app_providers.dart';

import 'auth/auth_repository.dart';
import 'auth/auth_session.dart';
import 'network/api_client.dart';
import 'notification/push_service.dart';
import 'router.dart';

class MbisApp extends ConsumerStatefulWidget {
  const MbisApp({
    super.key,
    required this.authRepository,
    required this.initialSession,
  });

  final AuthRepository authRepository;
  final AuthSession? initialSession;

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Lets screens (e.g. the dashboard) refresh when a pushed full-screen route is
  /// popped back to them — subscribe as a [RouteAware] and refetch in didPopNext().
  /// Typed to [PageRoute] (not [ModalRoute]) so that closing a modal bottom sheet
  /// (announcement detail, drill-down) does NOT count as "returning" and trigger a
  /// reload — only full-screen page pops do.
  static final RouteObserver<PageRoute<dynamic>> routeObserver =
      RouteObserver<PageRoute<dynamic>>();

  static MbisAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<MbisAppState>();

  /// Landing route after login/splash, by role. Agents get their own portal;
  /// everyone else (RM, supervisors KUP/BM/RO, and ADMIN) gets the adaptive
  /// dashboard, which then renders the right scope from the backend.
  static String homeRouteForRoles(List<String>? roles) {
    if (roles != null && roles.contains('AGENT')) return '/agent';
    return '/dashboard';
  }

  /// Oversight roles (ADMIN/RO/BM/KUP). They oversee RMs rather than doing field
  /// work themselves, so their UI drops the personal jadwal/akses-cepat, swaps the
  /// Tools tab for the RM management list, and hides "Ajukan Agen". Mirrors the
  /// backend scope (ADMIN = national, RO/BM/KUP = office subtree); ADMIN is
  /// included so it also gets the RM management tab, not just the dashboard view.
  static const Set<String> supervisorRoles = {'ADMIN', 'KUP', 'BM', 'RO'};

  static bool isSupervisorRole(List<String>? roles) =>
      roles != null && roles.any(supervisorRoles.contains);

  @override
  ConsumerState<MbisApp> createState() => MbisAppState();
}

class MbisAppState extends ConsumerState<MbisApp> {
  AuthSession? _session;
  late final GoRouter _router;

  /// Bumped on every auth-state change so the router's redirect re-runs and the
  /// global auth gate kicks in (e.g. a 401 while idle pushes to /login).
  final ValueNotifier<int> _authRevision = ValueNotifier<int>(0);

  /// In-flight token refresh shared by all concurrent requests. Refresh tokens
  /// ROTATE (the used one is revoked server-side), so two parallel refreshes
  /// with the same token would race and the loser would kill the session —
  /// hence single-flight.
  Future<AuthSession?>? _refreshInFlight;

  /// Refresh this long before the access token actually expires, so a request
  /// never leaves with a token that dies in transit (clock skew, slow link).
  static const Duration _refreshLeeway = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    _session = widget.initialSession;
    // Pass a live getter (not _session's current value) so the redirect always
    // reads the latest auth state on a cold load / refresh.
    _router = buildRouter(
      currentSession: () => _session,
      refreshListenable: _authRevision,
    );
    // Any API call that gets a 401 (e.g. token issued before a DB reset, or an
    // expired session) bounces the user back to the login screen.
    ApiClient.onUnauthorized = handleSessionExpired;
    // Token sesi aktif TANPA refresh — dipakai ApiClient untuk mengabaikan 401
    // dari request sesi lama yang masih menggantung (lihat _isStaleSession).
    ApiClient.currentAccessToken = () => _session?.accessToken;
    // Every request asks for the current token here first; when it is close to
    // expiry the session is silently extended via the refresh token, so the
    // effective session is 7 sliding days, not one 30-minute access token.
    ApiClient.tokenProvider = _freshAccessToken;

    // Set up push notifications and, if already signed in (session restored on a
    // cold start), register this device's FCM token. No-op when Firebase isn't
    // configured or on web.
    PushService.instance.init(() => _session).then((_) {
      if (_session != null) {
        PushService.instance.registerForCurrentSession();
      }
    });
  }

  @override
  void dispose() {
    _authRevision.dispose();
    super.dispose();
  }

  /// Records a new auth state and notifies the router so its redirect re-runs.
  /// Juga di-mirror ke [sessionProvider] agar lapisan Riverpod (apiClientProvider
  /// + repository modul yang sudah dimigrasi) ikut memakai sesi terbaru.
  void _setSession(AuthSession? session) {
    setState(() => _session = session);
    _authRevision.value++;
    ref.read(sessionProvider.notifier).set(session);
  }

  AuthSession? get session => _session;
  AuthRepository get authRepository => widget.authRepository;

  /// Returns the access token requests should carry right now, refreshing the
  /// session first when it is about to expire. Falls back to the current token
  /// on any refresh failure — the global 401 handler then decides the outcome
  /// (a network blip recovers silently; a revoked session lands on /login).
  Future<String?> _freshAccessToken() async {
    final s = _session;
    if (s == null) return null;
    final exp = s.accessTokenExpiresAt;
    if (exp == null || DateTime.now().isBefore(exp.subtract(_refreshLeeway))) {
      return s.accessToken;
    }
    final refreshed = await _refreshSession();
    return (refreshed ?? s).accessToken;
  }

  /// Rotates the refresh token into a fresh session (single-flight). Returns
  /// null when refreshing is impossible (no/expired refresh token) or rejected.
  Future<AuthSession?> _refreshSession() {
    final s = _session;
    final refreshToken = s?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) return Future.value(null);
    final refreshExp = s!.refreshTokenExpiresAt;
    if (refreshExp != null && DateTime.now().isAfter(refreshExp)) {
      return Future.value(null);
    }
    return _refreshInFlight ??= widget.authRepository
        .refresh(refreshToken) // persists the new session itself
        .then<AuthSession?>((fresh) {
          if (mounted) _setSession(fresh);
          return fresh;
        })
        .catchError((_) => null)
        .whenComplete(() => _refreshInFlight = null);
  }

  /// Clears the stored session and returns to the login screen. Triggered
  /// automatically on a 401 response, without calling the backend logout.
  /// Always clears + navigates (no early return on a null session) so a 401
  /// from a stale token still lands the user on the login form rather than a
  /// half-rendered screen showing an exception.
  Future<void> handleSessionExpired() async {
    await widget.authRepository.clearSession();
    if (!mounted) return;
    if (_session != null) {
      _setSession(null);
    }
    _router.go('/login');
  }

  Future<void> handleLogin(AuthSession session) async {
    _setSession(session);
    // Register this device for push now that we have a valid session.
    PushService.instance.registerForCurrentSession();
  }

  Future<void> handleLogout() async {
    final session = _session;
    // Unregister the device while the session is still valid (the endpoint needs auth).
    if (session != null) {
      await PushService.instance.unregisterForSession(session);
    }
    final refreshToken = session?.refreshToken;
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await widget.authRepository.logout(refreshToken);
      } catch (_) {}
    }
    await widget.authRepository.clearSession();
    _setSession(null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      title: 'M-BIS Askrindo',
      theme: AppTheme.lightTheme,
      // Web/desktop: let the mouse drag-scroll lists (not just the wheel) and
      // keep Material's scrollbars. Touch is unaffected on mobile.
      scrollBehavior: const _AppScrollBehavior(),
    );
  }
}

/// Allows mouse + trackpad drag-to-scroll on web/desktop on top of the default
/// touch dragging, so manager users can drag long performance lists.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
