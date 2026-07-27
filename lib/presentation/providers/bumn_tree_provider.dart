import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/bumn/bumn_repository.dart';

const Object _keep = Object();

/// State layar Ekosistem BUMN (pohon master_bumn) — cerminan 1:1 dari field
/// `setState` di layar lama (`_future`, `_query`). Immutable + [copyWith] dengan
/// sentinel `_keep` agar field nullable (`future`) bisa dibiarkan apa adanya.
///
/// Expand/collapse tiap node = state internal `ExpansionTile` (murni UI) dan
/// TETAP di widget — tak dipindah ke sini karena tak memicu load.
class BumnTreeState {
  /// Pohon ekosistem BUMN (Induk → Anak → Cucu → Cicit). Dulu `_future`.
  final Future<List<BumnTreeNode>>? future;

  /// Kata kunci pencarian lintas-level (client-side; mode datar saat terisi).
  /// Dulu `_query`.
  final String query;

  const BumnTreeState({
    this.future,
    this.query = '',
  });

  BumnTreeState copyWith({
    Object? future = _keep,
    String? query,
  }) {
    return BumnTreeState(
      future:
          future == _keep ? this.future : future as Future<List<BumnTreeNode>>?,
      query: query ?? this.query,
    );
  }
}

final bumnTreeProvider =
    NotifierProvider<BumnTreeNotifier, BumnTreeState>(BumnTreeNotifier.new);

/// Menggantikan seluruh logika `setState` di `_BumnTreeScreenState`.
/// Perilaku (muat pohon load-once, refresh, filter query) DIPINDAH APA ADANYA —
/// migrasi ini hanya memindah TEMPAT state, bukan mengubah perilaku.
class BumnTreeNotifier extends Notifier<BumnTreeState> {
  @override
  BumnTreeState build() => const BumnTreeState();

  BumnRepository get _repo => ref.read(bumnRepoProvider);

  /// Dipanggil dari `didChangeDependencies` layar (load-once). Menggantikan blok
  /// lama: `_repo ??= ...; _future ??= _repo!.getBumnTree();`.
  void start() {
    if (state.future != null) return;
    state = state.copyWith(future: _repo.getBumnTree());
  }

  /// Pull-to-refresh / retry. Dipindah utuh dari `_refresh()`.
  Future<void> refresh() async {
    final f = _repo.getBumnTree();
    state = state.copyWith(future: f);
    await f;
  }

  /// Dari `onChanged` kolom cari: dulu `setState(() => _query = v.trim())`.
  void onSearchChanged(String value) {
    state = state.copyWith(query: value.trim());
  }
}
