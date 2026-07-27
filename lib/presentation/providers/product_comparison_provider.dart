import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mbis/core/providers/repository_providers.dart';
import 'package:mbis/src/product_knowledge/product_knowledge_models.dart';

/// Katalog Product Knowledge yang dimuat async untuk layar Bandingkan Produk.
/// Menggantikan field `ProductKnowledge? _pk` yang dulu di-`setState` di
/// `_ProductComparisonScreenState`. Nilai `null` = masih memuat (spinner).
///
/// PERILAKU DIPERTAHANKAN (behavior-preserving):
///  - Dibuat `autoDispose` agar tiap kali layar dibuka, katalog dimuat ulang
///    dari awal — persis seperti `_pk` yang selalu mulai `null` di tiap instance
///    layar lama. Pemicu tetap dari `didChangeDependencies` layar (guard `!= null`,
///    padanan `if (_pk != null) return`), sesuai timing lama.
///  - Sumber data TAK berubah: singleton `ProductKnowledgeRepository.instance`.
///    Yang berubah hanya cara `MasterDataRepository` didapat: dari
///    [masterDataRepoProvider] (yang membawa sesi aktif via apiClient),
///    menggantikan pembuatan manual
///    `MasterDataRepository(apiClient: ApiClient(session: MbisApp.of(context)?.session))`.
///
/// State SELEKSI produk untuk dibandingkan TIDAK ikut ke sini — itu UI-ephemeral
/// dan tetap `setState` di widget, sesuai aturan migrasi (hanya data/loading).
final productComparisonProvider =
    NotifierProvider.autoDispose<ProductComparisonNotifier, ProductKnowledge?>(
        ProductComparisonNotifier.new);

class ProductComparisonNotifier extends Notifier<ProductKnowledge?> {
  @override
  ProductKnowledge? build() => null;

  /// Muat katalog sekali. Dipanggil layar dari `didChangeDependencies`, yang
  /// menjaga guard `state == null` (padanan `if (_pk != null) return`).
  Future<void> load() async {
    final pk = await ProductKnowledgeRepository.instance
        .load(ref.read(masterDataRepoProvider));
    if (!ref.mounted) return; // padanan `if (mounted)` di layar lama
    state = pk;
  }
}
