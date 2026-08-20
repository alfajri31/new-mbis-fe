import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'app.dart';
import 'auth/auth_session.dart';
import 'auth/roles.dart';
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
import '../presentation/screens/import_pipeline_screen.dart';
import '../presentation/screens/import_realisasi_screen.dart';
import '../presentation/screens/import_target_screen.dart';
import '../presentation/screens/privasi_akun_screen.dart';
import '../presentation/screens/kebijakan_privasi_screen.dart';
import '../presentation/screens/hapus_akun_screen.dart';
import 'legal/legal_routes.dart';
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
        //
        // Dikecualikan: kedua halaman kebijakan. Google Play mensyaratkan
        // kebijakan privasi dan jalur penghapusan akun dapat dibuka **tanpa
        // memasang aplikasi dan tanpa login** — reviewer membukanya dari browser
        // biasa, tanpa akun. Tanpa pengecualian ini yang dia lihat layar login,
        // dan halaman kebijakan yang tidak terbuka dianggap sama dengan tidak
        // ada. Isinya memang dokumen publik, jadi tidak ada yang bocor.
        if (session == null) {
          if (goingToLogin || rutePublikLegal.contains(loc)) return null;
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

        // Hub Kelola digerbangi peran, bukan hanya disembunyikan tabnya. Tanpa
        // ini seorang RM bisa mengetik '/kelola/export-data' dan mendapat
        // halaman yang tergambar lengkap tetapi seluruh tombolnya mati, yang
        // terbaca sebagai aplikasi rusak alih-alih sebagai penolakan akses.
        if (loc == '/kelola' || loc.startsWith('/kelola/')) {
          if (!Roles.hasAny(session.user.roles, Roles.kelolaHubRoles)) {
            return MbisApp.homeRouteForRoles(session.user.roles);
          }
        }
        return null;
      },
      routes: [
        // Fallback only — the redirect above always sends '/' elsewhere, so the
        // SplashScreen is never actually shown. Kept so initialLocation resolves.
        GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),

        // Halaman kebijakan publik — dikecualikan dari gerbang auth di atas.
        // URL inilah yang dilampirkan ke Play Console; reviewer membukanya dari
        // browser biasa tanpa akun. `showBack: false` karena keduanya bisa
        // mendarat sebagai halaman pertama, tanpa apa pun untuk dituju kembali.
        GoRoute(
            path: rutePublikKebijakan,
            builder: (_, _) => const KebijakanPrivasiScreen(showBack: false)),
        GoRoute(
            path: rutePublikHapusAkun,
            builder: (_, _) => const HapusAkunScreen(showBack: false)),
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
              // Pengajuan agen/TPM milik RM — pintunya "Ajukan Agen / TPM" di Profil.
              // Sengaja BUKAN bagian _konsolSubRoutes: konsol pengelolaan agen adalah
              // layar pimpinan kantor & kantor pusat, sedangkan layar ini hanya memuat
              // pengajuan pemanggilnya sendiri. Dirutekan (bukan Navigator.push) supaya
              // ketukan pada sebuah pengajuan memakai rute /agent-detail yang sama
              // seperti konsolnya.
              GoRoute(
                  path: 'pengajuan-agen',
                  builder: (_, _) => const AgentManagementScreen(mine: true)),
              // Rute 'export-visit-saya' dihapus (CR-13) — 'export' di bawah sudah
              // mencakup ekspor kunjungan, ter-scope di server.
              GoRoute(
                  path: 'export',
                  builder: (_, _) => const ExportScreen()),
              // Kebijakan privasi + jalur hapus akun (kewajiban Google Play).
              _privasiRoute(),
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
            '/agent/profil', 'agent-shell', 3, (i) => AgentMainScreen(index: i),
            subRoutes: [
              // Salinan untuk shell Agen, supaya back-nya kembali ke tab profil
              // Agen — bukan ke shell RM.
              _privasiRoute(),
            ]),

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

/// "Privasi & Akun" plus the full privacy policy nested under it.
///
/// Declared once and reused under both /profil (RM shell) and /agent/profil, so
/// back returns to the shell the user actually came from.
///
/// The policy is a *route*, not a `Navigator.push`: on web that gives it a real
/// URL (`/profil/privasi/kebijakan`) that survives a refresh and can be linked
/// to directly — Play requires the policy to be reachable from inside the app,
/// and a signed-in web user gets there without leaving it.
///
/// The store-listing URL is the separate, auth-exempt `/kebijakan-privasi`
/// declared at the top level. Same screen, same source text — only the entry
/// point and the back button differ.
GoRoute _privasiRoute() => GoRoute(
      path: 'privasi',
      // matchedLocation is the *resolved* path, so the same declaration yields
      // '/profil/privasi' under the RM shell and '/agent/profil/privasi' under
      // the agent shell — the screen links onward without knowing which shell
      // it was opened from.
      builder: (_, s) => PrivasiAkunScreen(basePath: s.matchedLocation),
      routes: [
        GoRoute(
            path: 'kebijakan',
            builder: (_, _) => const KebijakanPrivasiScreen()),
      ],
    );

/// The field tools, as a reusable sub-route list. Nested under the /tools tab
/// (for RM, whose tab 4 IS Tools) and under /kelola/tools (for BM/ADMIN, whose
/// tab 4 is the RM performance list), so back returns to the hub the user opened
/// the tool from.
///
/// `visit-map` adalah SATU-SATUNYA peta kunjungan, untuk semua peran — endpoint
/// di belakangnya ber-cakupan, jadi RM melihat kunjungannya sendiri dan penyelia
/// melihat kantornya. Rute lama `gps` (GPS Tracking, khusus RM) dihapus bersama
/// layarnya: dua peta bernama mirip sudah terbukti membuat orang salah menunjuk
/// layar. Kalau ada tautan lama ke `/tools/gps`, arahkan ke `visit-map`.
List<RouteBase> _toolsSubRoutes() => [
      GoRoute(
          path: 'product-knowledge',
          builder: (_, _) => const ProductKnowledgeScreen()),
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
      GoRoute(
          path: 'import-realisasi',
          builder: (_, _) => const ImportRealisasiScreen()),
      GoRoute(path: 'akun', builder: (_, _) => const KelolaAkunScreen()),
      GoRoute(
          path: 'aktivitas-ai',
          builder: (_, _) => const KelolaAktivitasAiScreen()),
      GoRoute(path: 'export-data', builder: (_, _) => const ExportDataScreen()),
      GoRoute(
          path: 'import-pipeline',
          builder: (_, _) => const ImportPipelineScreen()),
      GoRoute(
          path: 'import-target', builder: (_, _) => const ImportTargetScreen()),
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
