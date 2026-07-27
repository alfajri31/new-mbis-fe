import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/bumn/bumn_repository.dart';
import '../providers/bumn_tree_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/state_views.dart';

/// Ekosistem BUMN — pohon master_bumn (Induk → Anak → Cucu → Cicit) yang
/// dibangun dari adjacency list di backend (GET /api/bumns/tree). Read-only:
/// node bisa di-expand untuk telusuri turunannya; kotak cari memfilter lintas
/// level (mode datar saat ada query).
class BumnTreeScreen extends ConsumerStatefulWidget {
  const BumnTreeScreen({super.key});

  @override
  ConsumerState<BumnTreeScreen> createState() => _BumnTreeScreenState();
}

class _BumnTreeScreenState extends ConsumerState<BumnTreeScreen> {
  // UI-ephemeral (tetap di widget): kolom cari.
  final TextEditingController _searchController = TextEditingController();

  // State DATA/LOADING/search dikelola BumnTreeNotifier. Getter berikut
  // memproksinya agar seluruh kode build/widget di bawah tetap memakai nama
  // lama tanpa diubah.
  BumnTreeState get _bs => ref.read(bumnTreeProvider);
  BumnTreeNotifier get _notifier => ref.read(bumnTreeProvider.notifier);

  Future<List<BumnTreeNode>>? get _future => _bs.future;
  String get _query => _bs.query;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pemuatan pohon (load-once) dipindah ke BumnTreeNotifier.start(). Timing
    // tetap di didChangeDependencies agar frame pertama sudah punya future
    // (skeleton), sama seperti sebelumnya. Sesi dibaca notifier via provider
    // (bumnRepoProvider → apiClientProvider), jadi tak perlu context di sini.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _notifier.start();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() => _notifier.refresh();

  List<BumnTreeNode> _flatten(List<BumnTreeNode> nodes, [List<BumnTreeNode>? acc]) {
    acc ??= [];
    for (final n in nodes) {
      acc.add(n);
      _flatten(n.children, acc);
    }
    return acc;
  }

  Color _levelColor(String? level) {
    switch (level) {
      case 'Induk':
        return AppColors.primaryNavy;
      case 'Anak':
        return AppColors.secondaryOrange;
      case 'Cucu':
        return AppColors.successGreen;
      case 'Cicit':
        return AppColors.purpleAccent;
      default:
        return AppColors.grayStage;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(bumnTreeProvider);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'Ekosistem BUMN', showBack: true),
      body: FutureBuilder<List<BumnTreeNode>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return SkeletonList(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, topInset, AppSpacing.lg, AppSpacing.lg),
            );
          }
          if (snap.hasError) {
            return ErrorStateView(message: 'Gagal memuat pohon BUMN', onRetry: _refresh);
          }
          final roots = snap.data ?? const <BumnTreeNode>[];
          return RefreshIndicator(
            color: AppColors.primaryNavy,
            displacement: topInset,
            onRefresh: _refresh,
            child: ListView(
              padding: EdgeInsets.fromLTRB(0, topInset, 0, AppSpacing.xxxl),
              children: [
                _searchField(roots.length),
                if (_query.isEmpty)
                  for (final r in roots) _treeNode(r, 0)
                else
                  ..._searchResults(roots),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _searchField(int rootCount) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => _notifier.onSearchChanged(v),
          decoration: InputDecoration(
            hintText: 'Cari perusahaan BUMN…',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(borderRadius: AppRadius.radiusSm),
          ),
        ),
      );

  // ── tree mode ──────────────────────────────────────────────────────────────
  Widget _treeNode(BumnTreeNode n, int depth) {
    final indent = AppSpacing.lg + depth * 14.0;
    // Dim nodes that have no pipeline of their own, so the ones with activity pop.
    final dim = !n.hasPipeline;
    final titleColor = dim ? AppColors.grayStage : AppColors.textPrimary;
    if (!n.hasChildren) {
      return Padding(
        padding: EdgeInsets.only(left: indent, right: AppSpacing.lg),
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: _dot(n.level, dim: dim),
          title: Text(n.name, style: TextStyle(fontSize: 14, color: titleColor)),
          subtitle: (n.badanHukum != null && n.badanHukum!.isNotEmpty)
              ? Text('${n.level ?? ''} · ${n.badanHukum}')
              : (n.level != null ? Text(n.level!) : null),
          trailing: n.hasPipeline
              ? const Icon(Icons.circle, size: 9, color: AppColors.successGreen)
              : null,
        ),
      );
    }
    return Theme(
      // hilangkan garis pembatas default ExpansionTile agar pohon rapi.
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Padding(
        padding: EdgeInsets.only(left: depth * 14.0),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          childrenPadding: EdgeInsets.zero,
          leading: _dot(n.level, dim: dim),
          title: Text(n.name,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: titleColor)),
          subtitle: Text(
            '${n.badanHukum ?? n.level ?? ''} · ${n.descendantCount} anak usaha',
            style: const TextStyle(fontSize: 12),
          ),
          children: [for (final c in n.children) _treeNode(c, depth + 1)],
        ),
      ),
    );
  }

  // ── search mode (flat) ───────────────────────────────────────────────────────
  List<Widget> _searchResults(List<BumnTreeNode> roots) {
    final q = _query.toLowerCase();
    final matches =
        _flatten(roots).where((n) => n.name.toLowerCase().contains(q)).toList();
    if (matches.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: Text('Tidak ada hasil')),
        ),
      ];
    }
    return [
      for (final n in matches)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: _dot(n.level, dim: !n.hasPipeline),
            title: Text(n.name,
                style: TextStyle(
                    fontSize: 14,
                    color: n.hasPipeline
                        ? AppColors.textPrimary
                        : AppColors.grayStage)),
            subtitle: Text([n.level, n.badanHukum]
                .where((e) => e != null && e.isNotEmpty)
                .join(' · ')),
            trailing: n.hasPipeline
                ? const Icon(Icons.circle, size: 9, color: AppColors.successGreen)
                : null,
          ),
        ),
    ];
  }

  Widget _dot(String? level, {bool dim = false}) => Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: _levelColor(level).withValues(alpha: dim ? 0.25 : 1),
          shape: BoxShape.circle,
        ),
      );
}
