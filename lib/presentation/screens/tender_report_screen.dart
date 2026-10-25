import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../src/tender/tender_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../utils/responsive.dart';
import '../providers/tender_report_provider.dart';
import '../widgets/state_views.dart';
import 'pipeline_detail_screen.dart';

/// Report Tender: ringkasan statistik (Menang, Kalah, Win Rate, bar proporsi),
/// filter chip (Semua, Menang, Kalah), serta kartu accordion detail tender
/// yang sesuai dengan prototype.
class TenderReportScreen extends ConsumerStatefulWidget {
  const TenderReportScreen({super.key});

  @override
  ConsumerState<TenderReportScreen> createState() => _TenderReportScreenState();
}

class _TenderReportScreenState extends ConsumerState<TenderReportScreen> {
  TenderReportState get _trs => ref.read(tenderReportProvider);
  TenderReportNotifier get _notifier => ref.read(tenderReportProvider.notifier);

  Future<TenderReport>? get _future => _trs.future;
  String get _filter => _trs.filter; // all | won | loss

  final Set<String> _expandedIds = {};

  Future<void> _refresh() => _notifier.refresh();

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr.trim());
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatPeriod(String? mulai, String? selesai) {
    final start = _formatDate(mulai);
    final end = _formatDate(selesai);
    if (start == '-' && end == '-') return '-';
    if (start != '-' && end != '-') return '$start – $end';
    return start != '-' ? start : end;
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(tenderReportProvider);

    return Scaffold(
      backgroundColor: AppColors.bgDisabledCard,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: AppColors.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Report Tender',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderDivider),
        ),
      ),
      body: FutureBuilder<TenderReport>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const SkeletonList(
              padding: EdgeInsets.all(16),
            );
          }
          if (snap.hasError) {
            return ErrorStateView(
              message: 'Gagal memuat report tender',
              onRetry: _refresh,
            );
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
                color: AppColors.navyMbis,
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    // 1. Box Ringkasan Statistik
                    _buildSummaryCard(r),
                    const SizedBox(height: 12),

                    // 2. Chip Filter (Semua, Menang, Kalah)
                    _buildFilterChips(r),
                    const SizedBox(height: 14),

                    // 3. Daftar Tender Menang
                    if (_filter != 'loss') ...[
                      _buildSectionTitle(
                        title: 'Tender Menang (${r.wonCount})',
                        dotColor: AppColors.greenTotal,
                      ),
                      const SizedBox(height: 10),
                      if (r.won.isEmpty)
                        _buildEmptyTile('Belum ada tender menang')
                      else
                        ...r.won.map(_buildTenderAccordion),
                      const SizedBox(height: 14),
                    ],

                    // 4. Daftar Tender Kalah
                    if (_filter != 'won') ...[
                      _buildSectionTitle(
                        title: 'Tender Kalah (${r.lossCount})',
                        dotColor: AppColors.redRequired,
                      ),
                      const SizedBox(height: 10),
                      if (r.loss.isEmpty)
                        _buildEmptyTile('Belum ada tender kalah')
                      else
                        ...r.loss.map(_buildTenderAccordion),
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

  // ── 1. Summary Card ────────────────────────────────────────────────────────
  Widget _buildSummaryCard(TenderReport r) {
    final winPct = (r.winRate * 100).round();
    final total = r.totalWithActive > 0 ? r.totalWithActive : 1;
    final wFlex = (r.wonCount * 1000 / total).round();
    final lFlex = (r.lossCount * 1000 / total).round();
    final rFlex = 1000 - wFlex - lFlex;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderDivider),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(21, 34, 59, 0.06),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 3 Kolom Metrik
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  value: '${r.wonCount}',
                  label: 'Menang',
                  color: AppColors.greenTotal,
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.borderDivider),
              Expanded(
                child: _buildMetricItem(
                  value: '${r.lossCount}',
                  label: 'Kalah',
                  color: AppColors.redRequired,
                ),
              ),
              Container(width: 1, height: 40, color: AppColors.borderDivider),
              Expanded(
                child: _buildMetricItem(
                  value: '$winPct%',
                  label: 'Win Rate',
                  color: AppColors.navyMbis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar Proporsi
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Container(
                color: AppColors.grayStage,
                child: Row(
                  children: [
                    if (wFlex > 0)
                      Expanded(
                        flex: wFlex,
                        child: Container(color: AppColors.greenTotal),
                      ),
                    if (lFlex > 0)
                      Expanded(
                        flex: lFlex,
                        child: Container(color: AppColors.redRequired),
                      ),
                    if (rFlex > 0)
                      Expanded(
                        flex: rFlex,
                        child: Container(color: AppColors.grayStage),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Caption
          Text(
            'Win rate dari ${r.totalWithActive} tender, termasuk ${r.activeCount} yang masih berjalan.',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem({
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  // ── 2. Filter Chips ────────────────────────────────────────────────────────
  Widget _buildFilterChips(TenderReport r) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(
            keyVal: 'all',
            label: 'Semua (${r.total})',
            isSelected: _filter == 'all',
          ),
          const SizedBox(width: 8),
          _buildChip(
            keyVal: 'won',
            label: 'Menang (${r.wonCount})',
            isSelected: _filter == 'won',
          ),
          const SizedBox(width: 8),
          _buildChip(
            keyVal: 'loss',
            label: 'Kalah (${r.lossCount})',
            isSelected: _filter == 'loss',
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String keyVal,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _notifier.setFilter(keyVal),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyMbis : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.navyMbis : AppColors.borderDefault,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 14, color: AppColors.surfaceWhite),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.surfaceWhite : AppColors.textLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Section Title ───────────────────────────────────────────────────────
  Widget _buildSectionTitle({required String title, required Color dotColor}) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyTile(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  // ── 4. Tender Accordion Card ───────────────────────────────────────────────
  Widget _buildTenderAccordion(TenderItem t) {
    final cardId = (t.tenderNo != null && t.tenderNo!.isNotEmpty)
        ? t.tenderNo!
        : (t.pipelineId.isNotEmpty ? t.pipelineId : t.title);
    final isOpen = _expandedIds.contains(cardId);

    final subParts = [
      if (t.customerName != null && t.customerName!.isNotEmpty) t.customerName!,
      if (t.premi != null && t.premi! > 0)
        'Premi ${AppFormat.currencyShort(t.premi!)}',
    ];
    final sub = subParts.join(' · ');

    final kanwil = (t.kanwil != null && t.kanwil!.isNotEmpty) ? t.kanwil! : 'Kantor Wilayah 1';
    final kc = (t.kc != null && t.kc!.isNotEmpty)
        ? (t.kc!.startsWith('KC ') ? t.kc! : 'KC ${t.kc}')
        : 'KC Padang';
    final rm = (t.rmName != null && t.rmName!.isNotEmpty) ? t.rmName! : 'Mohammad Ridwan Majid';
    final pipeText = [
      t.pipelineName ?? t.title,
      if (t.stage != null && t.stage!.isNotEmpty) t.stage!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Baris Accordion
          InkWell(
            onTap: () {
              setState(() {
                if (isOpen) {
                  _expandedIds.remove(cardId);
                } else {
                  _expandedIds.add(cardId);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (sub.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            sub,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      size: 22,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Detail Isi Accordion (saat terbuka)
          if (isOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDetailRow('No. Tender', t.tenderNo ?? '-'),
                  _buildDetailRow('Metode', t.metode ?? 'Tender Terbuka'),
                  _buildDetailRow('Kantor Wilayah', kanwil),
                  _buildDetailRow('Kantor Cabang', kc),
                  _buildDetailRow('RM', rm),
                  _buildDetailRow('Pipeline', pipeText),
                  _buildDetailRow('Produk / COB', t.product ?? '-'),
                  _buildDetailRow('Nilai TSI', t.tsi != null ? AppFormat.rupiah(t.tsi!) : '-'),
                  _buildDetailRow('Premi', t.premi != null ? AppFormat.rupiah(t.premi!) : '-'),
                  _buildDetailRow('Periode Polis', _formatPeriod(t.periodeMulai, t.periodeSelesai)),
                  _buildDetailRow('Batas Penawaran', _formatDate(t.batasPenawaran)),
                  _buildDetailRow('Pengumuman Pemenang', _formatDate(t.pengumumanPemenang)),

                  // Co-insurer Share jika ada
                  if (t.shareAskrindo != null || t.shares.isNotEmpty) ...[
                    if (t.shareAskrindo != null)
                      _buildDetailRow(
                        'Share Askrindo',
                        '${t.shareAskrindo!.toStringAsFixed(t.shareAskrindo! % 1 == 0 ? 0 : 2)}%',
                      ),
                    for (final s in t.shares)
                      _buildDetailRow(
                        'Co-insurer (${s.partyType ?? 'Member'})',
                        '${s.name ?? '-'}${s.percentage != null ? ' (${s.percentage!.toStringAsFixed(s.percentage! % 1 == 0 ? 0 : 2)}%)' : ''}',
                      ),
                  ],

                  // Alasan Kalah jika ada
                  if (t.lossReason != null && t.lossReason!.trim().isNotEmpty)
                    _buildDetailRow('Alasan Kalah', t.lossReason!.trim()),

                  // Tombol "Lihat Pipeline"
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        onPressed: () {
                          if (t.pipelineId.isNotEmpty) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PipelineDetailScreen(pipelineId: t.pipelineId),
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.navyMbis, width: 1.5),
                          backgroundColor: AppColors.surfaceWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        child: const Text(
                          'Lihat Pipeline',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyMbis,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.bgDisabled),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
