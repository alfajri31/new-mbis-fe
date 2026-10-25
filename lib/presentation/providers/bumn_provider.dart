import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/bumn/bumn_repository.dart';
import 'package:mbis/src/common/partner_kpi.dart';

const Object _keep = Object();

class BumnFilter {
  final String wil;
  final String cab;
  final String rm;
  final String stage;
  final String kat;

  const BumnFilter({
    this.wil = '',
    this.cab = '',
    this.rm = '',
    this.stage = '',
    this.kat = '',
  });

  bool get isActive =>
      wil.isNotEmpty ||
      cab.isNotEmpty ||
      rm.isNotEmpty ||
      stage.isNotEmpty ||
      kat.isNotEmpty;

  int get count =>
      (wil.isNotEmpty ? 1 : 0) +
      (cab.isNotEmpty ? 1 : 0) +
      (rm.isNotEmpty ? 1 : 0) +
      (stage.isNotEmpty ? 1 : 0) +
      (kat.isNotEmpty ? 1 : 0);

  BumnFilter copyWith({
    String? wil,
    String? cab,
    String? rm,
    String? stage,
    String? kat,
  }) {
    return BumnFilter(
      wil: wil ?? this.wil,
      cab: cab ?? this.cab,
      rm: rm ?? this.rm,
      stage: stage ?? this.stage,
      kat: kat ?? this.kat,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BumnFilter &&
          runtimeType == other.runtimeType &&
          wil == other.wil &&
          cab == other.cab &&
          rm == other.rm &&
          stage == other.stage &&
          kat == other.kat;

  @override
  int get hashCode =>
      wil.hashCode ^
      cab.hashCode ^
      rm.hashCode ^
      stage.hashCode ^
      kat.hashCode;
}

/// State layar BUMN — cerminan 1:1 dari field `setState` di layar lama.
///
/// [future] menampung daftar pohon BUMN (dulu `_future`, dikonsumsi FutureBuilder).
/// [kpi] = KPI layar BUMN dari server; ter-scope kecuali `total` yang tetap ukuran
/// ekosistem master (dulu `_kpi`). [query] = kata kunci pencarian ter-debounce
/// (dulu `_query`). [expanded] = set id node yang terbuka (dulu `_expanded`).
/// [selectedId]/[selectedNode] = node terpilih yang menyetir kartu KPI (dulu
/// `_selectedId`/`_selectedNode`). [includeDescendants] = lingkup kartu node
/// terpilih: node + turunan vs node saja (dulu `_includeDescendants`).
class BumnState {
  final Future<List<BumnTreeCustomer>>? future;
  final PartnerKpi? kpi;
  final String query;
  final Set<String> expanded;

  /// Node yang DILIPAT manual saat mode pencarian. Kebalikan dari [expanded]:
  /// di mode pencarian semua cabang terbuka secara bawaan, jadi yang perlu diingat
  /// justru yang ditutup pengguna. Set terpisah supaya status buka/tutup mode biasa
  /// tidak bocor ke mode pencarian (dan sebaliknya).
  final Set<String> searchCollapsed;
  final String? selectedId;
  final BumnTreeCustomer? selectedNode;
  final bool includeDescendants;
  final BumnFilter filter;

  const BumnState({
    this.future,
    this.kpi,
    this.query = '',
    this.expanded = const <String>{},
    this.searchCollapsed = const <String>{},
    this.selectedId,
    this.selectedNode,
    this.includeDescendants = true,
    this.filter = const BumnFilter(),
  });

  BumnState copyWith({
    Object? future = _keep,
    Object? kpi = _keep,
    String? query,
    Set<String>? expanded,
    Set<String>? searchCollapsed,
    Object? selectedId = _keep,
    Object? selectedNode = _keep,
    bool? includeDescendants,
    BumnFilter? filter,
  }) {
    return BumnState(
      future: future == _keep
          ? this.future
          : future as Future<List<BumnTreeCustomer>>?,
      kpi: kpi == _keep ? this.kpi : kpi as PartnerKpi?,
      query: query ?? this.query,
      expanded: expanded ?? this.expanded,
      searchCollapsed: searchCollapsed ?? this.searchCollapsed,
      selectedId: selectedId == _keep ? this.selectedId : selectedId as String?,
      selectedNode: selectedNode == _keep
          ? this.selectedNode
          : selectedNode as BumnTreeCustomer?,
      includeDescendants: includeDescendants ?? this.includeDescendants,
      filter: filter ?? this.filter,
    );
  }
}

final bumnProvider =
    NotifierProvider<BumnNotifier, BumnState>(BumnNotifier.new);

/// Menggantikan seluruh logika `setState` di `_BumnScreenState`. Perilaku
/// (bootstrap tree + KPI, refresh, select/clear node, expand/collapse, query
/// ter-debounce, lingkup turunan) DIPINDAH APA ADANYA. Debounce, scroll, dan
/// controller pencarian tetap di widget (UI-ephemeral).
class BumnNotifier extends Notifier<BumnState> {
  @override
  BumnState build() => const BumnState();

  BumnRepository get _repo => ref.read(bumnRepoProvider);

  /// Dipanggil sekali per mount dari layar (dulu blok `if (_future == null)` di
  /// `didChangeDependencies`). Mulai muat pohon BUMN + KPI-nya.
  void start() {
    final future = _repo.getBumnCustomerTree();
    state = state.copyWith(future: future);
    _loadKpi();
  }

  /// Kembali dari layar lain (detail) → muat ulang + reset seleksi/expand.
  Future<void> refresh() async {
    final future = _repo.getBumnCustomerTree();
    state = state.copyWith(
      future: future,
      selectedId: null,
      selectedNode: null,
      expanded: <String>{},
      searchCollapsed: <String>{},
    );
    _loadKpi();
    await future;
  }

  Future<void> _loadKpi() async {
    try {
      final kpi = await _repo.getBumnKpi();
      state = state.copyWith(kpi: kpi);
    } catch (_) {
      // KPI cards are decorative; leave them as "–" on failure.
    }
  }

  /// Tap node: pilih, atau tap ulang node yang sama → lepas seleksi.
  void selectNode(BumnTreeCustomer n) {
    if (state.selectedId == n.id) {
      state = state.copyWith(selectedId: null, selectedNode: null);
    } else {
      state = state.copyWith(selectedId: n.id, selectedNode: n);
    }
  }

  void clearSelection() =>
      state = state.copyWith(selectedId: null, selectedNode: null);

  /// Tutup/buka satu cabang di mode pencarian (bawaannya terbuka).
  void toggleSearchCollapse(String id) {
    final next = Set<String>.from(state.searchCollapsed);
    if (!next.remove(id)) {
      next.add(id);
    }
    state = state.copyWith(searchCollapsed: next);
  }

  void toggleExpand(String id) {
    final next = Set<String>.from(state.expanded);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(expanded: next);
  }

  /// Nilai final pencarian (setelah debounce di widget). Hasil pencarian tak
  /// ber-scope node → seleksi dilepas saat query tak kosong.
  void setQuery(String value) {
    final q = value.trim();
    // Kata kunci berubah -> hasil pencariannya lain, jadi lipatan lama tidak lagi
    // bermakna; tanpa reset ini sebuah cabang bisa tampak "tertutup" tanpa sebab.
    if (q.isNotEmpty) {
      state = state.copyWith(
          query: q,
          selectedId: null,
          selectedNode: null,
          searchCollapsed: <String>{});
    } else {
      state = state.copyWith(query: q, searchCollapsed: <String>{});
    }
  }

  void setFilter(BumnFilter filter) {
    state = state.copyWith(
      filter: filter,
      selectedId: null,
      selectedNode: null,
      searchCollapsed: <String>{},
    );
  }

  void resetFilter() {
    state = state.copyWith(
      filter: const BumnFilter(),
      selectedId: null,
      selectedNode: null,
      searchCollapsed: <String>{},
    );
  }

  void setIncludeDescendants(bool value) =>
      state = state.copyWith(includeDescendants: value);
}
