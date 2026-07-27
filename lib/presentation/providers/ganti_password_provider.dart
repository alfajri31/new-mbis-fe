import 'package:flutter_riverpod/flutter_riverpod.dart';

const Object _keep = Object();

/// State submit "Ganti Password" — cerminan 1:1 dari field `setState` async di
/// layar lama (`_isSubmitting` + pesan error). Controller password, toggle
/// visibility, validator, dan panggilan change-password + navigasi/logout TETAP
/// di widget (form/auth). Yang dipindah HANYA flag loading + error async.
class GantiPasswordState {
  final bool saving;
  final String? error;

  const GantiPasswordState({
    this.saving = false,
    this.error,
  });

  GantiPasswordState copyWith({
    bool? saving,
    Object? error = _keep,
  }) {
    return GantiPasswordState(
      saving: saving ?? this.saving,
      error: error == _keep ? this.error : error as String?,
    );
  }
}

final gantiPasswordProvider =
    NotifierProvider<GantiPasswordNotifier, GantiPasswordState>(
        GantiPasswordNotifier.new);

/// Mengelola state submit ganti password (loading/error). Perilaku dipindah apa
/// adanya dari `setState(() => _isSubmitting = ...)` di `_GantiPasswordScreenState`.
class GantiPasswordNotifier extends Notifier<GantiPasswordState> {
  @override
  GantiPasswordState build() => const GantiPasswordState();

  /// Awal submit: tandai sedang menyimpan, bersihkan error sebelumnya.
  void begin() => state = state.copyWith(saving: true, error: null);

  /// Submit gagal: berhenti menyimpan, simpan pesan error.
  void fail(String message) =>
      state = state.copyWith(saving: false, error: message);

  /// Submit selesai (sukses / berhenti): berhenti menyimpan.
  void done() => state = state.copyWith(saving: false);

  /// Dipanggil saat layar dibuka. Provider ini keepAlive, jadi state-nya hidup
  /// lebih lama dari layar — tanpa reset, sisa `saving`/`error` dari sesi
  /// sebelumnya terbawa dan tombol Simpan langsung tampil loading + nonaktif.
  void reset() => state = const GantiPasswordState();
}
