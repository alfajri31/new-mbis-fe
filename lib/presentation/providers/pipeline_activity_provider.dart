import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/pipeline/pipeline_repository.dart';
import 'package:mbis/src/visit/visit_repository.dart';

const Object _keep = Object();

/// State Jadwal & Riwayat pipeline — cerminan 1:1 dari field `setState` di
/// `pipeline_activity_screen` lama. Hanya state DATA/LOADING & filter yang
/// pindah; ScrollController/Timer/navigasi/sheet tetap di widget.
class PipelineActivityState {
  final bool loading;
  final String? error;
  final List<PipelineScheduleModel> schedules;
  final List<VisitModel> visits;
  final List<PipelineHistoryModel> history;
  final String filter; // ALL | OPEN | DONE
  final bool showEdits; // edits are frequent & low-signal; opt in to see them

  const PipelineActivityState({
    this.loading = true,
    this.error,
    this.schedules = const [],
    this.visits = const [],
    this.history = const [],
    this.filter = 'ALL',
    this.showEdits = false,
  });

  PipelineActivityState copyWith({
    bool? loading,
    Object? error = _keep,
    List<PipelineScheduleModel>? schedules,
    List<VisitModel>? visits,
    List<PipelineHistoryModel>? history,
    String? filter,
    bool? showEdits,
  }) {
    return PipelineActivityState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      schedules: schedules ?? this.schedules,
      visits: visits ?? this.visits,
      history: history ?? this.history,
      filter: filter ?? this.filter,
      showEdits: showEdits ?? this.showEdits,
    );
  }
}

final pipelineActivityProvider =
    NotifierProvider<PipelineActivityNotifier, PipelineActivityState>(
      PipelineActivityNotifier.new,
    );

/// Menggantikan seluruh logika `setState` di `_PipelineActivityScreenState`.
/// Perilaku (fetch best-effort visits/history, mark done + refetch, filter,
/// toggle edits) DIPINDAH APA ADANYA.
class PipelineActivityNotifier extends Notifier<PipelineActivityState> {
  /// Pipeline yang sedang dilihat. Dulu dibaca dari `widget.pipelineId`;
  /// kini di-set sekali lewat [start] (post-frame initState layar).
  late String _pipelineId;

  @override
  PipelineActivityState build() => const PipelineActivityState();

  PipelineRepository get _pipelineRepo => ref.read(pipelineRepoProvider);
  VisitRepository get _visitRepo => ref.read(visitRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Simpan id + fetch.
  /// Menggantikan bagian data dari `initState`.
  void start({required String pipelineId}) {
    _pipelineId = pipelineId;
    fetch();
  }

  Future<void> fetch() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final detail = await _pipelineRepo.getPipelineDetail(_pipelineId);
      final schedules = [...detail.schedules]
        ..sort((a, b) => (a.date ?? '').compareTo(b.date ?? ''));
      List<VisitModel> visits = [];
      try {
        visits = await _visitRepo.getVisits(_pipelineId);
      } catch (_) {}
      // Best-effort like visits: a missing history shouldn't blank the Jadwal tab.
      List<PipelineHistoryModel> history = [];
      try {
        history = await _pipelineRepo.getPipelineHistory(_pipelineId);
      } catch (_) {}
      state = state.copyWith(
        schedules: schedules,
        visits: visits,
        history: history,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }

  /// Bagian data dari `_markDone` — set status lalu refetch. Snackbar (UI) tetap
  /// di widget; jalur error identik (throw dari sini bila set status gagal).
  Future<void> markDone(PipelineScheduleModel s) async {
    await _pipelineRepo.setScheduleStatus(s.id, 'DONE');
    await fetch();
  }

  void setFilter(String filter) => state = state.copyWith(filter: filter);

  void setShowEdits(bool showEdits) =>
      state = state.copyWith(showEdits: showEdits);
}
