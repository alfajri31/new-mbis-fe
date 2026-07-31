import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/network/api_client.dart';
import '../providers/ganti_password_provider.dart';
import '../widgets/back_app_bar.dart';

/// "Keamanan & Password" — the logged-in user changes their own password
/// (POST /api/auth/change-password). Requires the current password; there is no
/// self-service reset by design — a user who forgets their password contacts an
/// admin, who sets a new one via Kelola Akun.
class GantiPasswordScreen extends ConsumerStatefulWidget {
  const GantiPasswordScreen({super.key, this.forced = false});

  /// When true this screen is the mandatory first-login password change (the
  /// router redirects here and won't let the user leave until it's done). Hides
  /// the back button and blocks the back gesture; otherwise it's the normal
  /// self-service "Keamanan & Password" screen reachable from the profile.
  final bool forced;

  @override
  ConsumerState<GantiPasswordScreen> createState() =>
      _GantiPasswordScreenState();
}

class _GantiPasswordScreenState extends ConsumerState<GantiPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  // Toggle visibility murni UI-ephemeral → tetap setState di widget.
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Flag submit async dikelola GantiPasswordNotifier. Getter memproksinya agar
  // kode build/handler di bawah tetap memakai nama lama tanpa diubah.
  bool get _isSubmitting => ref.read(gantiPasswordProvider).saving;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(gantiPasswordProvider.notifier).reset();
    });
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSubmitting) return;
    final notifier = ref.read(gantiPasswordProvider.notifier);
    notifier.begin();

    final messenger = ScaffoldMessenger.of(context);
    final app = MbisApp.of(context);
    final api = ApiClient(session: app?.session);

    try {
      final res = await api.post('/api/auth/change-password', body: {
        'currentPassword': _currentController.text,
        'newPassword': _newController.text,
      });
      if (!mounted) return;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Password change logs out every device, including this one (the current
        // access token is now invalid server-side). Sign out locally and send the
        // user back to login to re-authenticate with the new password.
        messenger.showSnackBar(const SnackBar(
          content: Text('Password berhasil diubah. Silakan login kembali.'),
          behavior: SnackBarBehavior.floating,
        ));
        await app?.handleLogout();
        if (!mounted) return;
        context.go('/login');
        return;
      }
      final message = _extractMessage(res.body);
      notifier.fail(message);
      messenger.showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      notifier.fail('Gagal mengubah password. Coba lagi.');
      messenger.showSnackBar(const SnackBar(
        content: Text('Gagal mengubah password. Coba lagi.'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      // Tanpa guard `mounted`: pada jalur sukses layar sudah dilepas (logout +
      // go('/login')), sedangkan state notifier keepAlive tetap hidup. Kalau
      // done() dilewati, `saving` tertinggal true dan tombol Simpan pada
      // pembukaan layar berikutnya macet loading + nonaktif.
      notifier.done();
    }
  }

  String _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['message']?.toString() ?? 'Gagal mengubah password';
    } catch (_) {
      return 'Gagal mengubah password';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild saat flag submit berubah (tombol enable/disable + spinner).
    ref.watch(gantiPasswordProvider);
    final forced = widget.forced;
    return PopScope(
      // In forced mode the user must complete the change; block the back gesture.
      canPop: !forced,
      child: Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: forced
          ? AppBar(
              backgroundColor: AppColors.primaryNavy,
              foregroundColor: Colors.white,
              automaticallyImplyLeading: false,
              title: const Text('Ganti Password Wajib'),
            )
          : const BackAppBar(title: 'Keamanan & Password'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.navyBg,
                    borderRadius: AppRadius.radiusMd,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    forced
                        ? 'Demi keamanan, akun ini memakai password awal bersama. '
                            'Silakan buat password baru milikmu sendiri untuk melanjutkan. '
                            'Masukkan password awal sebagai "Password Lama".'
                        : 'Lupa password? Hubungi admin untuk mengatur ulang. '
                            'Halaman ini hanya untuk mengganti password dengan password lama yang masih kamu ingat.',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _label('Password Lama'),
                _passwordField(
                  controller: _currentController,
                  obscure: _obscureCurrent,
                  onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
                  hint: 'Masukkan password saat ini',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Password lama wajib diisi' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                _label('Password Baru'),
                _passwordField(
                  controller: _newController,
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  hint: 'Minimal 8 karakter',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password baru wajib diisi';
                    if (v.length < 8) return 'Password baru minimal 8 karakter';
                    if (v == _currentController.text) {
                      return 'Password baru harus berbeda dari password lama';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _label('Konfirmasi Password Baru'),
                _passwordField(
                  controller: _confirmController,
                  obscure: _obscureConfirm,
                  onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  hint: 'Ulangi password baru',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Konfirmasi password wajib diisi';
                    if (v != _newController.text) return 'Konfirmasi tidak cocok';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Simpan Password Baru',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      );

  Widget _passwordField({
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String hint,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      style: AppInput.fieldText,
      obscureText: obscure,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusMd,
          borderSide: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
        ),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              size: 20, color: AppColors.grayStage),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
