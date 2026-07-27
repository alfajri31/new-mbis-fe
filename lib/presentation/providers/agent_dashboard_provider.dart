import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/agent/agent_repository.dart';
import 'package:mbis/src/announcement/announcement_repository.dart';

const Object _keep = Object();

/// Data agregat dashboard agen (profil + kinerja + pengumuman). Dulu kelas
/// privat `_AgentData` di `agent_dashboard_screen.dart`; dipindah utuh ke sini
/// agar `future`-nya bisa hidup di state Riverpod.
class AgentDashboardData {
  final AgentSelfModel agent;
  final AgentDashboardModel perf;
  final List<Announcement> announcements;
  AgentDashboardData(this.agent, this.perf, this.announcements);
}

/// State dashboard agen — cerminan 1:1 dari field `_future` (FutureBuilder) di
/// layar lama. FutureBuilder tetap dipakai; hanya lokasi future yang pindah.
class AgentDashboardState {
  final Future<AgentDashboardData>? future;

  const AgentDashboardState({this.future});

  AgentDashboardState copyWith({
    Object? future = _keep,
  }) {
    return AgentDashboardState(
      future: future == _keep
          ? this.future
          : future as Future<AgentDashboardData>?,
    );
  }
}

final agentDashboardProvider =
    NotifierProvider<AgentDashboardNotifier, AgentDashboardState>(
        AgentDashboardNotifier.new);

/// Menggantikan logika pemuatan `setState`/FutureBuilder di
/// `_AgentDashboardScreenState`. Perilaku (guard sekali, error non-kritis
/// pengumuman) DIPINDAH APA ADANYA.
class AgentDashboardNotifier extends Notifier<AgentDashboardState> {
  @override
  AgentDashboardState build() => const AgentDashboardState();

  AgentRepository get _repo => ref.read(agentRepoProvider);
  AnnouncementRepository get _annRepo => ref.read(announcementRepoProvider);

  /// Dipanggil dari `didChangeDependencies` layar (sebelum build pertama).
  /// Guard sekali menggantikan `_future ??= _load()` — didChangeDependencies
  /// bisa dipanggil berulang, jadi hanya load bila belum ada future.
  void start() {
    if (state.future != null) return;
    state = state.copyWith(future: _load());
  }

  /// Muat ulang dari tombol "Coba lagi". Dulu `setState(() => _future = _load())`.
  void reload() {
    state = state.copyWith(future: _load());
  }

  Future<AgentDashboardData> _load() async {
    final results = await Future.wait([
      _repo.getMyProfile(),
      _repo.getMyDashboard(),
    ]);
    // Announcements are non-critical: never let a banner error block the page.
    List<Announcement> announcements = const [];
    try {
      announcements = await _annRepo.feed();
    } catch (_) {}
    return AgentDashboardData(
      results[0] as AgentSelfModel,
      results[1] as AgentDashboardModel,
      announcements,
    );
  }
}
