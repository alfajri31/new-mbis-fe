import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/product_knowledge/product_knowledge_models.dart';
import '../../utils/responsive.dart';
import '../providers/product_knowledge_provider.dart';
import '../widgets/back_app_bar.dart';
import '../widgets/state_views.dart';
import 'product_detail_screen.dart';

/// S-110 — Product Knowledge (Katalog). Kartu berkategori + search + filter
/// status (Aktif / Segera Hadir). Basis konten kurasi dari
/// assets/product_knowledge.json, di-overlay produk admin dari /api/products.
class ProductKnowledgeScreen extends ConsumerStatefulWidget {
  /// Optional pre-filled search term (e.g. when opened from an AI product card).
  final String? initialQuery;

  const ProductKnowledgeScreen({super.key, this.initialQuery});

  @override
  ConsumerState<ProductKnowledgeScreen> createState() =>
      _ProductKnowledgeScreenState();
}

class _ProductKnowledgeScreenState
    extends ConsumerState<ProductKnowledgeScreen> {
  // UI-ephemeral (tetap di widget): kolom cari.
  final _searchCtrl = TextEditingController();

  // State data/filter dikelola ProductKnowledgeNotifier. Getter berikut
  // memproksinya agar kode build/widget tetap memakai nama lama tanpa diubah.
  ProductKnowledgeState get _pk => ref.read(productKnowledgeProvider);
  ProductKnowledgeNotifier get _notifier =>
      ref.read(productKnowledgeProvider.notifier);

  String get _query => _pk.query;
  String? get _categoryId => _pk.categoryId;
  StatusFilter get _status => _pk.status;
  Future<ProductKnowledge>? get _future => _pk.future;

  @override
  void initState() {
    super.initState();
    // Seed kolom cari (UI) dari query awal; seed `_query` pindah ke notifier.start.
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _searchCtrl.text = q;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Trigger loader tetap di sini (pola FutureBuilder) agar tak ada kedip 1-frame.
    // Bangun sekali (guard `future == null` di notifier) + seed query awal.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start(initialQuery: widget.initialQuery);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(PkProduct p) => _notifier.matches(p);

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(productKnowledgeProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: const BackAppBar(title: 'Product Knowledge'),
      body: FutureBuilder<ProductKnowledge>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy));
          }
          if (snap.hasError || !snap.hasData) {
            return const EmptyStateView(
              icon: Icons.error_outline,
              title: 'Gagal memuat produk',
              subtitle: 'Coba buka ulang halaman ini.',
            );
          }
          final pk = snap.data!;
          final filtered = pk.products.where(_matches).toList();
          final cats = pk.categories.where((c) => pk.productCount(c.id) > 0).toList();

          return Column(
            children: [
              _searchBar(),
              _statusChips(),
              _categoryChips(cats, pk),
              Expanded(
                child: filtered.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.inventory_2_outlined,
                        title: 'Produk tidak ditemukan',
                        subtitle: 'Ubah kata kunci atau filter.',
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: Responsive.isWide(context)
                                ? Responsive.contentMaxWidthFor(context)
                                : double.infinity,
                          ),
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
                            children: [
                              for (final c in cats)
                                if (filtered.any((p) => p.categoryId == c.id))
                                  _categorySection(c, filtered.where((p) => p.categoryId == c.id).toList()),
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _searchBar() {
    return Container(
      color: AppColors.surfaceWhite,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.sm),
      child: SizedBox(
        height: 44,
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => _notifier.setQuery(v),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Cari produk…',
            hintStyle: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.grayStage),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.grayStage),
                    onPressed: () {
                      _searchCtrl.clear();
                      _notifier.clearQuery();
                    },
                  ),
            filled: true,
            fillColor: AppColors.bgScreen,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(borderRadius: AppRadius.radiusMd, borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }

  Widget _statusChips() {
    Widget c(String label, StatusFilter v) {
      final sel = _status == v;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => _notifier.setStatus(v),
          child: Container(
            height: 30,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryNavy : AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: sel ? AppColors.primaryNavy : AppColors.border),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      );
    }

    return Container(
      color: AppColors.surfaceWhite,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
      child: Row(children: [
        c('Semua', StatusFilter.semua),
        c('Aktif', StatusFilter.aktif),
        c('Segera Hadir', StatusFilter.segeraHadir),
      ]),
    );
  }

  Widget _categoryChips(List<PkCategory> cats, ProductKnowledge pk) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(children: [
          _catChip('Semua', null, AppColors.primaryNavy),
          for (final cat in cats) ...[
            const SizedBox(width: 8),
            _catChip(cat.name, cat.id, cat.color),
          ],
        ]),
      ),
    );
  }

  Widget _catChip(String label, String? value, Color color) {
    final sel = _categoryId == value;
    return GestureDetector(
      onTap: () => _notifier.setCategory(value),
      child: Container(
        height: 30,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: sel ? color : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: sel ? color : AppColors.border),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: sel ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _categorySection(PkCategory cat, List<PkProduct> products) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: cat.color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(cat.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Text('(${products.length})', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 12),
        // Cap card width (~220) so columns grow on wide screens instead of the
        // cards ballooning — keeps a consistent, compact card size everywhere.
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            childAspectRatio: 0.95,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, i) => _productCard(products[i], cat),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _productCard(PkProduct p, PkCategory cat) {
    final faded = !p.active;
    return Opacity(
      opacity: faded ? 0.62 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
          boxShadow: const [AppShadows.level1],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.radiusLg,
          child: InkWell(
            borderRadius: AppRadius.radiusLg,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p, category: cat)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.10), borderRadius: AppRadius.radiusSm),
                    child: Icon(pkCategoryIcon(cat.icon), size: 20, color: cat.color),
                  ),
                  const SizedBox(height: 10),
                  Text(p.name,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.3)),
                  const Spacer(),
                  const SizedBox(height: 8),
                  faded
                      ? _pill('Segera Hadir', AppColors.grayStage, AppColors.grayBg)
                      : _pill('Lihat detail', cat.color, cat.color.withValues(alpha: 0.10), trailing: true),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color fg, Color bg, {bool trailing = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(50)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
        if (trailing) Icon(Icons.chevron_right, size: 13, color: fg),
      ]),
    );
  }
}
