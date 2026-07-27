import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/agent/agent_repository.dart';

const Object _keep = Object();

/// State layar profil agen — hanya memegang future load (pola FutureBuilder lama).
/// Cerminan 1:1 dari field `_future` `setState` di `agent_profil_screen.dart`.
class AgentProfilState {
  final Future<AgentSelfModel>? future;

  const AgentProfilState({this.future});

  AgentProfilState copyWith({Object? future = _keep}) {
    return AgentProfilState(
      future:
          future == _keep ? this.future : future as Future<AgentSelfModel>?,
    );
  }
}

final agentProfilProvider =
    NotifierProvider<AgentProfilNotifier, AgentProfilState>(
        AgentProfilNotifier.new);

/// Menggantikan logika `setState` (data/loading) di `_AgentProfilScreenState`.
/// Load dipindah apa adanya; `AgentRepository` kini dari [agentRepoProvider]
/// (membawa sesi aktif, ekuivalen `AgentRepository(apiClient: ApiClient(
/// session: MbisApp.of(context)?.session))`).
class AgentProfilNotifier extends Notifier<AgentProfilState> {
  @override
  AgentProfilState build() => const AgentProfilState();

  AgentRepository get _repo => ref.read(agentRepoProvider);

  /// Dipicu sekali dari `didChangeDependencies` layar. Hanya memulai load bila
  /// future belum ada — mirror perilaku `_future ??= _repo!.getMyProfile()`.
  void start() {
    if (state.future != null) return;
    state = state.copyWith(future: _repo.getMyProfile());
  }

  /// Tombol "Coba lagi" + setelah pengajuan perpanjangan sukses — pengganti
  /// `setState(() => _future = _repo!.getMyProfile())`.
  void reload() {
    state = state.copyWith(future: _repo.getMyProfile());
  }
}
