import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/dashboard/dashboard_repository.dart';
import 'package:mbis/utils/format.dart';

const Object _keep = Object();

/// State layar "Semua Jadwal" — cerminan 1:1 dari field `setState` di layar lama.
/// Hanya state DATA/ASYNC yang pindah; controller/RouteAware/navigasi tetap di widget.
class SemuaJadwalState {
  final bool loading;
  final String? error;
  final List<DashboardSchedule> schedules;
  // null = "Semua" (tampilkan semua tanggal); selain itu key `yyyy-m-d` yang difilter.
  final String? selectedDateKey;

  const SemuaJadwalState({
    this.loading = true,
    this.error,
    this.schedules = const [],
    this.selectedDateKey,
  });

  SemuaJadwalState copyWith({
    bool? loading,
    Object? error = _keep,
    List<DashboardSchedule>? schedules,
    Object? selectedDateKey = _keep,
  }) {
    return SemuaJadwalState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      schedules: schedules ?? this.schedules,
      selectedDateKey: selectedDateKey == _keep
          ? this.selectedDateKey
          : selectedDateKey as String?,
    );
  }

  /// Agenda per-tanggal (derivasi murni dari [schedules]) — menggantikan field
  /// `_groups` yang dulu dihitung sekali di dalam `_fetch`.
  List<DateGroup> get groups => groupSchedulesByDate(schedules);
}

final semuaJadwalProvider =
    NotifierProvider<SemuaJadwalNotifier, SemuaJadwalState>(
      SemuaJadwalNotifier.new,
    );

/// Menggantikan seluruh logika `setState` di `_SemuaJadwalScreenState`.
/// Perilaku (loading/error, grouping, drop filter usang) DIPINDAH APA ADANYA.
class SemuaJadwalNotifier extends Notifier<SemuaJadwalState> {
  @override
  SemuaJadwalState build() => const SemuaJadwalState();

  DashboardRepository get _repo => ref.read(dashboardRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Repo & sesi datang dari
  /// provider bersama (apiClientProvider membawa sesi), jadi cukup memuat data.
  void start() {
    fetch();
  }

  Future<void> fetch({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(loading: true, error: null);
    }
    try {
      final s = await _repo.getSchedules();
      final newGroups = groupSchedulesByDate(s);
      // Drop a stale filter if that date no longer has any visits after refresh.
      final keepKey =
          (state.selectedDateKey != null &&
              !newGroups.any((g) => g.key == state.selectedDateKey))
          ? null
          : state.selectedDateKey;
      state = state.copyWith(
        schedules: s,
        selectedDateKey: keepKey,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }

  void selectDate(String? key) {
    state = state.copyWith(selectedDateKey: key);
  }
}

/// Groups schedules by calendar date, sorted chronologically (the nearest
/// visits first), so the list reads as a per-date agenda.
List<DateGroup> groupSchedulesByDate(List<DashboardSchedule> items) {
  final sorted = [...items]
    ..sort((a, b) {
      final da = _parseDt(a);
      final db = _parseDt(b);
      if (da == null && db == null) return 0;
      if (da == null) return 1; // undated entries sink to the bottom
      if (db == null) return -1;
      return da.compareTo(db);
    });
  final groups = <DateGroup>[];
  final indexByKey = <String, int>{};
  for (final s in sorted) {
    final dt = _parseDt(s);
    final key = dt != null ? '${dt.year}-${dt.month}-${dt.day}' : 'unknown';
    final existing = indexByKey[key];
    if (existing == null) {
      indexByKey[key] = groups.length;
      groups.add(
        DateGroup(
          key,
          dt,
          AppFormat.dayDate(s.scheduleDateTime ?? s.scheduleDate),
          [s],
        ),
      );
    } else {
      groups[existing].items.add(s);
    }
  }
  return groups;
}

DateTime? _parseDt(DashboardSchedule s) =>
    DateTime.tryParse(s.scheduleDateTime ?? s.scheduleDate ?? '')?.toLocal();

/// One calendar-date bucket of schedules for the agenda view.
class DateGroup {
  final String key; // `yyyy-m-d`, used to match the selected date chip
  final DateTime? date; // parsed date for chip labels (null = undated bucket)
  final String label;
  final List<DashboardSchedule> items;
  DateGroup(this.key, this.date, this.label, this.items);
}
