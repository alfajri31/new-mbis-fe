import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../../src/app.dart';
import '../../src/auth/roles.dart';
import 'dashboard_screen.dart';
import 'customer_list_screen.dart';
import 'bumn_screen.dart';
import 'broker_screen.dart';
import 'tools_screen.dart';
import 'kelola_screen.dart';
import 'rm_performance_screen.dart';
import 'profil_screen.dart';
import '../widgets/draggable_ai_button.dart';

/// RM/BM/RO/KUP/ADMIN shell. [index] is driven by the URL (see [router] —
/// /dashboard, /customer, …), so a web refresh restores the active tab. The
/// router gives every tab the same page key, so this widget's State (and the
/// IndexedStack's live children) persists across tab switches.
class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.index = 0});

  /// Active tab, supplied by the route. The bottom nav navigates by URL rather
  /// than mutating local state, so this is the single source of truth.
  final int index;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  /// Tab index → route, kept in sync with the order of the `screens` list
  /// built in [build].
  // Urutan harus sama dengan list `screens` di [build] dan dengan index di router.
  // Profil bukan tab navbar lagi (dibuka dari ikon profil di dashboard), tapi
  // tetap di index 5 supaya rute /profil & sub-menunya tetap hidup.
  static const _tabPaths = [
    '/dashboard', // 0
    '/customer',  // 1
    '/bumn',      // 2 (tengah)
    '/broker',    // 3
    '/tools',     // 4 (Tools / RM performance)
    '/profil',    // 5 (tanpa tombol navbar)
    '/kelola',    // 6 (hub Kelola — tab khusus ADMIN)
  ];

  // RM-tab filter lifted here so the dashboard's per-wilayah/cabang cards can
  // switch to the RM tab AND pre-apply a filter. Bumping the nonce rebuilds the
  // RM screen with the new filter; normal tab taps keep its state.
  String? _rmRegionId;
  String? _rmBranchId;
  String? _rmSearch;
  int _rmFilterNonce = 0;

  /// Supervisors (KUP/BM/RO/DPJ) don't use the field tools — their 4th tab is the
  /// RM performance list instead. Stable for the whole session.
  bool get _isSupervisor {
    final roles = MbisApp.of(context)?.session?.user.roles;
    final list = (roles as List?)?.map((e) => e.toString()).toList();
    return MbisApp.isSupervisorRole(list);
  }

  /// ADMIN, seluruh pimpinan kantor (BM/RO/KUP), dan divisi kantor pusat yang
  /// mengelola satu daftar master mendapat tab "Kelola" (index 6) di samping tab
  /// RM, supaya konsol yang boleh mereka pakai cukup satu ketukan — tidak lagi
  /// terselip di Profil. Hub-nya menyaring kartunya sendiri per peran. Tools ikut
  /// di dalamnya karena tab 4 mereka dipakai daftar kinerja RM, jadi tak ada ruang
  /// untuk tab Tools tersendiri.
  ///
  /// DIV_AUDIT & DIV_PROGRAM sengaja TIDAK dapat tab ini: mereka hanya boleh
  /// melihat, dan semua yang boleh mereka lihat sudah ada di tab Dashboard,
  /// Customer, BUMN, Broker, dan Tools. Memberi mereka hub Kelola hanya akan
  /// memunculkan pintu-pintu yang seluruhnya 403.
  bool get _hasKelolaTab {
    final roles = MbisApp.of(context)?.session?.user.roles ?? const [];
    return roles.contains('ADMIN') ||
        roles.contains('BM') ||
        roles.contains('RO') ||
        roles.contains('KUP') ||
        roles.any(Roles.curatorDivisions.contains);
  }

  /// RM gets the draggable AI quick-access button (others manage/don't run AI).
  bool get _isRm {
    final roles = MbisApp.of(context)?.session?.user.roles;
    final list = (roles as List?)?.map((e) => e.toString()).toList();
    return list?.contains('RM') ?? false;
  }

  void _onTabTapped(int index) {
    if (index == widget.index) return;
    context.go(_tabPaths[index]);
  }

  /// Switch to the RM tab (index 4, the supervisor's RM performance list) and
  /// apply the given filter (from a dashboard card). Bumping the nonce rebuilds
  /// RmPerformanceScreen with the new filter; the context.go drives the URL so
  /// the tab switch survives a refresh like every other tab.
  void _openRmTab({String? regionId, String? branchId, String? search}) {
    setState(() {
      _rmRegionId = regionId;
      _rmBranchId = branchId;
      _rmSearch = search;
      _rmFilterNonce++;
    });
    context.go(_tabPaths[4]);
  }

  @override
  Widget build(BuildContext context) {
    final supervisor = _isSupervisor;
    final kelola = _hasKelolaTab;
    final screens = <Widget>[
      DashboardScreen(
        onTabChange: _onTabTapped,
        // Supervisors (incl. admin) have the RM performance tab, so office/RM
        // cards on the dashboard switch to it.
        onOpenRmTab: supervisor ? _openRmTab : null,
      ),
      const CustomerListScreen(),
      const BumnScreen(),
      const BrokerScreen(),
      // Index 4: supervisors (incl. admin) → RM performance; field roles → Tools.
      supervisor
          ? RmPerformanceScreen(
              key: ValueKey(_rmFilterNonce),
              initialRegionId: _rmRegionId,
              initialBranchId: _rmBranchId,
              initialSearch: _rmSearch,
            )
          : const ToolsScreen(),
      const ProfilScreen(),
      // Index 6: management hub — a dedicated tab for ADMIN and BM. Other roles
      // never navigate here; the static screen is harmless in the IndexedStack.
      const KelolaScreen(),
    ];
    // Width-driven (NOT kIsWeb): a narrow browser window still gets the mobile
    // bottom-nav; a wide tablet/desktop gets the persistent side rail. Same
    // screens, same routes/indices — only the navigation chrome differs.
    return Responsive.isWide(context)
        ? _buildWideShell(context, screens, supervisor: supervisor, kelola: kelola)
        : _buildMobileShell(context, screens, supervisor: supervisor, kelola: kelola);
  }

  /// Tablet/desktop chrome: persistent left navigation rail + content area.
  Widget _buildWideShell(BuildContext context, List<Widget> screens,
      {required bool supervisor, required bool kelola}) {
    final extended = Responsive.isDesktop(context);
    // Index-4 swing: supervisors (incl. admin) get the RM performance list;
    // field roles get Tools. ADMIN/BM ALSO get a separate Kelola tab (index 6),
    // which is where they reach Tools from.
    final (IconData fourthIcon, IconData fourthActive, String fourthLabel) =
        supervisor
            ? (Icons.groups_outlined, Icons.groups, 'RM')
            : (Icons.construction_outlined, Icons.construction, 'Tools');
    // Rail order (Profil always last; Kelola shown for ADMIN/BM, before Profil).
    // Positions map to tab indices via [railTabs] — they aren't 1:1.
    final railTabs = <int>[0, 1, 2, 3, 4, if (kelola) 6, 5];
    NavigationRailDestination destFor(int i) {
      switch (i) {
        case 0:
          return const NavigationRailDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: Text('Dashboard'));
        case 1:
          return const NavigationRailDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: Text('Customer'));
        case 2:
          return const NavigationRailDestination(
              icon: Icon(Icons.account_balance_outlined),
              selectedIcon: Icon(Icons.account_balance),
              label: Text('BUMN'));
        case 3:
          return const NavigationRailDestination(
              icon: Icon(Icons.handshake_outlined),
              selectedIcon: Icon(Icons.handshake),
              label: Text('Broker'));
        case 5:
          return const NavigationRailDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: Text('Profil'));
        case 6:
          return const NavigationRailDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: Text('Kelola'));
        default: // 4 — role-dependent swing
          return NavigationRailDestination(
              icon: Icon(fourthIcon),
              selectedIcon: Icon(fourthActive),
              label: Text(fourthLabel));
      }
    }

    final selectedRail = railTabs.indexOf(widget.index);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Row(
        children: [
          // NavigationRail tidak bisa men-scroll destinasinya sendiri: dengan 7 menu
          // (ADMIN) di layar landscape tingginya kurang dan Flutter melapor
          // "BOTTOM OVERFLOWED BY 196 PIXELS" — menu terakhir terpotong. Bungkus
          // dengan scroll + minHeight setinggi viewport supaya tampilannya tetap
          // penuh saat muat, dan bisa digeser saat tidak muat.
          LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: NavigationRail(
            extended: extended,
            // Trim the extended width (default 256) so the rail isn't so wide.
            minExtendedWidth: 200,
            backgroundColor: AppColors.surfaceWhite,
            selectedIndex: selectedRail < 0 ? 0 : selectedRail,
            onDestinationSelected: (pos) => _onTabTapped(railTabs[pos]),
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            // Active pill is orange; make the selected icon white so it stays
            // legible against it (navy-on-orange was too low-contrast).
            indicatorColor: AppColors.secondaryOrange,
            selectedIconTheme: const IconThemeData(color: Colors.white),
            unselectedIconTheme: const IconThemeData(color: AppColors.grayStage),
            selectedLabelTextStyle: const TextStyle(
                color: AppColors.primaryNavy, fontWeight: FontWeight.w600),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Image.asset('assets/images/logo-mbis.webp',
                  width: 40, height: 40),
            ),
            destinations: [for (final i in railTabs) destFor(i)],
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.border),
          Expanded(
            child: IndexedStack(index: widget.index, children: screens),
          ),
        ],
      ),
    );
  }

  /// Mobile chrome: bottom navigation bar + single-column content.
  Widget _buildMobileShell(BuildContext context, List<Widget> screens,
      {required bool supervisor, required bool kelola}) {
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: Stack(
        children: [
          IndexedStack(
            index: widget.index,
            children: screens,
          ),
          // AssistiveTouch-style AI button, draggable, RM only.
          if (_isRm) const Positioned.fill(child: DraggableAiButton()),
        ],
      ),
      bottomNavigationBar: Container(
        // No fixed height here — SafeArea below adds the device's bottom system
        // inset (3-button nav / gesture pill) as extra height so the nav row
        // itself always gets its full 64px instead of being squeezed/clipped
        // by the system bar (was: SafeArea nested inside a fixed-height box).
        decoration: const BoxDecoration(
          color: AppColors.surfaceWhite,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            // ADMIN/BM have an extra tab (RM + Kelola), so they use a flat 6-item
            // row; the other roles keep the BUMN-centred 5-item layout.
            child: kelola ? _kelolaNavRow() : _defaultNavRow(supervisor),
          ),
        ),
      ),
    );
  }

  /// Bottom nav for RM/supervisor/field: Dashboard, Customer, BUMN (centre),
  /// Broker, and the role's 4th tab (RM for supervisors, Tools for field).
  Widget _defaultNavRow(bool supervisor) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, 'Dashboard', Icons.home_outlined, Icons.home),
              _buildNavItem(1, 'Customer', Icons.people_outline, Icons.people),
            ],
          ),
        ),
        Expanded(flex: 1, child: _buildBumnNavItem()),
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(3, 'Broker', Icons.handshake_outlined, Icons.handshake),
              supervisor
                  ? _buildNavItem(4, 'RM', Icons.groups_outlined, Icons.groups)
                  : _buildNavItem(4, 'Tools', Icons.construction_outlined, Icons.construction),
            ],
          ),
        ),
      ],
    );
  }

  /// ADMIN/BM bottom nav: six even tabs — the RM performance list AND the Kelola
  /// hub. Both roles are supervisors, so tab 4 is always the RM list here.
  Widget _kelolaNavRow() {
    return Row(
      children: [
        _buildNavItem(0, 'Dashboard', Icons.home_outlined, Icons.home),
        _buildNavItem(1, 'Customer', Icons.people_outline, Icons.people),
        _buildNavItem(2, 'BUMN', Icons.account_balance_outlined, Icons.account_balance),
        _buildNavItem(3, 'Broker', Icons.handshake_outlined, Icons.handshake),
        _buildNavItem(4, 'RM', Icons.groups_outlined, Icons.groups),
        _buildNavItem(6, 'Kelola', Icons.settings_outlined, Icons.settings),
      ],
    );
  }

  Widget _buildNavItem(int index, String label, IconData inactiveIcon, IconData activeIcon) {
    final isActive = widget.index == index;
    final color = isActive ? AppColors.primaryNavy : AppColors.grayStage;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : inactiveIcon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
            if (isActive) ...[
              const SizedBox(height: 2),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primaryNavy,
                  shape: BoxShape.circle,
                ),
              ),
            ] else ...[
              const SizedBox(height: 6), // Spacer to maintain size
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBumnNavItem() {
    final isActive = widget.index == 2;
    final color = isActive ? AppColors.primaryNavy : AppColors.grayStage;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabTapped(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? Icons.account_balance : Icons.account_balance_outlined,
            color: color,
            size: 22,
          ),
          const SizedBox(height: 2),
          Text(
            'BUMN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: color,
            ),
          ),
          if (isActive) ...[
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: const BoxDecoration(
                color: AppColors.primaryNavy,
                shape: BoxShape.circle,
              ),
            ),
          ] else ...[
            const SizedBox(height: 6), // Spacer to maintain size
          ],
        ],
      ),
    );
  }
}
