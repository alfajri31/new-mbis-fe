import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app.dart';
import 'auth/auth_session.dart';
import '../presentation/screens/splash_screen.dart';
import '../presentation/screens/login_screen.dart';
import '../presentation/screens/main_screen.dart';
import '../presentation/screens/agent_main_screen.dart';
import '../presentation/screens/customer_detail_screen.dart';
import '../presentation/screens/pipeline_detail_screen.dart';
import '../presentation/screens/pipeline_activity_screen.dart';
import '../presentation/screens/semua_jadwal_screen.dart';
import '../presentation/screens/rm_performance_screen.dart';
import '../presentation/screens/visit_map_screen.dart';
import '../presentation/screens/agent_detail_screen.dart';
import '../presentation/screens/tools_screen.dart';
import '../presentation/screens/product_knowledge_screen.dart';
import '../presentation/screens/gps_tracking_loader.dart';
import '../presentation/screens/kalkulator_premi_screen.dart';
import '../presentation/screens/kelola_premi_screen.dart';
import '../presentation/screens/assistant_screen.dart';
import '../presentation/screens/agent_management_screen.dart';
import '../presentation/screens/pindah_rm_screen.dart';
import '../presentation/screens/rm_transfer_screen.dart';
import '../presentation/screens/referral_management_screen.dart';
import '../presentation/screens/kelola_pengumuman_screen.dart';
import '../presentation/screens/kelola_master_data_screen.dart';
import '../presentation/screens/kelola_akun_screen.dart';
import '../presentation/screens/kelola_aktivitas_ai_screen.dart';
import '../presentation/screens/export_data_screen.dart';
import '../presentation/screens/export_my_visits_screen.dart';
import '../presentation/screens/export_screen.dart';
import '../presentation/screens/ganti_password_screen.dart';

