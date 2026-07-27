import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/assistant/ai_activity_admin_repository.dart';

const Object _keep = Object();

/// State layar Kelola Model AI (ADMIN) — cerminan 1:1 dari field `setState` di
/// `_KelolaModelAiScreenState`. Hanya data/loading/list yang dipindah; input
/// edit (dialog tambah/ubah model) & aksi tulis (aktifkan/hapus/simpan) tetap
/// di widget dan mendorong hasilnya lewat [reload].
class KelolaModelAiState {
  final bool ready;
  final bool loading;
  final String? error;
  final List<AdminAiModel> models;

  const KelolaModelAiState({
    this.ready = false,
    this.loading = true,
    this.error,
    this.models = const [],
  });

  KelolaModelAiState copyWith({
    bool? ready,
    bool? loading,
    Object? error = _keep,
    List<AdminAiModel>? models,
  }) {
    return KelolaModelAiState(
      ready: ready ?? this.ready,
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      models: models ?? this.models,
    );
  }
}

final kelolaModelAiProvider =
    NotifierProvider<KelolaModelAiNotifier, KelolaModelAiState>(
        KelolaModelAiNotifier.new);

/// Menggantikan logika `setState` (data/loading/list) di `_KelolaModelAiScreenState`.
/// Perilaku dipindah APA ADANYA. Aksi tulis (aktifkan/hapus/tambah/ubah model)
/// tetap di widget dan memicu muat ulang lewat [reload]; dialog editnya tak tersentuh.
class KelolaModelAiNotifier extends Notifier<KelolaModelAiState> {
  @override
  KelolaModelAiState build() => const KelolaModelAiState();

  AiModelAdminRepository get _repo => ref.read(aiModelAdminRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Repo kini dari provider
  /// (dulu dibuat dari `MbisApp.of(context)?.session`). Menggantikan `initState`.
  void start() {
    state = state.copyWith(ready: true);
    reload();
  }

  Future<void> reload() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final models = await _repo.list();
      state = state.copyWith(models: models, loading: false);
    } catch (e) {
      state = state.copyWith(error: '$e', loading: false);
    }
  }
}
