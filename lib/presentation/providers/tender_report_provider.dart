import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/tender/tender_repository.dart';

const Object _keep = Object();

/// State Report Tender — cerminan 1:1 dari field `setState` di layar lama:
///  - [future] : hasil `getReport()` yang dikonsumsi `FutureBuilder` (DATA/LOADING).
///    Dulu `_future` (di-init lazy di `didChangeDependencies`).
///  - [filter] : chip Semua/Menang/Kalah. Dulu `_filter`.
class TenderReportState {
  final Future<TenderReport>? future;
  final String filter; // all | won | loss

  const TenderReportState({
    this.future,
    this.filter = 'all',
  });

  TenderReportState copyWith({
    Object? future = _keep,
    String? filter,
  }) {
    return TenderReportState(
      future: future == _keep ? this.future : future as Future<TenderReport>?,
      filter: filter ?? this.filter,
    );
  }
}

final tenderReportProvider =
    NotifierProvider<TenderReportNotifier, TenderReportState>(
        TenderReportNotifier.new);

/// Menggantikan logika `setState` di `_TenderReportScreenState`. Perilaku
/// (muat sekali saat masuk, refresh, ganti filter) DIPINDAH APA ADANYA.
class TenderReportNotifier extends Notifier<TenderReportState> {
  TenderRepository get _repo => ref.read(tenderRepoProvider);

  /// Muat report sekali saat provider pertama dibaca layar — meniru
  /// `_future ??= _repo!.getReport()` di `didChangeDependencies`, yang berjalan
  /// SEBELUM build pertama sehingga frame pertama sudah menampilkan skeleton
  /// (bukan report kosong). `ref.read` → tak memicu ulang saat apiClient berubah,
  /// jadi request hanya sekali seperti guard `??=` lama.
  @override
  TenderReportState build() => TenderReportState(future: _repo.getReport());

  /// Pull-to-refresh / retry. Meniru `setState(() => _future = f); await f;` —
  /// pasang future baru lalu tunggu agar spinner RefreshIndicator tetap hidup.
  Future<void> refresh() async {
    final f = _repo.getReport();
    state = state.copyWith(future: f);
    await f;
  }

  /// Ganti filter chip. Dulu `setState(() => _filter = value)`.
  void setFilter(String value) => state = state.copyWith(filter: value);
}
