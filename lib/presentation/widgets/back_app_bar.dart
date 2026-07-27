import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../src/nav.dart';

/// Light sub-screen app bar with a back button (design.md §3.2 light variant).
/// Used by pushed utility screens (Kalkulator, Product Knowledge, GPS Tracking).
class BackAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget> actions;

  const BackAppBar({super.key, required this.title, this.actions = const []});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 1);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surfaceWhite,
      surfaceTintColor: AppColors.surfaceWhite,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: () => safePop(context),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      actions: actions,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1.0),
        child: Container(color: AppColors.border, height: 1.0),
      ),
    );
  }
}
