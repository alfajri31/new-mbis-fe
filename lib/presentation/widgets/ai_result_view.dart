import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../src/app.dart';
import '../../src/network/api_client.dart';
import '../../src/master_data/master_data_repository.dart';
import '../../src/assistant/assistant_repository.dart';
import '../../src/product_knowledge/product_knowledge_models.dart';
import '../screens/product_knowledge_screen.dart';
import '../screens/product_detail_screen.dart';

/// Renders a standardized AI result as **separate collapsible section cards**
/// (icon + heading + chevron, like the Product Knowledge detail), so a long answer
/// is broken into readable parts instead of one block. Reused on the run/result
/// screen and the saved-result viewer.
///
/// Text is sanitized at render time (markdown stars/hashes/bullets stripped) so even
/// older saved results read cleanly without re-generating them.
class AiResultView extends StatelessWidget {
  final AiStructuredResult result;
  final List<AiSource> sources;

  const AiResultView({super.key, required this.result, this.sources = const []});

  @override
  Widget build(BuildContext context) {
    final recos = result.recommendations.where((r) => r.produk.trim().isNotEmpty).toList();
    var sections = result.sections
        // Section tanpa satu pun item yang tersisa setelah dibersihkan hanya menghasilkan kartu
        // kosong berisi "—" (dan tanpa badge angka). Model kerap menulis heading lalu menaruh
        // isinya di tempat lain, jadi headingnya menggantung sendirian.
        .where((s) => s.items.any((t) => _clean(t).isNotEmpty))
        .where((s) => !_isRingkasan(s.heading))
        // Prompt sudah meminta model menaruh produk HANYA di 'recommendations', tetapi itu
        // permintaan tanpa penegakan: model tetap sering menulis ulang daftarnya sebagai section,
        // lalu kartu "Rekomendasi Produk" di bawah menampilkannya untuk KEDUA kalinya. Disaring
        // di sisi render supaya hasil LAMA yang tersimpan ikut tertolong tanpa dijalankan ulang.
        .where((s) => !(recos.isNotEmpty && _isProductHeading(s.heading)))
        .toList();

    // Safety net: never render a blank screen. If filtering (e.g. dropping a stray "Ringkasan")
    // removed everything and there is nothing else to show, fall back to the raw sections that
    // still carry content — better an unpolished answer than an empty white screen.
    if (sections.isEmpty && recos.isEmpty && sources.isEmpty) {
      sections = result.sections
          .where((s) => s.heading.isNotEmpty || s.items.isNotEmpty)
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_clean(result.judul ?? '').isNotEmpty) ...[
          Text(_clean(result.judul!),
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.3)),
          const SizedBox(height: 12),
        ],
        for (final s in sections) ...[
          _AiSectionCard(
            icon: _iconFor(s.heading),
            heading: _clean(s.heading).isEmpty ? 'Bagian' : _clean(s.heading),
            count: s.items.length,
            child: _bullets(s.items),
          ),
          const SizedBox(height: 10),
        ],
        if (recos.isNotEmpty) ...[
          _AiSectionCard(
            icon: Icons.shield_outlined,
            heading: 'Rekomendasi Produk',
            count: recos.length,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final r in recos) ...[
                  _ProductRecoCard(reco: r),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (sources.isNotEmpty)
          _AiSectionCard(
            icon: Icons.link,
            heading: 'Sumber',
            count: sources.length,
            initiallyOpen: false,
            child: _sourceList(),
          ),
      ],
    );
  }

  /// Defensive: hide a stray "Ringkasan" heading (we now ask the model not to emit one,
  /// but older saved results may still have it).
  static bool _isRingkasan(String heading) => _clean(heading).toLowerCase() == 'ringkasan';

  /// True bila heading ini adalah daftar rekomendasi produk yang ditulis ulang oleh model
  /// (mis. "Rekomendasi Produk Askrindo", "Produk yang Direkomendasikan"). KEDUA kata wajib ada
  /// supaya bagian yang sah seperti "Langkah Rekomendasi" atau "Produk Existing" tetap tampil.
  static bool _isProductHeading(String heading) {
    final h = _clean(heading).toLowerCase();
    return h.contains('rekomendasi') && h.contains('produk');
  }

  /// Strips leftover markdown decoration the model sometimes emits inside item text:
  /// leading `#`, list bullets, `*`/`**` emphasis, stray backticks, and Gemini's inline
  /// `<cite index="n">...</cite>` grounding markup (tags only — the wrapped text is kept).
  /// The backend now strips `<cite>` for new results (GeminiClient.stripCiteTags), but this
  /// also cleans up older saved results that already have it baked into their stored JSON.
  static String _clean(String s) {
    var t = s.trim();
    t = t.replaceFirst(RegExp(r'^#+\s*'), '');
    t = t.replaceFirst(RegExp(r'^[-*•]\s+'), '');
    t = t.replaceAll('*', '');
    t = t.replaceAll('`', '');
    t = t.replaceAll(RegExp(r'</?cite\b[^>]*>', caseSensitive: false), '');
    return t.trim();
  }

  static IconData _iconFor(String heading) {
    final h = heading.toLowerCase();
    if (h.contains('profil') || h.contains('perusahaan') || h.contains('tentang')) return Icons.business_outlined;
    if (h.contains('kebutuhan')) return Icons.checklist_rtl;
    if (h.contains('produk') || h.contains('rekomendasi')) return Icons.shield_outlined;
    if (h.contains('talking') || h.contains('pendekatan') || h.contains('pitch')) return Icons.chat_bubble_outline;
    if (h.contains('langkah') || h.contains('tindak') || h.contains('follow') || h.contains('lanjut')) return Icons.flag_outlined;
    if (h.contains('risiko') || h.contains('keberatan')) return Icons.warning_amber_rounded;
    if (h.contains('tender') || h.contains('proyek')) return Icons.assignment_outlined;
    if (h.contains('skala') || h.contains('ukuran')) return Icons.straighten;
    return Icons.info_outline;
  }

  Widget _bullets(List<String> items) {
    final cleaned = items.map(_clean).where((t) => t.isNotEmpty).toList();
    if (cleaned.isEmpty) {
      return const Text('—', style: TextStyle(fontSize: 13, color: AppColors.textSecondary));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in cleaned)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 6, right: 10),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: AppColors.secondaryOrange, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(item,
                    style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textPrimary)),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _sourceList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Tautan dari pencarian web — verifikasi sebelum digunakan.',
            style: TextStyle(
                fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
          ),
        ),
        for (final s in sources)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (s.judul.isNotEmpty)
                Text(_clean(s.judul),
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              SelectableText(s.url,
                  style: const TextStyle(fontSize: 11, color: AppColors.primaryNavyLight)),
            ]),
          ),
      ],
    );
  }
}

