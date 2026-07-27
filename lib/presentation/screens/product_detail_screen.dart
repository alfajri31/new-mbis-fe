import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../src/product_knowledge/product_knowledge_models.dart';
import '../widgets/back_app_bar.dart';
import 'product_comparison_screen.dart';

/// S-110b — Detail Produk (pola kartu section accordion).
/// Strip "Sekilas" + kartu section collapse; teks legal tersembunyi sampai di-tap.
class ProductDetailScreen extends StatefulWidget {
  final PkProduct product;
  final PkCategory category;
  const ProductDetailScreen({super.key, required this.product, required this.category});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  PkProduct get p => widget.product;
  PkCategory get cat => widget.category;

  // Urutan & tipe render tiap section.
  // Premi/Masa/Nilai TIDAK di sini — sudah ringkas di strip "Sekilas" (hindari duplikasi).
  static const List<List<dynamic>> _order = [
    ['deskripsi', 'Deskripsi', Icons.info_outline, 'text'],
    ['jenis', 'Jenis Produk', Icons.category_outlined, 'text'],
    ['manfaat', 'Manfaat', Icons.verified_outlined, 'text'],
    ['biaya', 'Biaya', Icons.receipt_long_outlined, 'text'],
    ['skemaPembayaran', 'Skema Pembayaran Premi', Icons.account_balance_wallet_outlined, 'text'],
    ['pengecualian', 'Pengecualian', Icons.warning_amber_rounded, 'exclusions'],
    ['persyaratan', 'Persyaratan Penutupan', Icons.checklist_rtl, 'checklist'],
    ['tataCara', 'Tata Cara Penutupan', Icons.timeline_outlined, 'timeline'],
    ['persyaratanKlaim', 'Persyaratan Klaim', Icons.fact_check_outlined, 'checklist'],
    ['tataCaraKlaim', 'Tata Cara Klaim', Icons.timeline_outlined, 'timeline'],
    ['risiko', 'Risiko', Icons.report_problem_outlined, 'text'],
    ['simulasi', 'Contoh Simulasi', Icons.calculate_outlined, 'text'],
  ];

