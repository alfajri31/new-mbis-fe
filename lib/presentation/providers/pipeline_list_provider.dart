import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../src/pipeline/pipeline_repository.dart';

class PipelineListState {
  final bool isLoading;
  final String? error;
  final List<PipelineListModel> allItems;
  final String searchTerm;
  final String stage; // '' = Semua, 'P3', 'P2', 'P1', 'WON', 'DECLINE'
  final String prod; // '' = Semua, 'psakdi', 'paxtra', 'other'
  final String src; // '' = Semua, 'cust', 'bumn'
  final String mine; // '' = Semua, 'me'
  final String sort; // 'new', 'pot'
  final String? currentUserName;

  const PipelineListState({
    this.isLoading = false,
    this.error,
    this.allItems = const [],
    this.searchTerm = '',
    this.stage = '',
    this.prod = '',
    this.src = '',
    this.mine = '',
    this.sort = 'new',
    this.currentUserName,
  });

  PipelineListState copyWith({
    bool? isLoading,
    String? Function()? error,
    List<PipelineListModel>? allItems,
    String? searchTerm,
    String? stage,
    String? prod,
    String? src,
    String? mine,
    String? sort,
    String? currentUserName,
  }) {
    return PipelineListState(
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
      allItems: allItems ?? this.allItems,
      searchTerm: searchTerm ?? this.searchTerm,
      stage: stage ?? this.stage,
      prod: prod ?? this.prod,
      src: src ?? this.src,
      mine: mine ?? this.mine,
      sort: sort ?? this.sort,
      currentUserName: currentUserName ?? this.currentUserName,
    );
  }

  bool get hasActiveFilter =>
      prod.isNotEmpty || src.isNotEmpty || mine.isNotEmpty || sort != 'new';

  /// Saringan awal berdasarkan pencarian dan dropdown (sebelum saringan tahap/stage).
  /// Dipakai untuk menghitung jumlah item pada chip tahap.
  List<PipelineListModel> get baseItems {
    final q = searchTerm.trim().toLowerCase();
    return allItems.where((p) {
      // 1. Search query
      if (q.isNotEmpty) {
        final name = (p.projectName ?? p.product ?? '').toLowerCase();
        final cust = p.customerName.toLowerCase();
        final bumn = (p.bumnName ?? '').toLowerCase();
        if (!name.contains(q) && !cust.contains(q) && !bumn.contains(q)) {
          return false;
        }
      }

      // 2. Produk filter
      if (prod.isNotEmpty) {
        final pr = (p.product ?? '').toLowerCase();
        if (prod == 'psakdi') {
          if (!pr.contains('psakdi')) return false;
        } else if (prod == 'paxtra') {
          if (!pr.contains('pa') && !pr.contains('xtra')) return false;
        } else if (prod == 'other') {
          if (pr.contains('psakdi') || pr.contains('pa') || pr.contains('xtra')) {
            return false;
          }
        }
      }

      // 3. Sumber filter
      if (src.isNotEmpty) {
        final isBumn = p.isBumn ||
            (p.sourceType ?? '').toLowerCase().contains('bumn') ||
            (p.bumnName != null && p.bumnName!.isNotEmpty);
        if (src == 'bumn' && !isBumn) return false;
        if (src == 'cust' && isBumn) return false;
      }

      // 4. Pengelola (milik saya)
      if (mine == 'me') {
        if (currentUserName != null && currentUserName!.isNotEmpty) {
          final rm = (p.rmName ?? '').toLowerCase();
          if (!rm.contains(currentUserName!.toLowerCase())) return false;
        }
      }

      return true;
    }).toList();
  }

  /// Menghitung jumlah pipeline per tahap pada saringan saat ini.
  Map<String, int> get stageCounts {
    final counts = <String, int>{
      '': baseItems.length,
      'P3': 0,
      'P2': 0,
      'P1': 0,
      'WON': 0,
      'DECLINE': 0,
    };
    for (final p in baseItems) {
      final s = p.stage.toUpperCase();
      if (counts.containsKey(s)) {
        counts[s] = counts[s]! + 1;
      }
    }
    return counts;
  }

  /// Hasil akhir setelah saringan tahap dan pengurutan.
  List<PipelineListModel> get filteredItems {
    var list = baseItems;
    if (stage.isNotEmpty) {
      list = list.where((p) => p.stage.toUpperCase() == stage.toUpperCase()).toList();
    }

    if (sort == 'pot') {
      list.sort((a, b) => (b.potensiPremi ?? b.premi ?? 0)
          .compareTo(a.potensiPremi ?? a.premi ?? 0));
    } else {
      // sort == 'new'
      list.sort((a, b) {
        final da = a.createdAt ?? a.closingEstimasi ?? '';
        final db = b.createdAt ?? b.closingEstimasi ?? '';
        return db.compareTo(da);
      });
    }

    return list;
  }

  double get totalPotensi {
    return filteredItems.fold(
      0.0,
      (sum, p) => sum + (p.potensiPremi ?? p.premi ?? 0),
    );
  }
}

class PipelineListNotifier extends Notifier<PipelineListState> {
  @override
  PipelineListState build() {
    final session = ref.watch(sessionProvider);
    final userName = session?.user.name;
    Future.microtask(() => fetchPipelines());
    return PipelineListState(currentUserName: userName);
  }

  PipelineRepository get _pipelineRepo => ref.read(pipelineRepoProvider);

  Future<void> fetchPipelines() async {
    state = state.copyWith(isLoading: true, error: () => null);
    try {
      final items = await _pipelineRepo.getPipelines();
      state = state.copyWith(
        isLoading: false,
        allItems: items,
        error: () => null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void setSearch(String q) {
    state = state.copyWith(searchTerm: q);
  }

  void setStage(String stage) {
    state = state.copyWith(stage: stage);
  }

  void setProd(String prod) {
    state = state.copyWith(prod: prod);
  }

  void setSrc(String src) {
    state = state.copyWith(src: src);
  }

  void setMine(String mine) {
    state = state.copyWith(mine: mine);
  }

  void setSort(String sort) {
    state = state.copyWith(sort: sort);
  }

  void resetFilters() {
    state = state.copyWith(
      searchTerm: '',
      stage: '',
      prod: '',
      src: '',
      mine: '',
      sort: 'new',
    );
  }
}

final pipelineListProvider =
    NotifierProvider<PipelineListNotifier, PipelineListState>(PipelineListNotifier.new);