/// A small expandable card for one AI product recommendation: shows the product name,
/// expands to reveal the reason + a button that deep-searches Product Knowledge.
class _ProductRecoCard extends StatefulWidget {
  final AiRecommendation reco;
  const _ProductRecoCard({required this.reco});

  @override
  State<_ProductRecoCard> createState() => _ProductRecoCardState();
}

class _ProductRecoCardState extends State<_ProductRecoCard> {
  bool _open = false;
  bool _loading = false;

  /// Deep-link to the exact product's detail page (where "Jenis Produk" lives) when the
  /// recommendation carries a resolved [productId]; otherwise fall back to a name search.
  Future<void> _openDetail() async {
    final reco = widget.reco;
    if (reco.productId == null) {
      _openSearch();
      return;
    }
    setState(() => _loading = true);
    try {
      final pk = await ProductKnowledgeRepository.instance.load(
        MasterDataRepository(apiClient: ApiClient(session: MbisApp.of(context)?.session)),
      );
      PkProduct? found;
      for (final p in pk.products) {
        if (p.id == reco.productId) {
          found = p;
          break;
        }
      }
      if (!mounted) return;
      setState(() => _loading = false);
      if (found != null) {
        final product = found;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product, category: pk.categoryOf(product)),
          ),
        );
      } else {
        _openSearch();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _openSearch();
    }
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductKnowledgeScreen(initialQuery: widget.reco.produk),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alasan = AiResultView._clean(widget.reco.alasan);
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: AppRadius.radiusMd,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              const Icon(Icons.verified_outlined, size: 18, color: AppColors.primaryNavy),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AiResultView._clean(widget.reco.produk),
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.3)),
                    if (widget.reco.jenis.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('Jenis: ${AiResultView._clean(widget.reco.jenis)}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryNavyLight)),
                    ],
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.grayStage),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 11),
            // Align melebar memenuhi kartu lalu menempelkan isinya ke tepi kiri. Tanpa ini
            // AnimatedCrossFade menyusut selebar isinya, dan Column pembungkus di atas (yang
            // crossAxisAlignment bawaannya center) menaruhnya di TENGAH kartu — sehingga tepi
            // kiri alasan & tombol bergeser mengikuti panjang teks dan antar-produk tidak
            // sejajar. Pola yang sama sudah dipakai _AiSectionCard di bawah.
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (alasan.isNotEmpty)
                Text(alasan,
                    style: const TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary)),
              if (alasan.isNotEmpty) const SizedBox(height: 10),
              InkWell(
                borderRadius: BorderRadius.circular(50),
                onTap: _loading ? null : _openDetail,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.navyBg,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_loading)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryNavy),
                      )
                    else
                      const Icon(Icons.menu_book_outlined, size: 15, color: AppColors.primaryNavy),
                    const SizedBox(width: 6),
                    const Text('Lihat detail produk',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryNavy)),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.primaryNavy),
                  ]),
                ),
                ),
              ]),
            ),
          ),
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ]),
    );
  }
}

/// Collapsible card with an icon header + count badge + chevron (default expanded).
class _AiSectionCard extends StatefulWidget {
  final IconData icon;
  final String heading;
  final int count;
  final bool initiallyOpen;
  final Widget child;

  const _AiSectionCard({
    required this.icon,
    required this.heading,
    required this.count,
    required this.child,
    this.initiallyOpen = true,
  });

  @override
  State<_AiSectionCard> createState() => _AiSectionCardState();
}

class _AiSectionCardState extends State<_AiSectionCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(children: [
        InkWell(
          borderRadius: AppRadius.radiusLg,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(widget.icon, size: 20, color: AppColors.primaryNavy),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.heading,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              if (widget.count > 0)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppColors.navyBg, borderRadius: BorderRadius.circular(50)),
                  child: Text('${widget.count}',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryNavy)),
                ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.keyboard_arrow_down, color: AppColors.grayStage),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Align(alignment: Alignment.centerLeft, child: widget.child),
          ),
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
      ]),
    );
  }
}
