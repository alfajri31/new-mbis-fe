import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/agent/agent_repository.dart';

const Object _keep = Object();

/// State detail agen — cerminan 1:1 dari field `setState` DATA/LOADING di layar
/// lama. `_busy` (overlay aksi tulis yang sedang berjalan) TIDAK ikut: itu murni
/// UI-gating aksi tulis (dialog/snackbar) & tetap dikelola widget dengan
/// `setState`, sejalan aturan migrasi (hanya state DATA/LOADING yang dipindah).
class AgentDetailState {
  final AgentModel? agent;
  final List<AgentDocumentModel> docs;
  final bool loading;
  final String? error;

  const AgentDetailState({
    this.agent,
    this.docs = const [],
    this.loading = true,
    this.error,
  });

  AgentDetailState copyWith({
    Object? agent = _keep,
    List<AgentDocumentModel>? docs,
    bool? loading,
    Object? error = _keep,
  }) {
    return AgentDetailState(
      agent: agent == _keep ? this.agent : agent as AgentModel?,
      docs: docs ?? this.docs,
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
    );
  }
}

final agentDetailProvider =
    NotifierProvider<AgentDetailNotifier, AgentDetailState>(
      AgentDetailNotifier.new,
    );

/// Menggantikan logika `setState` DATA/LOADING di `_AgentDetailScreenState`.
/// Perilaku (fetch agen, guard best-effort dokumen, error handling) DIPINDAH
/// APA ADANYA. Repository legacy dipakai ulang lewat shared provider (bukan
/// konstruksi `ApiClient` sendiri).
class AgentDetailNotifier extends Notifier<AgentDetailState> {
  /// Id agen yang dimuat; diisi sekali dari [start] (dulu `widget.agentId`).
  late String _agentId;

  @override
  AgentDetailState build() => const AgentDetailState();

  AgentRepository get _repo => ref.read(agentRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Menggantikan bagian
  /// data dari `didChangeDependencies` lama (konstruksi repo kini via provider).
  void start(String agentId) {
    _agentId = agentId;
    load();
  }

  /// Memuat detail agen + dokumen. Dipakai saat bootstrap dan sebagai reload
  /// pasca aksi tulis (approve/reject/issue CIF/dll.) yang dipicu widget.
  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final agent = await _repo.getAgent(_agentId);
      List<AgentDocumentModel> docs = const [];
      try {
        docs = await _repo.getDocuments(_agentId);
      } catch (_) {
        // documents are optional; ignore if not accessible
      }
      state = state.copyWith(
        agent: agent,
        docs: docs,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: '$e'.replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }
}
