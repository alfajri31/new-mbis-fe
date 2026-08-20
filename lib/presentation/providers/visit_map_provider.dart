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

  /// Hitungan kunjungan se-cakupan, termasuk yang TANPA koordinat. [locations]
  /// hanya berisi yang bisa diplot, jadi angka inilah yang memungkinkan layar
  /// berkata "N kunjungan tercatat, tapi tak satu pun menyimpan koordinat".
  /// Null = belum termuat / gagal (kartu statistik menampilkan "–").
  final VisitTrackingSummary? summary;

  const VisitMapState({
    this.loading = true,
    this.error,
    this.locations = const [],
    this.offices = const [],
    this.officeFilter,
    this.selectedVisitId,
    this.summary,
  });

  VisitMapState copyWith({
    bool? loading,
    Object? error = _keep,
    List<VisitLocation>? locations,
    List<ScopeOffice>? offices,
    Object? officeFilter = _keep,
    Object? selectedVisitId = _keep,
    Object? summary = _keep,
  }) {
    return VisitMapState(
      loading: loading ?? this.loading,
      error: error == _keep ? this.error : error as String?,
      locations: locations ?? this.locations,
      offices: offices ?? this.offices,
      summary: summary == _keep ? this.summary : summary as VisitTrackingSummary?,
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
      // Hitungan menyusul dan TIDAK menahan peta: pin jauh lebih penting daripada
      // angka di kartu, dan kegagalannya tidak boleh mengosongkan peta yang sudah
      // benar. Gagal → summary dibiarkan null, kartunya menampilkan "–".
      _loadSummary();
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
        loading: false,
      );
    }
  }

  Future<void> _loadSummary() async {
    final officeId = state.officeFilter; // dibekukan: filter bisa berubah saat menunggu
    try {
      final summary = await _repo.getVisitTrackingSummary(officeId: officeId);
      // Filter sudah berganti selagi permintaan ini berjalan → hasilnya milik
      // pertanyaan lama; membuangnya lebih baik daripada angka yang tak cocok
      // dengan pin yang sedang tampil.
      if (officeId != state.officeFilter) return;
      state = state.copyWith(summary: summary);
    } catch (_) {
      if (officeId != state.officeFilter) return;
      state = state.copyWith(summary: null);
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

  /// Batal seleksi — menutup ringkasan kunjungan (CR-10). Dipanggil tombol tutup
  /// pada kartu ringkasan dan sebelum berpindah ke halaman customer: state ini
  /// hidup di notifier, jadi tanpa dibersihkan ringkasan lama sudah terbuka lagi
  /// saat peta dibuka berikutnya.
  void clearSelection() {
    state = state.copyWith(selectedVisitId: null);
  }
}