/// The app's URL-addressable route table.
///
/// Every bottom-nav tab is a top-level route ([_tabRoute]); the detail screens
/// that open from a tab are declared as that tab's *sub-routes*. Because there
/// is no ShellRoute, a sub-route stacks on the same (root) navigator on top of
/// its tab page — so the tab (with its live IndexedStack) stays mounted beneath
/// a full-screen detail, the URL reflects the nesting (e.g. /customer/123 or
/// /customer/123/pipeline/45), a web refresh rebuilds the whole stack from that
/// URL, and the back button pops naturally (pipeline → customer → list).
///
/// All tab pages of one shell share a single page key (e.g. 'rm-shell') so
/// switching tab reuses the same page Element instead of tearing it down,
/// preserving each tab's state exactly as the old in-shell setState did.
///
/// Pipeline detail is reachable with a customer context (under customer detail,
/// back → customer) and without one (under the dashboard tab, back → dashboard),
/// so it is declared in both spots via [_pipelineSubRoutes]. Forms, pickers and
/// admin tools stay on imperative `Navigator.push` — restoring a half-filled
/// form on reload is pointless, so they just fall back to their parent location.
///
/// Reuses [MbisApp.navigatorKey] (so the 401 handler can still navigate) and
/// [MbisApp.routeObserver] (so RouteAware screens keep getting didPopNext).
///
/// [currentSession] is read live (not captured) so the redirect always sees the
/// latest auth state on a cold load / refresh. [refreshListenable] re-runs the
/// redirect whenever auth state changes (login / logout / 401 expiry), so a
/// session that drops while the user sits on a protected screen bounces them to
/// login without each call site having to navigate manually.
GoRouter buildRouter({
  required AuthSession? Function() currentSession,
  Listenable? refreshListenable,
}) =>
    GoRouter(
      navigatorKey: MbisApp.navigatorKey,
      observers: [MbisApp.routeObserver],
      initialLocation: '/',
      refreshListenable: refreshListenable,
      // Global auth gate. Runs on every navigation (and every refreshListenable
      // tick), so it covers the bare '/' landing, deep links, and web refreshes
      // of inner pages alike.
      redirect: (context, state) {
        final session = currentSession();
        final loc = state.matchedLocation;
        final goingToLogin = loc == '/login';

        // Not signed in: the only reachable screen is /login. Everything else —
        // a deep link, or a refresh on an inner page — is sent there, with the
        // intended destination remembered in ?from= so we can return after
        // login. This is what turns "hit an API while logged out -> 401
        // exception on a half-rendered screen" into a clean trip to the login
        // form: the screen never mounts and never fires its request.
        if (session == null) {
          if (goingToLogin) return null;
          final dest = state.uri.toString();
          if (dest.isEmpty || dest == '/') return '/login';
          return '/login?from=${Uri.encodeComponent(dest)}';
        }

        // Forced first-login password change. Accounts seeded/created with a shared
        // or temporary LOCAL password must set a private one before the app is
        // usable — trap them on the change screen until it's done. SSO logins have
        // no local password to rotate, so they're exempt (authMethod != LOCAL).
        const forcedChangePath = '/ganti-password-wajib';
        final mustChange = session.user.mustChangePassword && session.user.authMethod == 'LOCAL';
        if (mustChange && loc != forcedChangePath) {
          return forcedChangePath;
        }
        // Satisfied/exempt users shouldn't linger on (or deep-link to) the gate.
        if (!mustChange && loc == forcedChangePath) {
          return MbisApp.homeRouteForRoles(session.user.roles);
        }

        // Signed in: don't sit on the bare '/' or the login screen. Landing on
        // '/' (first load or a refresh of the bare URL) goes straight to the
        // role's home — the branded HTML splash in web/index.html already
        // covered the wasm download, so the Flutter SplashScreen would just be a
        // second, redundant hold.
        if (goingToLogin || loc == '/') {
          return MbisApp.homeRouteForRoles(session.user.roles);
        }
        return null;
      },
      routes: [
        // Fallback only — the redirect above always sends '/' elsewhere, so the
        // SplashScreen is never actually shown. Kept so initialLocation resolves.
        GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        // Mandatory first-login password change (see the redirect gate above).
        GoRoute(
            path: '/ganti-password-wajib',
            builder: (_, _) => const GantiPasswordScreen(forced: true)),

        // RM/BM/RO/KUP/ADMIN shell — one route per bottom-nav tab, with the
        // detail screens reachable from each tab nested under it.
        _tabRoute('/dashboard', 'rm-shell', 0, (i) => MainScreen(index: i),
            subRoutes: [
              ..._pipelineSubRoutes(),
              GoRoute(
                  path: 'jadwal', builder: (_, _) => const SemuaJadwalScreen()),
              GoRoute(
                path: 'rm-performance',
                builder: (_, s) => RmPerformanceScreen(
                  initialRegionId: s.uri.queryParameters['regionId'],
                  initialBranchId: s.uri.queryParameters['branchId'],
                  initialSearch: s.uri.queryParameters['search'],
                ),
              ),
              GoRoute(
                  path: 'visit-map', builder: (_, _) => const VisitMapScreen()),
            ]),
        _tabRoute('/customer', 'rm-shell', 1, (i) => MainScreen(index: i),
            subRoutes: [_customerDetailRoute()]),
        // BUMN — read-only view over BUMN customers + their pipelines.
        _tabRoute('/bumn', 'rm-shell', 2, (i) => MainScreen(index: i)),
        _tabRoute('/broker', 'rm-shell', 3, (i) => MainScreen(index: i)),
        // Tools hub + the field tools that open from it. Routed (not imperative
        // Navigator.push) so a web refresh while inside a tool restores it.
        _tabRoute('/tools', 'rm-shell', 4, (i) => MainScreen(index: i),
            subRoutes: _toolsSubRoutes()),
        // Profile + the management consoles that open from it (admin/supervisor
        // tools). Routed so they survive refresh; the role-gated cards still
        // decide who sees the entry points, and the backend gates the data.
        _tabRoute('/profil', 'rm-shell', 5, (i) => MainScreen(index: i),
            subRoutes: [
              ..._konsolSubRoutes(),
              GoRoute(
                  path: 'export-visit-saya',
                  builder: (_, _) => const ExportMyVisitsScreen()),
              GoRoute(
                  path: 'export',
                  builder: (_, _) => const ExportScreen()),
            ]),
        // "Kelola" hub as its own tab (index 6), for ADMIN and BM. The hub's cards
        // are role-filtered, so BM sees only what it is allowed.
        _tabRoute('/kelola', 'rm-shell', 6, (i) => MainScreen(index: i),
            subRoutes: [
              ..._konsolSubRoutes(),
              // Also reachable at /tools/kelola-premi; declared here so the hub's
              // card pops back to Kelola instead of the Tools tab.
              GoRoute(
                  path: 'kelola-premi',
                  builder: (_, _) => const KelolaPremiScreen()),
              // Tools nested under Kelola: BM's tab 4 is the RM performance list,
              // so /tools would render that instead of the hub. This copy gives BM
              // a real Tools entry whose back returns to Kelola.
              GoRoute(
                  path: 'tools',
                  builder: (_, _) => const ToolsScreen(basePath: '/kelola/tools'),
                  routes: _toolsSubRoutes()),
            ]),

        // Agent/TPM shell.
        _tabRoute('/agent', 'agent-shell', 0, (i) => AgentMainScreen(index: i),
            subRoutes: [..._pipelineSubRoutes()]),
        _tabRoute('/agent/customer', 'agent-shell', 1,
            (i) => AgentMainScreen(index: i),
            subRoutes: [_customerDetailRoute()]),
        _tabRoute(
            '/agent/komisi', 'agent-shell', 2, (i) => AgentMainScreen(index: i)),
        _tabRoute(
            '/agent/profil', 'agent-shell', 3, (i) => AgentMainScreen(index: i)),

        // Reached only from the (imperatively pushed) agent-management tool, so
        // it stays a top-level route.
        GoRoute(
          path: '/agent-detail/:agentId',
          builder: (_, s) =>
              AgentDetailScreen(agentId: s.pathParameters['agentId']!),
        ),
      ],
    );

