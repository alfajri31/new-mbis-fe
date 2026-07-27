import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/app_providers.dart';
import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/pipeline/pipeline_repository.dart';
import 'package:mbis/presentation/screens/tender_status_screen.dart';

/// State layar Ubah Status Pipeline (tender) — cerminan 1:1 dari `setState` di
/// `_TenderStatusScreenState`. Hanya loading (`busy`) + penanda label master
/// sudah termuat (`labelsLoaded`) yang pindah ke sini; controller/dialog/sheet,
/// navigasi, dan form Won tetap di widget.
class TenderStatusState {
  /// Proses advance/lost sedang berjalan (tombol → spinner, aksi dikunci).
  final bool busy;

  /// Label PROSES_TENDER dari master data sudah selesai dimuat — dipakai hanya
  /// untuk memicu rebuild setelah `loadTenderLabels` (dulu `setState(() {})`).
  final bool labelsLoaded;

  const TenderStatusState({this.busy = false, this.labelsLoaded = false});

  TenderStatusState copyWith({bool? busy, bool? labelsLoaded}) {
    return TenderStatusState(
      busy: busy ?? this.busy,
      labelsLoaded: labelsLoaded ?? this.labelsLoaded,
    );
  }
}

final tenderStatusProvider =
    NotifierProvider<TenderStatusNotifier, TenderStatusState>(
        TenderStatusNotifier.new);

/// Menggantikan logika `setState` di `_TenderStatusScreenState`. Perilaku
/// (urutan pick-role → won-sheet → advance, guard, error handling) DIPINDAH APA
/// ADANYA; orkestrasi dialog/navigasi tetap di widget yang memanggil method ini.
class TenderStatusNotifier extends Notifier<TenderStatusState> {
  @override
  TenderStatusState build() => const TenderStatusState();

  PipelineRepository get _repo => ref.read(pipelineRepoProvider);

  /// Dipanggil sekali dari initState layar (post-frame). Reset state (provider
  /// dipakai ulang antar buka layar) lalu muat label langkah tender dari master
  /// data; rebuild saat berhasil. Menggantikan `initState`.
  void start() {
    state = const TenderStatusState();
    // Muat label langkah tender dari master data; rebuild bila berhasil.
    loadTenderLabels(ref.read(apiClientProvider)).then((_) {
      state = state.copyWith(labelsLoaded: true);
    });
  }

  /// Maju satu proses tender. Mengembalikan `null` bila sukses (widget lalu
  /// pop(true)), atau pesan error bila gagal (widget menampilkan snackbar).
  /// Body sudah dirakit di widget (role / form Won) sebelum dipanggil.
  Future<String?> advance(String pipelineId, Map<String, dynamic> body) async {
    state = state.copyWith(busy: true);
    try {
      await _repo.advanceTender(pipelineId, body);
      return null;
    } catch (e) {
      state = state.copyWith(busy: false);
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Tandai tender Lost. `null` = sukses; selain itu pesan error. Alasan sudah
  /// dikumpulkan lewat dialog di widget.
  Future<String?> lost(String pipelineId, String reason) async {
    state = state.copyWith(busy: true);
    try {
      await _repo.lostTender(pipelineId, reason);
      return null;
    } catch (e) {
      state = state.copyWith(busy: false);
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}
