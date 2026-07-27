import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/product_knowledge/product_knowledge_models.dart';
import '../providers/product_comparison_provider.dart';
import '../widgets/back_app_bar.dart';

/// Perbandingan produk side-by-side (maks 3). Membandingkan quickFacts +
/// atribut kunci. Dipanggil dari Detail Produk via "Bandingkan".
class ProductComparisonScreen extends ConsumerStatefulWidget {
  final PkProduct initial;
  const ProductComparisonScreen({super.key, required this.initial});

  @override
  ConsumerState<ProductComparisonScreen> createState() => _ProductComparisonScreenState();
}

class _ProductComparisonScreenState extends ConsumerState<ProductComparisonScreen> {
  static const int _maxCols = 3;

  // UI-ephemeral (tetap di widget): produk yang dipilih untuk dibandingkan.
  final List<PkProduct> _selected = [];

  // Katalog (data async) dikelola ProductComparisonNotifier. Getter memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai `_pk` tanpa diubah.
  ProductKnowledge? get _pk => ref.read(productComparisonProvider);

  @override
  void initState() {
    super.initState();
    _selected.add(widget.initial);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Loader jenis didChangeDependencies dipertahankan di sini (guard sekali,
    // padanan `if (_pk != null) return`). Pemuatan + sesi kini ditangani notifier
    // lewat masterDataRepoProvider — tak perlu MbisApp/ApiClient di layar.
    if (ref.read(productComparisonProvider) != null) return; // sekali saja
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(productComparisonProvider.notifier).load();
    });
  }

  // Baris perbandingan: label + cara ambil nilainya dari produk.
  late final List<({String label, String Function(PkProduct) get})> _rows = [
    (label: 'Kategori', get: (p) => _pk?.categoryOf(p).name ?? '-'),
    (label: 'Premi', get: (p) => p.quickFacts['premi'] ?? '-'),
    (label: 'Masa Pertanggungan', get: (p) => p.quickFacts['masaPertanggungan'] ?? '-'),
    (label: 'Nilai Pertanggungan', get: (p) => p.quickFacts['nilaiPertanggungan'] ?? '-'),
    (label: 'Jml. Pengecualian', get: (p) => p.sectionList('pengecualian').isEmpty ? '-' : '${p.sectionList('pengecualian').length}'),
  ];

  @override
  Widget build(BuildContext context) {
    // Berlangganan katalog → rebuild otomatis saat data tiba (ganti setState).
    ref.watch(productComparisonProvider);
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: const BackAppBar(title: 'Bandingkan Produk'),
      body: _pk == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryNavy))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _table(),
              ),
            ),
    );
  }

  Widget _table() {
    const labelW = 130.0, colW = 160.0;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // header: nama produk
        Row(children: [
          const SizedBox(width: labelW),
          for (final p in _selected) SizedBox(width: colW, child: _headerCell(p)),
          if (_selected.length < _maxCols) SizedBox(width: colW, child: _addCell()),
        ]),
        const Divider(height: 1, color: AppColors.border),
        // baris atribut
        for (var i = 0; i < _rows.length; i++)
          Container(
            color: i.isEven ? AppColors.bgScreen.withValues(alpha: 0.5) : null,
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: labelW,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Text(_rows[i].label,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                ),
              ),
              for (final p in _selected)
                SizedBox(
                  width: colW,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Text(_rows[i].get(p),
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.35)),
                  ),
                ),
            ]),
            ),
          ),
      ]),
    );
  }

  Widget _headerCell(PkProduct p) {
    final cat = _pk!.categoryOf(p);
    final removable = _selected.length > 1;
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle)),
          const Spacer(),
          if (removable)
            GestureDetector(
              onTap: () => setState(() => _selected.remove(p)),
              child: const Icon(Icons.close, size: 16, color: AppColors.grayStage),
            ),
        ]),
        const SizedBox(height: 6),
        Text(p.name, maxLines: 3, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.25)),
      ]),
    );
  }

  Widget _addCell() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: OutlinedButton.icon(
        onPressed: _pickProduct,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Tambah'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryNavy,
          side: const BorderSide(color: AppColors.primaryNavy, width: 1.4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
        ),
      ),
    );
  }

  void _pickProduct() {
    final pk = _pk!;
    final selectedIds = _selected.map((e) => e.id).toSet();
    final candidates = pk.products.where((p) => p.active && !selectedIds.contains(p.id)).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Align(alignment: Alignment.centerLeft, child: Text('Pilih produk untuk dibandingkan',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in candidates)
                  ListTile(
                    leading: Icon(pkCategoryIcon(pk.categoryOf(p).icon), color: pk.categoryOf(p).color),
                    title: Text(p.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text(pk.categoryOf(p).name, style: const TextStyle(fontSize: 12)),
                    onTap: () {
                      setState(() => _selected.add(p));
                      Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
