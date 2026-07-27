import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Redirect after 900ms — a brief branded beat, not a load wait. On web the
    // HTML splash (web/index.html) already showed this exact branded screen while
    // the wasm bundle downloaded and cross-fades into this one, so a long hold here
    // would just be a second, redundant delay. Keep it short.
    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      // Navigate directly here — do NOT wrap in addPostFrameCallback. By 900ms the
      // bar animation (800ms) has finished and the page is idle, so no frame is
      // scheduled; a post-frame callback would then never run until something else
      // schedules a frame (a reload, window resize, or tap), leaving the splash
      // stuck. The Timer already fires outside the build phase, so calling go_router
      // here is safe. (In practice the '/' redirect in the router sends users to
      // their home before this screen is ever shown — this is a belt-and-braces
      // fallback that reuses the same role-aware home mapping.)
      final session = MbisApp.of(context)?.session;
      context.go(session != null
          ? MbisApp.homeRouteForRoles(session.user.roles)
          : '/login');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryNavy,
      body: Stack(
        children: [
          // Main content centered
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Container
                Container(
                  width: 88,
                  height: 88,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryNavy.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/logo-mbis.webp',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                // App Name
                const Text(
                  'M-BIS',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle
                Text(
                  'Manajemen Bisnis'.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11, // Tiny / Caption style
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.65),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                // Loading bar (160x3dp, bg white 20%, fill orange). Fills in
                // 800ms — just under the 900ms redirect timer so it visibly
                // completes and the page is idle before navigating.
                SizedBox(
                  width: 160,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(1.5),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return LinearProgressIndicator(
                          value: value,
                          backgroundColor: Colors.white.withValues(alpha: 0.20),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.secondaryOrange,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Company label at the bottom (bottom 48dp)
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Text(
              'PT Askrindo (Persero)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.50),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
