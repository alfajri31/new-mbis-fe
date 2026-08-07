import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/network/api_client.dart';
import '../widgets/back_app_bar.dart';

/// "Email Akun" — pengguna mengganti email akunnya sendiri
/// (POST /api/auth/change-email), tanpa perlu meminta admin.
///
/// Password sekarang wajib disertakan, dan itu bukan formalitas: email juga
/// dipakai sebagai identitas login (NIP → CIF agen → email), jadi sesi yang
/// terlanjur dibajak tidak boleh bisa menggesernya diam-diam.
///
/// Layar ini hanya terbuka untuk peran yang dilayani server (RM, dan lewat
/// hierarki peran KUP + ADMIN); akun agen memakai jalur lain karena email
/// akunnya mengikuti data agennya.
class GantiEmailScreen extends ConsumerStatefulWidget {
  const GantiEmailScreen({super.key});

  @override
  ConsumerState<GantiEmailScreen> createState() => _GantiEmailScreenState();
}

class _GantiEmailScreenState extends ConsumerState<GantiEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();

  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_submitting) return;
    setState(() => _submitting = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final app = MbisApp.of(context);
    final api = ApiClient(session: app?.session);

    try {
      final res = await api.post('/api/auth/change-email', body: {
        'currentPassword': _passwordController.text,
        'newEmail': _emailController.text.trim(),
      });
      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Penggantian email TIDAK mencabut sesi (beda dari ganti password), dan
        // klaim `email` pada token yang sudah terbit masih yang lama — layar
        // profil membacanya dari klaim itu. Tukar token lewat refresh supaya
        // email baru langsung tampil tanpa memaksa pengguna login ulang.
        final refreshed = await _refreshSession(app);
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(
          content: Text(refreshed
              ? 'Email akun berhasil diubah.'
              : 'Email akun berhasil diubah. Tampilan profil menyesuaikan '
                  'setelah login berikutnya.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.successGreen,
        ));
        navigator.pop(true);
        return;
      }

      final message = _extractMessage(res.body);
      setState(() => _submitting = false);
      messenger.showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      messenger.showSnackBar(const SnackBar(
        content: Text('Gagal mengubah email. Coba lagi.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Tukar token supaya klaimnya memuat email baru. Kegagalannya BUKAN kegagalan
  /// operasi — emailnya sudah tersimpan di server; yang tertinggal hanya tampilan
  /// sampai login berikutnya.
  Future<bool> _refreshSession(MbisAppState? app) async {
    final token = app?.session?.refreshToken;
    if (app == null || token == null || token.isEmpty) return false;
    try {
      final fresh = await app.authRepository.refresh(token);
      await app.handleLogin(fresh);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['message']?.toString() ?? 'Gagal mengubah email';
    } catch (_) {
      return 'Gagal mengubah email';
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = MbisApp.of(context)?.session?.user.email ?? '-';
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: const BackAppBar(title: 'Email Akun'),
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
                  child: const Text(
                    'Email akun juga bisa dipakai untuk login, jadi perubahannya '
                    'perlu dikonfirmasi dengan password. Pastikan alamat barunya '
                    'benar dan memang milikmu — alamat yang salah membuat akun '
                    'ini sulit dipulihkan.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                _label('Email Sekarang'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.bgScreen,
                    borderRadius: AppRadius.radiusMd,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(current,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: AppSpacing.lg),
                _label('Email Baru'),
                TextFormField(
                  controller: _emailController,
                  style: AppInput.fieldText,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: _decoration('nama@askrindo.co.id'),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Email baru wajib diisi';
                    // Sekadar penyaring salah ketik yang kasar; server tetap
                    // memvalidasi format dan menolak alamat yang sudah dipakai.
                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                      return 'Format email tidak valid';
                    }
                    if (value.toLowerCase() ==
                        (MbisApp.of(context)?.session?.user.email ?? '').toLowerCase()) {
                      return 'Email baru sama dengan email sekarang';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _label('Password Sekarang'),
                TextFormField(
                  controller: _passwordController,
                  style: AppInput.fieldText,
                  obscureText: _obscurePassword,
                  decoration: _decoration('Masukkan password saat ini').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                          color: AppColors.grayStage),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Password wajib diisi' : null,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNavy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Simpan Email Baru',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
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

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surfaceWhite,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
      );
}
