import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/product_knowledge/product_knowledge_models.dart';

/// Filter status katalog (dulu enum privat `_StatusFilter` di layar lama).
enum StatusFilter { semua, aktif, segeraHadir }

const Object _keep = Object();

/// State layar Product Knowledge — cerminan 1:1 dari field `setState` layar lama:
/// future data/loading + filter (search / kategori / status).
class ProductKnowledgeState {
  final Future<ProductKnowledge>? future;
  final String query;
  final String? categoryId; // null = semua kategori
  final StatusFilter status;

  const ProductKnowledgeState({
    this.future,
    this.query = '',
    this.categoryId,
    this.status = StatusFilter.semua,
  });

  ProductKnowledgeState copyWith({
    Object? future = _keep,
    String? query,
    Object? categoryId = _keep,
    StatusFilter? status,
  }) {
    return ProductKnowledgeState(
      future:
          future == _keep ? this.future : future as Future<ProductKnowledge>?,
      query: query ?? this.query,
      categoryId: categoryId == _keep ? this.categoryId : categoryId as String?,
      status: status ?? this.status,
    );
  }
}

final productKnowledgeProvider =
    NotifierProvider<ProductKnowledgeNotifier, ProductKnowledgeState>(
        ProductKnowledgeNotifier.new);

/// Menggantikan logika `setState` di `_ProductKnowledgeScreenState`.
/// Perilaku (load katalog sekali, seed query awal, filter kartu) DIPINDAH APA ADANYA.
class ProductKnowledgeNotifier extends Notifier<ProductKnowledgeState> {
  @override
  ProductKnowledgeState build() => const ProductKnowledgeState();

  /// Dipanggil dari `didChangeDependencies` layar. Bangun future load SEKALI
  /// (guard `future == null`, dulu `_future ??=`) + seed query awal dari
  /// `initialQuery`. Menggantikan `initState` + `didChangeDependencies` lama.
  void start({String? initialQuery}) {
    if (state.future != null) return;
    final q = initialQuery?.trim() ?? '';
    state = state.copyWith(
      query: q,
      future: ProductKnowledgeRepository.instance
          .load(ref.read(masterDataRepoProvider)),
    );
  }

  /// Search field (dulu `setState(() => _query = v)`).
  void setQuery(String value) => state = state.copyWith(query: value);

  /// Tombol clear pada search field (dulu `setState(() => _query = '')`).
  void clearQuery() => state = state.copyWith(query: '');

  /// Chip status (dulu `setState(() => _status = v)`).
  void setStatus(StatusFilter value) => state = state.copyWith(status: value);

  /// Chip kategori (dulu `setState(() => _categoryId = value)`).
  void setCategory(String? value) => state = state.copyWith(categoryId: value);

  /// Filter kartu — logika `_matches` layar lama, dipindah apa adanya.
  bool matches(PkProduct p) {
    if (state.categoryId != null && p.categoryId != state.categoryId) {
      return false;
    }
    if (state.status == StatusFilter.aktif && !p.active) return false;
    if (state.status == StatusFilter.segeraHadir && p.active) return false;
    if (state.query.isNotEmpty &&
        !p.name.toLowerCase().contains(state.query.toLowerCase())) {
      return false;
    }
    return true;
  }
}
