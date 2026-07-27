import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/visit/visit_repository.dart';

const Object _keep = Object();

/// State GPS Tracking Kunjungan — cerminan 1:1 dari field `setState` di layar lama.
/// HANYA data/loading (`_future`) & seleksi pin (`_selected`) yang pindah ke sini.
/// Peta tak digerakkan secara imperatif (tanpa `MapController`); `ApiClient` untuk
/// thumbnail `AuthImage` tetap di widget (lihat `gps_tracking_screen.dart`).
class GpsTrackingState {
  /// Future daftar kunjungan RM aktif (`/api/visits/me`) — dipakai FutureBuilder
  /// di layar. `null` = belum dimuat. (Dulu `_future`.)
  final Future<List<VisitModel>>? future;

  /// Pin/kunjungan terpilih untuk popup bawah; `null` = tak ada popup. (Dulu
  /// `_selected`.)
  final VisitModel? selected;

  const GpsTrackingState({this.future, this.selected});

  GpsTrackingState copyWith({
    Object? future = _keep,
    Object? selected = _keep,
  }) {
    return GpsTrackingState(
      future: future == _keep
          ? this.future
          : future as Future<List<VisitModel>>?,
      selected: selected == _keep ? this.selected : selected as VisitModel?,
    );
  }
}

final gpsTrackingProvider =
    NotifierProvider<GpsTrackingNotifier, GpsTrackingState>(
      GpsTrackingNotifier.new,
    );

/// Menggantikan seluruh logika `setState` di `_GpsTrackingScreenState`. Perilaku
/// (muat `/api/visits/me`, refresh + tutup popup, pilih/clear pin) DIPINDAH APA
/// ADANYA. Repo lama dipakai ulang lewat [visitRepoProvider].
class GpsTrackingNotifier extends Notifier<GpsTrackingState> {
  @override
  GpsTrackingState build() => const GpsTrackingState();

  VisitRepository get _repo => ref.read(visitRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Menggantikan inisiasi
  /// `_future ??= VisitRepository(...).getMyVisits()` yang dulu di
  /// `didChangeDependencies`.
  void start() {
    state = state.copyWith(future: _repo.getMyVisits());
  }

  /// Muat ulang daftar kunjungan lalu tutup popup, dan tunggu selesai (dipakai
  /// `onRetry`). (Dulu `setState(() { _future = ...; _selected = null; })`
  /// diikuti `await future`.)
  Future<void> refresh() async {
    final future = _repo.getMyVisits();
    state = state.copyWith(future: future, selected: null);
    await future;
  }

  /// Tandai pin terpilih (buka popup bawah). (Dulu `setState(() => _selected = v)`.)
  void select(VisitModel v) {
    state = state.copyWith(selected: v);
  }

  /// Batal seleksi / tutup popup. (Dulu `setState(() => _selected = null)`.)
  void clearSelection() {
    state = state.copyWith(selected: null);
  }
}