  @override
  Widget build(BuildContext context) {
    // Sumber data tunggal: tampilkan setiap section yang tersedia di JSON.
    final sections = _order.where((s) => p.hasSection(s[0] as String)).toList();
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: BackAppBar(
        title: 'Detail Produk',
        actions: p.active
            ? [
                IconButton(
                  tooltip: 'Bandingkan',
                  icon: const Icon(Icons.compare_arrows, color: AppColors.primaryNavy),
                  onPressed: _openComparison,
                )
              ]
            : const [],
      ),
      // Cap + centre so the reading content doesn't stretch edge-to-edge on desktop.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 32),
        children: [
          _hero(),
          const SizedBox(height: AppSpacing.lg),
          if (!p.active) _maintenanceBanner(),
          if (p.cleanQuickFacts().isNotEmpty) ...[
            _sekilasStrip(),
            const SizedBox(height: AppSpacing.lg),
          ],
          for (final s in sections) ...[
            _SectionCard(
              title: s[1] as String,
              icon: s[2] as IconData,
              accent: cat.color,
              badge: _badgeFor(s[0] as String, s[3] as String),
              child: _sectionBody(s[0] as String, s[3] as String),
            ),
            const SizedBox(height: 10),
          ],
          if (p.skemaUrl != null) ...[
            const SizedBox(height: 2),
            _skemaButton(),
          ],
        ],
      ),
        ),
      ),
    );
  }

  String? _badgeFor(String key, String type) {
    if (type == 'exclusions' || type == 'checklist' || type == 'timeline') {
      final n = p.sectionList(key).length;
      if (n > 0) return type == 'timeline' ? '$n langkah' : '$n';
    }
    return null;
  }

  // ---------- Hero ----------
  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radius2Xl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.10), borderRadius: AppRadius.radiusLg),
          child: Icon(pkCategoryIcon(cat.icon), color: cat.color, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.25)),
            const SizedBox(height: 6),
            Row(children: [
              _tag(cat.name, cat.color),
              const SizedBox(width: 6),
              if (!p.active) _tag('Segera Hadir', AppColors.grayStage),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _tag(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(50)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );

  Widget _maintenanceBanner() => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.orangeLight,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.secondaryOrange.withValues(alpha: 0.3)),
        ),
        child: Row(children: const [
          Icon(Icons.construction, size: 18, color: AppColors.secondaryOrange),
          SizedBox(width: 10),
          Expanded(
            child: Text('Produk ini masih dalam penyiapan (Segera Hadir). Sebagian informasi belum tersedia.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.4)),
          ),
        ]),
      );

  // ---------- Strip Sekilas ----------
  Widget _sekilasStrip() {
    final qf = p.cleanQuickFacts();
    final items = <List<String>>[
      if (qf['premi'] != null) ['Premi', qf['premi']!],
      if (qf['masa'] != null) ['Masa', qf['masa']!],
      if (qf['nilai'] != null) ['Nilai', qf['nilai']!],
    ];
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _factTile(items[i][0], items[i][1])),
          ],
        ],
      ),
    );
  }

  Widget _factTile(String label, String value) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
          boxShadow: const [AppShadows.level1],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(value, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cat.color, height: 1.25)),
        ]),
      );

  // ---------- Section bodies ----------
  Widget _sectionBody(String key, String type) {
    switch (type) {
      case 'exclusions':
        return _exclusions(p.sectionList(key));
      case 'checklist':
        return _Checklist(items: p.sectionList(key), accent: cat.color);
      case 'timeline':
        return _timeline(p.sectionList(key));
      case 'text':
      default:
        // Jenis Produk → kartu per-jenis (tap untuk detail) bila berupa array objek.
        if (key == 'jenis' && p.jenisCards().isNotEmpty) {
          return _JenisCards(items: p.jenisCards(), accent: cat.color);
        }
        // Section berupa array string dirender sebagai bullet; prosa → markdown ringan.
        final bullets = p.sectionList(key);
        final Widget body = bullets.isNotEmpty
            ? _Bullets(items: bullets, accent: cat.color)
            : MdLite(
                text: p.sectionText(key) ?? '',
                baseColor: AppColors.textPrimary,
                fontSize: 13.5,
              );
        final children = <Widget>[body];
        if (key == 'deskripsi') {
          final chips = _glossaryChips(p.sectionText(key) ?? '');
          if (chips.isNotEmpty) {
            children.add(const SizedBox(height: 12));
            children.add(Wrap(spacing: 6, runSpacing: 6, children: chips));
          }
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
    }
  }

  Widget _exclusions(List<String> items) => Column(
        children: [
          for (final e in items)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.redLight, borderRadius: AppRadius.radiusSm),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.errorRed),
                const SizedBox(width: 8),
                Expanded(child: MdLite(text: e, baseColor: AppColors.textPrimary, fontSize: 13)),
              ]),
            ),
        ],
      );

  Widget _timeline(List<String> steps) => Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Column(children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  if (i != steps.length - 1)
                    Expanded(child: Container(width: 2, color: cat.color.withValues(alpha: 0.25))),
                ]),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14, top: 2),
                    child: MdLite(text: steps[i], baseColor: AppColors.textPrimary, fontSize: 13),
                  ),
                ),
              ]),
            ),
        ],
      );

  // glossary istilah penjaminan/asuransi
  static const Map<String, String> _glossary = {
    'Principal': 'Pihak yang dijamin (mis. kontraktor) yang wajib memenuhi kewajiban dalam Perjanjian Pokok.',
    'Obligee': 'Pemilik proyek / penerima jaminan yang dilindungi bila Principal wanprestasi.',
    'Bouwheer': 'Istilah lain untuk Obligee / pemberi kerja.',
    'Tertanggung': 'Pihak yang mengalihkan risiko dan dilindungi oleh polis.',
    'Penanggung': 'Perusahaan asuransi/penjamin (Askrindo) yang menanggung risiko.',
    'Credit Limit': 'Batas maksimum outstanding kredit yang dijamin per Pembeli.',
  };

  List<Widget> _glossaryChips(String text) {
    final found = _glossary.keys.where((k) => text.toLowerCase().contains(k.toLowerCase())).toList();
    return [
      for (final term in found)
        ActionChip(
          label: Text(term, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cat.color)),
          backgroundColor: cat.color.withValues(alpha: 0.08),
          side: BorderSide(color: cat.color.withValues(alpha: 0.25)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          onPressed: () => _showGlossary(term, _glossary[term]!),
        ),
    ];
  }

  void _showGlossary(String term, String def) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        // Layar landscape sangat pendek: tanpa ini isi dialog yang lebih
        // tinggi dari layar meluber (overflow) alih-alih bisa digulung.
        scrollable: true,
        title: Text(term, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(def, style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
      ),
    );
  }

  // ---------- skema + CTA ----------
  Widget _skemaButton() => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _comingSoon,
          icon: const Icon(Icons.schema_outlined, size: 18),
          label: const Text('Lihat Skema Produk'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryNavy,
            side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
          ),
        ),
      );

  void _openComparison() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductComparisonScreen(initial: p)),
      );

  void _comingSoon() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fitur ini segera hadir.'), behavior: SnackBarBehavior.floating),
      );
}

