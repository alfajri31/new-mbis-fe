import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/assistant/ai_activity_admin_repository.dart';

const Object _keep = Object();

/// State layar Kelola Aktivitas AI (ADMIN) — cerminan 1:1 dari field `setState`
/// di `_KelolaAktivitasAiScreenState` lama (`_ready`/`_loading`/`_error`/
/// `_components`/`_activities`). Perilaku load DIPINDAH APA ADANYA.
class KelolaAktivitasAiState {
  final bool ready;
  final bool loading;
  final String? error;
  final List<AiComponent> components;
  final List<AdminActivity> activities;

  const KelolaAktivitasAiState({
    this.ready = false,
    this.loading = true,
    this.error,
    this.components = const [],
    this.activities = const [],
  });

  KelolaAktivitasAiState copyWith({
    bool? ready,
    bool? loading,
    Object? error = _keep,
    List<AiComponent>? components,
    List<AdminActivity>? activities,
  }) {
    return KelolaAktivitasAiState(
      ready: ready ?? this.ready,
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      components: components ?? this.components,
      activities: activities ?? this.activities,
    );
  }
}

final kelolaAktivitasAiProvider =
    NotifierProvider<KelolaAktivitasAiNotifier, KelolaAktivitasAiState>(
        KelolaAktivitasAiNotifier.new);

/// Menggantikan logika `setState` data/loading di `_KelolaAktivitasAiScreenState`.
/// Aksi tulis (toggle/delete) + dialog/snackbar tetap di layar; notifier ini hanya
/// memegang muatan daftar + status muat (dipakai balik lewat [load]).
class KelolaAktivitasAiNotifier extends Notifier<KelolaAktivitasAiState> {
  @override
  KelolaAktivitasAiState build() => const KelolaAktivitasAiState();

  AiActivityAdminRepository get _repo => ref.read(aiActivityAdminRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Menggantikan pembuatan
  /// repo + `_ready = true` + `_load()` di post-frame callback lama. Repo kini
  /// dibaca dari aiActivityAdminRepoProvider (membawa sesi aktif).
  void start() {
    state = state.copyWith(ready: true);
    load();
  }

  /// Muat komponen + daftar aktivitas. Dipindah apa adanya dari `_load()`.
  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final comps = await _repo.getComponents();
      final acts = await _repo.list();
      state = state.copyWith(
        components: comps,
        activities: acts,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(error: '$e', loading: false);
    }
  }
}
