import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../src/tender/tender_repository.dart';
import '../../utils/format.dart';
import '../../utils/responsive.dart';
import '../providers/tender_report_provider.dart';
import '../widgets/glass_app_bar.dart';
import '../widgets/state_views.dart';

/// Report Tender (global): win/loss ringkasan + daftar tender menang (dgn share
/// Askrindo & co-insurer) dan daftar tender kalah (dgn alasan). Dibuka dari BUMN.
class TenderReportScreen extends ConsumerStatefulWidget {
  const TenderReportScreen({super.key});

  @override
  ConsumerState<TenderReportScreen> createState() => _TenderReportScreenState();
}

class _TenderReportScreenState extends ConsumerState<TenderReportScreen> {
  // State bisnis/async dikelola TenderReportNotifier. Getter berikut memproksinya
  // agar seluruh kode build/widget di bawah tetap memakai nama lama tanpa diubah.
  TenderReportState get _trs => ref.read(tenderReportProvider);
  TenderReportNotifier get _notifier => ref.read(tenderReportProvider.notifier);

  Future<TenderReport>? get _future => _trs.future;
  String get _filter => _trs.filter; // all | won | loss

  // Pull-to-refresh / retry → delegasi ke notifier (logika dipindah utuh).
  Future<void> _refresh() => _notifier.refresh();

  @override
  Widget build(BuildContext context) {
    // Berlangganan state notifier → rebuild otomatis saat berubah (ganti setState).
    ref.watch(tenderReportProvider);
    final topInset = MediaQuery.of(context).padding.top + kToolbarHeight;
    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBar(title: 'Report Tender', showBack: true),
      body: FutureBuilder<TenderReport>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return SkeletonList(
              padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg, topInset, AppSpacing.lg, AppSpacing.lg),
            );
          }
          if (snap.hasError) {
            return ErrorStateView(
                message: 'Gagal memuat report tender', onRetry: _refresh);
          }
          final r = snap.data ?? const TenderReport();
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.isWide(context)
                    ? Responsive.contentMaxWidthFor(context)
                    : double.infinity,
              ),
              child: RefreshIndicator(
                color: AppColors.primaryNavy,
                displacement: topInset,
                onRefresh: _refresh,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg, topInset + AppSpacing.md, AppSpacing.lg, AppSpacing.xxxl),
                  children: [
                    _summary(r),
                    const SizedBox(height: AppSpacing.md),
                    _filterChips(r),
                    const SizedBox(height: AppSpacing.md),
                    if (_filter != 'loss') ...[
                      _sectionTitle('Tender Menang', r.wonCount, AppColors.successGreen),
                      if (r.won.isEmpty)
                        _emptyLine('Belum ada tender menang')
                      else
                        ...r.won.map(_wonTile),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (_filter != 'won') ...[
                      _sectionTitle('Tender Kalah', r.lossCount, AppColors.errorRed),
                      if (r.loss.isEmpty)
                        _emptyLine('Belum ada tender kalah')
                      else
                        ...r.loss.map(_lossTile),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Filter: Semua / Menang / Kalah.
  Widget _filterChips(TenderReport r) {
    Widget chip(String value, String label) {
      final selected = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: AppSpacing.sm),
        child: ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 12)),
          selected: selected,
          onSelected: (_) => _notifier.setFilter(value),
          labelStyle: TextStyle(
              fontSize: 12,
              color: selected ? Colors.white : AppColors.textSecondary),
          selectedColor: AppColors.primaryNavy,
        ),
      );
    }

    return Row(
      children: [
        chip('all', 'Semua (${r.total})'),
        chip('won', 'Menang (${r.wonCount})'),
        chip('loss', 'Kalah (${r.lossCount})'),
      ],
    );
  }

  // ── Summary: win/loss counts + proportional bar + win rate ────────────────
  Widget _summary(TenderReport r) {
    final winPct = (r.winRate * 100).round();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.border),
        boxShadow: const [AppShadows.level1],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _bigStat('Menang', '${r.wonCount}', AppColors.successGreen)),
              Container(width: 1, height: 40, color: AppColors.border),
              Expanded(child: _bigStat('Kalah', '${r.lossCount}', AppColors.errorRed)),
              Container(width: 1, height: 40, color: AppColors.border),
              Expanded(child: _bigStat('Win Rate', '$winPct%', AppColors.primaryNavy)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Proportional won/loss/active bar — segments match the win-rate
          // denominator, so the bar and the percentage always agree.
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: r.totalWithActive == 0
                  ? Container(color: AppColors.border)
                  : Row(
                      children: [
                        Expanded(
                          flex: r.wonCount,
                          child: Container(color: AppColors.successGreen),
                        ),
                        Expanded(
                          flex: r.lossCount,
                          child: Container(color: AppColors.errorRed),
                        ),
                        Expanded(
                          flex: r.activeCount,
                          child: Container(color: AppColors.grayStage),
                        ),
                      ],
                    ),
            ),
          ),
          if (r.activeCount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Win rate dari ${r.totalWithActive} tender, termasuk ${r.activeCount} yang masih berjalan.',
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _bigStat(String label, String value, Color color) => Column(
        children: [
          Text(value,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      );

  Widget _sectionTitle(String label, int count, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 6),
            Text('$label ($count)',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ],
        ),
      );

  Widget _emptyLine(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.grayStage)),
      );

  Widget _card({required Widget child}) => Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: child,
        ),
      );

  // Won tender: tap to reveal Askrindo share + co-insurer breakdown.
  Widget _wonTile(TenderItem t) {
    return _card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        title: Text(t.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          [t.customerName, if (t.premi != null) 'Premi ${AppFormat.currencyShort(t.premi!)}']
              .where((e) => e != null && e.toString().isNotEmpty)
              .join(' · '),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        children: [
          _shareRow('Askrindo', t.shareAskrindo, highlight: true),
          for (final s in t.shares)
            _shareRow(
              '${s.name ?? '-'}${s.partyType != null ? ' (${s.partyType})' : ''}',
              s.percentage,
            ),
        ],
      ),
    );
  }

  Widget _shareRow(String name, double? pct, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(name,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
                      color: highlight ? AppColors.primaryNavy : AppColors.textPrimary)),
            ),
            Text(pct != null ? '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 2)}%' : '-',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: highlight ? AppColors.primaryNavy : AppColors.textPrimary)),
          ],
        ),
      );

  // Lost tender: tap to reveal the loss reason.
  Widget _lossTile(TenderItem t) {
    return _card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        title: Text(t.title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: t.customerName != null
            ? Text(t.customerName!,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))
            : null,
        childrenPadding:
            const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Alasan kalah: ${t.lossReason?.isNotEmpty == true ? t.lossReason : '(tidak diisi)'}',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
