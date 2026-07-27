import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import 'agent_dashboard_screen.dart';
import 'customer_list_screen.dart';
import 'ajukan_komisi_screen.dart';
import 'agent_profil_screen.dart';

/// Agent portal shell — mirrors the RM [MainScreen] but with agent-appropriate
/// tabs (no Broker; pipelines are a flat list). Reuses the RM customer screen.
///
/// [index] is URL-driven (see [router] — /agent, /agent/customer, …) so a web
/// refresh restores the active tab; tabs share one page key so this State and
/// the IndexedStack's live children survive tab switches.
class AgentMainScreen extends StatefulWidget {
  const AgentMainScreen({super.key, this.index = 0});

  final int index;

  @override
  State<AgentMainScreen> createState() => _AgentMainScreenState();
}

class _AgentMainScreenState extends State<AgentMainScreen> {
  /// Tab index → route, kept in sync with the order of [_screens].
  static const _tabPaths = [
    '/agent',
    '/agent/customer',
    '/agent/komisi',
    '/agent/profil',
  ];

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      AgentDashboardScreen(onTabChange: _onTabTapped),
      const CustomerListScreen(agentScoped: true),
      const AjukanKomisiScreen(),
      const AgentProfilScreen(),
    ];
  }

  void _onTabTapped(int index) {
    if (index == widget.index) return;
    context.go(_tabPaths[index]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: IndexedStack(index: widget.index, children: _screens),
      bottomNavigationBar: Container(
        // No fixed height here — SafeArea below adds the device's bottom system
        // inset (3-button nav / gesture pill) as extra height so the nav row
        // itself always gets its full 64px instead of being squeezed/clipped
        // by the system bar (was: SafeArea nested inside a fixed-height box).
        decoration: const BoxDecoration(
          color: AppColors.surfaceWhite,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _navItem(0, 'Dashboard', Icons.home_outlined, Icons.home),
                _navItem(1, 'Customer', Icons.people_outline, Icons.people),
                _navItem(2, 'Komisi', Icons.payments_outlined, Icons.payments),
                _navItem(3, 'Profil', Icons.person_outline, Icons.person),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
      int index, String label, IconData inactiveIcon, IconData activeIcon) {
    final isActive = widget.index == index;
    final color = isActive ? AppColors.primaryNavy : AppColors.grayStage;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabTapped(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isActive ? activeIcon : inactiveIcon, color: color, size: 22),
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
                    color: AppColors.primaryNavy, shape: BoxShape.circle),
              ),
            ] else
              const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
