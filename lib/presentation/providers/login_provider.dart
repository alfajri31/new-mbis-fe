import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Sentinel agar `copyWith` bisa membedakan "tak diubah" dari "diset ke null"
/// pada field nullable [LoginState.error] (mis. bersihkan error saat mulai).
const Object _keep = Object();

/// State submit login — cerminan 1:1 dari dua field `setState` di layar lama
/// (`_isLoading` + `_errorMessage`). Kontrol form, controller, toggle password,
/// validator, panggilan login, dan navigasi TETAP di widget.
class LoginState {
  final bool loading;
  final String? error;

  const LoginState({
    this.loading = false,
    this.error,
  });

  LoginState copyWith({
    bool? loading,
    Object? error = _keep,
  }) {
    return LoginState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
    );
  }
}

final loginProvider =
    NotifierProvider<LoginNotifier, LoginState>(LoginNotifier.new);

/// Mengelola STATE async submit login (loading/error). Perilaku dipindah apa
/// adanya: mulai submit → loading true + error dibersihkan; sukses → loading
/// false; gagal → loading false + pesan error. Panggilan login & navigasi
/// (`MbisApp.of(context)?.handleLogin(session)`) tetap dikerjakan widget.
class LoginNotifier extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  /// Mulai submit: tampilkan spinner, bersihkan error sebelumnya.
  void begin() => state = state.copyWith(loading: true, error: null);

  /// Submit gagal: sembunyikan spinner, simpan pesan error.
  void fail(String message) =>
      state = state.copyWith(loading: false, error: message);

  /// Submit selesai (sukses): sembunyikan spinner.
  void done() => state = state.copyWith(loading: false);
}
