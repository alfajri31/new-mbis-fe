import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/broker/broker_repository.dart';
import 'package:mbis/src/common/partner_kpi.dart';

const Object _keep = Object();

/// State layar Broker (S-201) — cerminan 1:1 dari field `setState` di layar lama
/// (`_future`, `_kpi`, `_query`). Immutable + [copyWith] dengan sentinel `_keep`
/// agar field nullable (`future`, `kpi`) bisa dibiarkan atau di-set null eksplisit.
class BrokerState {
  /// Data broker (read-only view atas pipeline milik customer). Dulu `_future`.
  final Future<List<BrokerView>>? future;

  /// KPI global broker (total 150, with-pipeline, won, premi, stages). Dulu `_kpi`.
  final PartnerKpi? kpi;

  /// Kata kunci pencarian broker/kode (client-side). Dulu `_query`.
  final String query;

  const BrokerState({
    this.future,
    this.kpi,
    this.query = '',
  });

  BrokerState copyWith({
    Object? future = _keep,
    Object? kpi = _keep,
    String? query,
  }) {
    return BrokerState(
      future:
          future == _keep ? this.future : future as Future<List<BrokerView>>?,
      kpi: kpi == _keep ? this.kpi : kpi as PartnerKpi?,
      query: query ?? this.query,
    );
  }
}

final brokerProvider =
    NotifierProvider<BrokerNotifier, BrokerState>(BrokerNotifier.new);

/// Menggantikan seluruh logika `setState` di `_BrokerScreenState`.
/// Perilaku (muat data, KPI dekoratif best-effort, filter query) DIPINDAH APA
/// ADANYA — migrasi ini hanya memindah TEMPAT state, bukan mengubah perilaku.
class BrokerNotifier extends Notifier<BrokerState> {
  @override
  BrokerState build() => const BrokerState();

  BrokerRepository get _repo => ref.read(brokerRepoProvider);

  /// Dipanggil dari `didChangeDependencies` layar (load-once). Menggantikan blok
  /// pemuatan lama: `if (_future == null) { _future = ...; _loadKpi(); }`.
  void start() {
    if (state.future != null) return;
    state = state.copyWith(future: _repo.getBrokerViews());
    _loadKpi();
  }

  /// Refresh saat kembali dari layar yang dipush / pull-to-refresh. Dipindah utuh
  /// dari `_refresh()`.
  Future<void> refresh() async {
    final future = _repo.getBrokerViews();
    state = state.copyWith(future: future);
    _loadKpi();
    await future;
  }

  Future<void> _loadKpi() async {
    try {
      final kpi = await _repo.getBrokerKpi();
      state = state.copyWith(kpi: kpi);
    } catch (_) {
      // KPI cards are decorative; leave them as "–" on failure.
    }
  }

  /// Dari `onChanged` kolom cari: dulu `setState(() => _query = v.trim())`.
  void onSearchChanged(String value) {
    state = state.copyWith(query: value.trim());
  }

  /// Dari tombol hapus pencarian: dulu `setState(() => _query = '')`.
  void clearQuery() {
    state = state.copyWith(query: '');
  }
}
