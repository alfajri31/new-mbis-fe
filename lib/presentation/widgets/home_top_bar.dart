import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import '../screens/notifikasi_screen.dart';

/// Full-width navy bar at the very top of the home screens (RM & Agen/TPM).
///
/// Holds the bits that used to live inside the floating welcome card: the
/// greeting, the user's name, a role/office subtitle, a notification bell and
/// the profile avatar. It bleeds edge-to-edge and reaches up under the status
/// bar, so the home screens render light status-bar icons over it.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.name,
    required this.initials,
    this.subtitle,
    this.office = 'Kantor Cabang Padang',
    this.profileRoute = '/profil',
    this.showConnectTag = false,
  });

  final String name;
  final String initials;
  final String? subtitle;

  /// Nama kantor cabang yang ditampilkan di chip bawah header (mis. 'Kantor Cabang Padang').
  final String? office;

  /// Shows a "Connect" badge next to the subtitle (jabatan) — RM tagged as
  /// Connect by an admin (via Kelola Akun), post-piloting feedback. Read-only
  /// here; only admin can set it.
  final bool showConnectTag;

  /// Destination for the avatar tap. Defaults to the RM shell's profile tab;
  /// the agent shell passes '/agent/profil' so tapping it stays inside the
  /// agent shell (otherwise it jumps to the RM shell and swaps the bottom bar).
  final String profileRoute;

  /// Two-letter initials from a full name, e.g. "Indah Tang" -> "IT".
  static String initialsOf(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    // Navy band bleeds edge-to-edge, tapi ISI-nya (greeting/avatar) di-cap + center
    // agar sejajar dengan konten body yang juga di-cap pada layar lebar (kalau tidak,
    // header terlihat "menggantung" lebih lebar dari konten di bawahnya).
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: topInset + AppSpacing.sm, bottom: AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.primaryNavy,
        boxShadow: [AppShadows.level2],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: Responsive.isWide(context)
                ? Responsive.contentMaxWidthFor(context)
                : double.infinity,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selamat datang!',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (subtitle != null && subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.55),
                                    ),
                                  ),
                                ),
                                if (showConnectTag) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                    child: const Text(
                                      'Connect',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const NotifikasiScreen()),
                      ),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.notifications_none,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => context.go(profileRoute),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.secondaryOrange,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (office != null && office!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.apartment,
                          size: 16,
                          color: Color(0xFFF6B489),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          office!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
