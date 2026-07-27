import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/dashboard/dashboard_repository.dart';

const Object _keep = Object();

/// State peta kunjungan — cerminan 1:1 dari field `setState` di layar lama.
/// HANYA data/loading yang pindah ke sini; `MapController`, pemusatan peta,
/// dan pembangunan marker tetap di widget (lihat `visit_map_screen.dart`).
class VisitMapState {
  final bool loading;
  final String? error;
  final List<VisitLocation> locations;
  final List<ScopeOffice> offices;
  final String? officeFilter; // selected office id, null = whole scope
  final String? selectedVisitId;

  const VisitMapState({
    this.loading = true,
    this.error,
    this.locations = const [],
    this.offices = const [],
    this.officeFilter,
    this.selectedVisitId,
  });

  VisitMapState copyWith({
    bool? loading,
    Object? error = _keep,
    List<VisitLocation>? locations,
    List<ScopeOffice>? offices,
    Object? officeFilter = _keep,
    Object? selectedVisitId = _keep,
  }) {
    return VisitMapState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      locations: locations ?? this.locations,
      offices: offices ?? this.offices,
      officeFilter: officeFilter == _keep
          ? this.officeFilter
          : officeFilter as String?,
      selectedVisitId: selectedVisitId == _keep
          ? this.selectedVisitId
          : selectedVisitId as String?,
    );
  }
}

final visitMapProvider = NotifierProvider<VisitMapNotifier, VisitMapState>(
  VisitMapNotifier.new,
);

/// Menggantikan logika `setState` di `_VisitMapScreenState`. Perilaku
/// (bootstrap scope → fetch lokasi, filter kantor, seleksi) DIPINDAH APA ADANYA.
/// Efek peta (fit/move) tetap di widget — lihat catatan tiap method.
class VisitMapNotifier extends Notifier<VisitMapState> {
  @override
  VisitMapState build() => const VisitMapState();

  DashboardRepository get _repo => ref.read(dashboardRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Menggantikan
  /// `initState` + `_bootstrap`: muat daftar kantor scope lalu lokasi.
  void start() {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final offices = await _repo.getScopeOffices();
      state = state.copyWith(offices: offices);
      await fetchLocations();
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }

  /// Muat lokasi kunjungan untuk filter kantor aktif. Menggantikan
  /// `_fetchLocations`; pemusatan peta (`_fitToLocations`) ditangani widget
  /// secara reaktif saat [VisitMapState.locations] berubah.
  Future<void> fetchLocations() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final locations = await _repo.getVisitLocations(
        officeId: state.officeFilter,
      );
      state = state.copyWith(
        locations: locations,
        loading: false,
        selectedVisitId: null,
      );
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }

  /// Ganti filter kantor lalu muat ulang lokasi. (Dulu `setState`+`_fetchLocations`
  /// di `onChanged` dropdown.)
  void onFilterChanged(String? v) {
    state = state.copyWith(officeFilter: v);
    fetchLocations();
  }

  /// Tandai lokasi terpilih (marker/list highlight). Gerakan peta
  /// (`_mapController.move`) tetap di widget. (Dulu bagian `setState` di `_focus`.)
  void select(VisitLocation loc) {
    state = state.copyWith(selectedVisitId: loc.visitId);
  }
}