// ============ Reusable widgets ============

/// Kartu section yang bisa collapse: ikon + judul + badge jumlah + chevron.
class _SectionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color accent;
  final String? badge;
  final Widget child;
  const _SectionCard({required this.title, required this.icon, required this.accent, required this.child, this.badge});

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(widget.icon, size: 20, color: widget.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              if (widget.badge != null)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: widget.accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(50)),
                  child: Text(widget.badge!,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: widget.accent)),
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

/// Checklist interaktif dengan counter (untuk Persyaratan).
class _Checklist extends StatefulWidget {
  final List<String> items;
  final Color accent;
  const _Checklist({required this.items, required this.accent});

  @override
  State<_Checklist> createState() => _ChecklistState();
}

class _ChecklistState extends State<_Checklist> {
  final Set<int> _done = {};

  @override
  Widget build(BuildContext context) {
    final total = widget.items.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('${_done.length}/$total disiapkan',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.accent)),
      ),
      for (var i = 0; i < total; i++)
        InkWell(
          borderRadius: AppRadius.radiusSm,
          onTap: () => setState(() => _done.contains(i) ? _done.remove(i) : _done.add(i)),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(_done.contains(i) ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20, color: _done.contains(i) ? widget.accent : AppColors.grayStage),
              const SizedBox(width: 10),
              Expanded(
                child: MdLite(
                  text: widget.items[i],
                  baseColor: _done.contains(i) ? AppColors.textSecondary : AppColors.textPrimary,
                  fontSize: 13,
                  strike: _done.contains(i),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Renderer markdown ringan: mendukung **bold**, menjaga newline. (Tanpa dependency.)
class MdLite extends StatelessWidget {
  final String text;
  final Color baseColor;
  final double fontSize;
  final bool strike;
  final int? maxLines;
  const MdLite({super.key, required this.text, required this.baseColor, this.fontSize = 14, this.strike = false, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      color: baseColor,
      height: 1.5,
      decoration: strike ? TextDecoration.lineThrough : null,
    );
    final spans = <TextSpan>[];
    final parts = text.replaceAll('*Italic*', '').split('**');
    for (var i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: i.isOdd ? base.copyWith(fontWeight: FontWeight.w700) : base,
      ));
    }
    return RichText(
      text: TextSpan(children: spans, style: base),
      maxLines: maxLines,
      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
    );
  }
}

/// Poin-poin (bullet) rapi, dengan jarak antar poin agar mudah dibaca.
class _Bullets extends StatelessWidget {
  final List<String> items;
  final Color accent;
  const _Bullets({required this.items, required this.accent});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final b in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 6, right: 10),
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            Expanded(child: MdLite(text: b, baseColor: AppColors.textPrimary, fontSize: 13.5)),
          ]),
        ),
    ]);
  }
}

/// Daftar "jenis" sebagai kartu; tap kartu → detail muncul (accordion bertingkat).
class _JenisCards extends StatelessWidget {
  final List<({String title, String detail})> items;
  final Color accent;
  const _JenisCards({required this.items, required this.accent});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final it in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _MiniExpandable(title: it.title, detail: it.detail, accent: accent),
        ),
    ]);
  }
}

class _MiniExpandable extends StatefulWidget {
  final String title;
  final String detail;
  final Color accent;
  const _MiniExpandable({required this.title, required this.detail, required this.accent});
  @override
  State<_MiniExpandable> createState() => _MiniExpandableState();
}

class _MiniExpandableState extends State<_MiniExpandable> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgScreen,
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: AppRadius.radiusSm,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.accent, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 150),
                child: Icon(Icons.keyboard_arrow_down, size: 18, color: widget.accent),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 12, 11),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MdLite(text: widget.detail, baseColor: AppColors.textSecondary, fontSize: 12.5),
            ),
          ),
          crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 150),
        ),
      ]),
    );
  }
}
