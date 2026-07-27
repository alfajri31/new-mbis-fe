import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../providers/login_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // UI-ephemeral (tetap di widget): toggle visibilitas password + enable tombol
  // (derivasi murni dari controller). Keduanya bukan state async → tetap setState.
  bool _obscurePassword = true;
  bool _isButtonEnabled = false;

  // State async submit dikelola LoginNotifier. Getter berikut memproksinya agar
  // kode build/handler di bawah tetap memakai nama lama tanpa diubah.
  bool get _isLoading => ref.read(loginProvider).loading;
  String? get _errorMessage => ref.read(loginProvider).error;
  LoginNotifier get _loginNotifier => ref.read(loginProvider.notifier);

  /// At/above this width we show the desktop two-pane split (branding | form)
  /// instead of the stacked mobile hero + overlapping card.
  static const double _splitMinWidth = 900;

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(_updateButtonState);
    _passwordController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    final username = _usernameController.text;
    final password = _passwordController.text;
    setState(() {
      _isButtonEnabled = username.isNotEmpty && password.isNotEmpty;
    });
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    _loginNotifier.begin();

    try {
      final appState = MbisApp.of(context);
      if (appState == null) throw Exception('App State not found');

      final session = await appState.authRepository.login(
        identifier: _usernameController.text,
        password: _passwordController.text,
      );

      await appState.handleLogin(session);

      if (mounted) {
        _loginNotifier.done();
        // Return the user to wherever the auth gate intercepted them (?from=),
        // falling back to the role's home. Guard against looping back to the
        // login/root routes.
        final from = GoRouterState.of(context).uri.queryParameters['from'];
        final home = MbisApp.homeRouteForRoles(session.user.roles);
        final dest = (from != null &&
                from.isNotEmpty &&
                from != '/' &&
                !from.startsWith('/login'))
            ? from
            : home;
        context.go(dest);
      }
    } catch (e) {
      if (mounted) {
        _loginNotifier.fail(e.toString().replaceAll('Exception: ', ''));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage ?? 'Login failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state submit login → rebuild otomatis saat loading/error
    // berubah (pengganti setState untuk _isLoading/_errorMessage).
    ref.watch(loginProvider);
    // Dark status bar variant is handled by Theme and Scaffold
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return constraints.maxWidth >= _splitMinWidth
              ? _buildWideLayout(context)
              : _buildNarrowLayout(context);
        },
      ),
    );
  }

  /// Mobile / tablet-portrait: navy hero on top, form in an overlapping white card.
  Widget _buildNarrowLayout(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Top Section (Background Navy)
          Container(
            width: double.infinity,
            color: AppColors.primaryNavy,
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 48),
            child: _brandingContent(center: true),
          ),

          // Form Card Overlapping
          Transform.translate(
            offset: const Offset(0, -20),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [AppShadows.level4],
              ),
              child: _buildForm(context),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Desktop: branding fills the left, the form sits on a single side (right),
  /// constrained to a comfortable reading width — the typical desktop login.
  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        // Left branding panel.
        Expanded(
          flex: 5,
          child: Container(
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primaryNavy, AppColors.primaryNavyDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(64),
            // Vertically centred and nudged slightly left of centre (not pinned
            // to the edge) so the branding block sits a bit toward the left.
            child: Align(
              alignment: const Alignment(-0.35, 0),
              child: _brandingContent(center: false),
            ),
          ),
        ),
        // Right form panel — form only on this side.
        Expanded(
          flex: 4,
          child: Container(
            height: double.infinity,
            color: AppColors.surfaceWhite,
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _buildForm(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Logo + app name. [center] aligns it for the stacked mobile hero; otherwise
  /// it's left-aligned and larger for the desktop branding panel.
  Widget _brandingContent({required bool center}) {
    final cross = center ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final logoSize = center ? 68.0 : 88.0;
    final titleSize = center ? 26.0 : 36.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: cross,
      children: [
        // Logo
        Container(
          width: logoSize,
          height: logoSize,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Image.asset(
            'assets/images/logo-mbis.webp',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 16),
        // App Name and Subtitle
        Text(
          'M-BIS',
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'PT Askrindo (Persero)',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        // A short tagline only makes sense on the roomy desktop panel.
        if (!center) ...[
          const SizedBox(height: 28),
          Text(
            'Sistem Manajemen Bisnis untuk\nmemantau progres RM asuransi.',
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ],
    );
  }

  /// The login form (title, fields, actions). Shared by both layouts so the
  /// behaviour stays identical — only the surrounding chrome differs.
  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form Title
          const Text(
            'Masuk ke Akun',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          // Form Subtitle/Hint
          const Text(
            'Silakan masuk menggunakan kredensial Anda',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // Input Username/NIP
          const Text(
            'Username / NIP',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _usernameController,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Masukkan NIP atau CIF',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.person_outline,
                  color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.grayBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primaryNavy, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Input Password
          const Text(
            'Password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
            onFieldSubmitted: (_) {
              if (_isButtonEnabled && !_isLoading) _handleLogin();
            },
            decoration: InputDecoration(
              hintText: 'Masukkan password Anda',
              hintStyle: const TextStyle(color: AppColors.textSecondary),
              prefixIcon:
                  const Icon(Icons.lock_outline, color: AppColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
              filled: true,
              fillColor: AppColors.grayBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide:
                    const BorderSide(color: AppColors.primaryNavy, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Forgot Password Link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                // Link placeholder
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Lupa Password?',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryOrange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Button Masuk
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed:
                  (_isButtonEnabled && !_isLoading) ? _handleLogin : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNavy,
                disabledBackgroundColor: AppColors.grayBg,
                foregroundColor: Colors.white,
                disabledForegroundColor: AppColors.grayStage,
                elevation: _isButtonEnabled ? 4 : 0,
                shadowColor: AppColors.primaryNavy.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.0,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Masuk',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