/// A bottom-nav tab route for a role shell, optionally carrying the detail
/// [subRoutes] that open from it.
///
/// All tabs of one shell share [pageKey] so the Navigator reuses the same page
/// (and the shell's IndexedStack of live tabs) across tab switches; only [index]
/// changes. NoTransitionPage keeps the tab switch instant. Sub-routes use the
/// default page builder (normal slide transition) and stack on top full-screen.
GoRoute _tabRoute(
  String path,
  String pageKey,
  int index,
  Widget Function(int index) build, {
  List<RouteBase> subRoutes = const [],
}) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) => NoTransitionPage(
        key: ValueKey(pageKey),
        child: build(index),
      ),
      routes: subRoutes,
    );

/// The field tools, as a reusable sub-route list. Nested under the /tools tab
/// (for RM, whose tab 4 IS Tools) and under /kelola/tools (for BM/ADMIN, whose
/// tab 4 is the RM performance list), so back returns to the hub the user opened
/// the tool from. `visit-map` is the supervisory, office-scoped map — the same
/// screen the dashboard's "Peta Visit" button opens.
List<RouteBase> _toolsSubRoutes() => [
      GoRoute(
          path: 'product-knowledge',
          builder: (_, _) => const ProductKnowledgeScreen()),
      GoRoute(path: 'gps', builder: (_, _) => const GpsTrackingLoader()),
      GoRoute(path: 'visit-map', builder: (_, _) => const VisitMapScreen()),
      GoRoute(
          path: 'kalkulator-premi',
          builder: (_, _) => const KalkulatorPremiScreen()),
      GoRoute(
          path: 'kelola-premi', builder: (_, _) => const KelolaPremiScreen()),
      GoRoute(path: 'assistant', builder: (_, _) => const AssistantScreen()),
    ];

/// The management consoles, as a reusable sub-route list. Nested both under
/// /profil (opened from the Profile screen → back returns to Profil) and under
/// /kelola (opened from the admin hub → back returns to Kelola). A console
/// declared under only one parent would drop the user into that parent's tab no
/// matter where they actually came from.
List<RouteBase> _konsolSubRoutes() => [
      GoRoute(
          path: 'manajemen-agen',
          builder: (_, _) => const AgentManagementScreen()),
      GoRoute(path: 'pindah-rm', builder: (_, _) => const PindahRmScreen()),
      GoRoute(
          path: 'pemindahan-cabang', builder: (_, _) => const RmTransferScreen()),
      GoRoute(
          path: 'referral',
          builder: (_, _) => const ReferralManagementScreen()),
      GoRoute(
          path: 'pengumuman',
          builder: (_, _) => const KelolaPengumumanScreen()),
      GoRoute(
          path: 'master-data',
          builder: (_, _) => const KelolaMasterDataScreen()),
      GoRoute(path: 'akun', builder: (_, _) => const KelolaAkunScreen()),
      GoRoute(
          path: 'aktivitas-ai',
          builder: (_, _) => const KelolaAktivitasAiScreen()),
      GoRoute(path: 'export-data', builder: (_, _) => const ExportDataScreen()),
    ];

/// Customer detail (and the pipeline detail reachable from within it). Reused
/// under both the RM and Agent customer tabs.
GoRoute _customerDetailRoute() => GoRoute(
      path: ':customerId',
      builder: (_, s) =>
          CustomerDetailScreen(customerId: s.pathParameters['customerId']!),
      routes: _pipelineSubRoutes(),
    );

/// Pipeline detail + its activity tab, as a reusable sub-route list. Nested both
/// under customer detail (back → customer) and under the dashboard/agent tab
/// (back → that tab), so a pipeline opened from either place has a real URL.
List<RouteBase> _pipelineSubRoutes() => [
      GoRoute(
        path: 'pipeline/:pipelineId',
        builder: (_, s) =>
            PipelineDetailScreen(pipelineId: s.pathParameters['pipelineId']!),
        routes: [
          GoRoute(
            path: 'activity',
            builder: (_, s) => PipelineActivityScreen(
              pipelineId: s.pathParameters['pipelineId']!,
              initialTab:
                  int.tryParse(s.uri.queryParameters['tab'] ?? '') ?? 0,
            ),
          ),
        ],
      ),
    ];
