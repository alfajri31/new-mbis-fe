import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/bumn/bumn_repository.dart';
import 'package:mbis/src/common/partner_kpi.dart';

const Object _keep = Object();

/// State layar BUMN — cerminan 1:1 dari field `setState` di layar lama.
///
/// [future] menampung daftar pohon BUMN (dulu `_future`, dikonsumsi FutureBuilder).
/// [kpi] = KPI global (dulu `_kpi`). [query] = kata kunci pencarian ter-debounce
/// (dulu `_query`). [expanded] = set id node yang terbuka (dulu `_expanded`).
/// [selectedId]/[selectedNode] = node terpilih yang menyetir kartu KPI (dulu
/// `_selectedId`/`_selectedNode`). [includeDescendants] = lingkup kartu node
/// terpilih: node + turunan vs node saja (dulu `_includeDescendants`).
class BumnState {
  final Future<List<BumnTreeCustomer>>? future;
  final PartnerKpi? kpi;
  final String query;
  final Set<String> expanded;
  final String? selectedId;
  final BumnTreeCustomer? selectedNode;
  final bool includeDescendants;

  const BumnState({
    this.future,
    this.kpi,
    this.query = '',
    this.expanded = const <String>{},
    this.selectedId,
    this.selectedNode,
    this.includeDescendants = true,
  });

  BumnState copyWith({
    Object? future = _keep,
    Object? kpi = _keep,
    String? query,
    Set<String>? expanded,
    Object? selectedId = _keep,
    Object? selectedNode = _keep,
    bool? includeDescendants,
  }) {
    return BumnState(
      future: future == _keep
          ? this.future
          : future as Future<List<BumnTreeCustomer>>?,
      kpi: kpi == _keep ? this.kpi : kpi as PartnerKpi?,
      query: query ?? this.query,
      expanded: expanded ?? this.expanded,
      selectedId: selectedId == _keep ? this.selectedId : selectedId as String?,
      selectedNode: selectedNode == _keep
          ? this.selectedNode
          : selectedNode as BumnTreeCustomer?,
      includeDescendants: includeDescendants ?? this.includeDescendants,
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
  /// `didChangeDependencies`). Mulai muat pohon BUMN + KPI global.
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
    if (q.isNotEmpty) {
      state = state.copyWith(query: q, selectedId: null, selectedNode: null);
    } else {
      state = state.copyWith(query: q);
    }
  }

  void setIncludeDescendants(bool value) =>
      state = state.copyWith(includeDescendants: value);
}
