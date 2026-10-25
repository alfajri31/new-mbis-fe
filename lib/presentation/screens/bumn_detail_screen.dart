import 'package:flutter/material.dart';

import '../../src/bumn/bumn_repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/responsive.dart';
import 'pipeline_detail_screen.dart';

/// Layar Detail BUMN (bdt) sesuai prototype.
/// Menampilkan header entitas BUMN, metrik 4 KPI (P3, P2, P1, Won),
/// daftar anak usaha (jika ada), daftar pipeline terkait, dan riwayat kunjungan.
class BumnDetailScreen extends StatelessWidget {
  final BumnTreeCustomer node;
  final String? parentName;

  const BumnDetailScreen({
    super.key,
    required this.node,
    this.parentName,
  });

  String get _subtitle {
    if (parentName != null && parentName!.trim().isNotEmpty) {
      return 'Anak usaha dari $parentName';
    }
    if (node.level != null && node.level!.trim().isNotEmpty) {
      final kidsPart = node.hasChildren ? ' · ${node.children.length} anak usaha' : '';
      return '${node.level!}$kidsPart';
    }
    if (node.hasChildren) {
      return 'Induk · ${node.children.length} anak usaha';
    }
    return 'BUMN';
  }

  @override
  Widget build(BuildContext context) {
    final p3Count = node.subtree.p3 > 0
        ? node.subtree.p3
        : (node.own.p3 > 0
            ? node.own.p3
            : node.links.where((l) => l.stage.toUpperCase() == 'P3').length);
    final p2Count = node.subtree.p2 > 0
        ? node.subtree.p2
        : (node.own.p2 > 0
            ? node.own.p2
            : node.links.where((l) => l.stage.toUpperCase() == 'P2').length);
    final p1Count = node.subtree.p1 > 0
        ? node.subtree.p1
        : (node.own.p1 > 0
            ? node.own.p1
            : node.links.where((l) => l.stage.toUpperCase() == 'P1').length);
    final wonCount = node.subtree.won > 0
        ? node.subtree.won
        : (node.own.won > 0
            ? node.own.won
            : (node.wonCount > 0
                ? node.wonCount
                : node.links.where((l) => l.stage.toUpperCase() == 'WON').length));

    return Scaffold(
      backgroundColor: AppColors.bgScaffold,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header Navy
            Container(
              color: AppColors.navyMbis,
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.of(context).padding.top + 8,
                16,
                20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Baris Tombol Kembali & Judul Layar
                  Row(
                    children: [
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        icon: const Icon(Icons.chevron_left, size: 28, color: AppColors.surfaceWhite),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Detail BUMN',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.surfaceWhite,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Info BUMN: Icon Box & Nama
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.whiteAlpha12,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.apartment,
                          size: 28,
                          color: AppColors.surfaceWhite,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              node.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                color: AppColors.surfaceWhite,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _subtitle,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.whiteAlpha78,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Konten Isi
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.isWide(context)
                        ? Responsive.contentMaxWidthFor(context)
                        : double.infinity,
                  ),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      // 1. Grid 2x2: Metrik KPI (P3, P2, P1, Won)
                      _buildKpiGrid(
                        p3: p3Count,
                        p2: p2Count,
                        p1: p1Count,
                        won: wonCount,
                      ),
                      const SizedBox(height: 16),

                      // 2. Daftar Anak Usaha (jika ada)
                      if (node.hasChildren) ...[
                        _buildSectionHeader(
                          title: 'Anak Usaha',
                          count: '${node.children.length} entitas',
                        ),
                        const SizedBox(height: 8),
                        _buildKidsCard(context),
                        const SizedBox(height: 16),
                      ],

                      // 3. Daftar Pipeline
                      _buildSectionHeader(
                        title: 'Pipeline',
                        count: '${node.links.length} pipeline',
                      ),
                      const SizedBox(height: 8),
                      if (node.links.isEmpty)
                        _buildEmptyCard('Belum ada pipeline')
                      else
                        ...node.links.map((link) => _buildPipelineCard(context, link)),

                      const SizedBox(height: 16),

                      // 4. Riwayat Kunjungan
                      _buildVisitHistoryHeader(),
                      const SizedBox(height: 8),
                      _buildEmptyCard('Belum ada kunjungan'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Grid 2x2 Metrik KPI ───────────────────────────────────────────────────
  Widget _buildKpiGrid({
    required int p3,
    required int p2,
    required int p1,
    required int won,
  }) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.8,
      children: [
        _buildKpiCard(value: '$p3', label: 'Pipeline P3', color: AppColors.iconDropdown),
        _buildKpiCard(value: '$p2', label: 'Pipeline P2', color: AppColors.orangeDark),
        _buildKpiCard(value: '$p1', label: 'Pipeline P1', color: AppColors.navyMbis),
        _buildKpiCard(value: '$won', label: 'Won', color: AppColors.greenTotal),
      ],
    );
  }

  Widget _buildKpiCard({
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section Anak Usaha ─────────────────────────────────────────────────────
  Widget _buildKidsCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDivider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < node.children.length; i++) ...[
            _buildKidRow(context, node.children[i]),
            if (i < node.children.length - 1)
              const Divider(height: 1, color: AppColors.bgDisabled),
          ],
        ],
      ),
    );
  }

  Widget _buildKidRow(BuildContext context, BumnTreeCustomer kid) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BumnDetailScreen(
              node: kid,
              parentName: node.name,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.hintText,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                kid.name,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.navyBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${kid.pipelineCount} pipeline',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyMbis,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.iconDropdown,
            ),
          ],
        ),
      ),
    );
  }

  // ── Section Pipeline Cards ─────────────────────────────────────────────────
  Widget _buildPipelineCard(BuildContext context, BumnLink link) {
    final title = link.customer.name.isNotEmpty
        ? link.customer.name
        : 'Pipeline ${link.pipelineId}';
    final isFromKid = link.customer.name != node.name;

    final kanwil = (link.kanwil != null && link.kanwil!.isNotEmpty)
        ? link.kanwil!
        : 'Kantor Wilayah 1';
    final kc = (link.kc != null && link.kc!.isNotEmpty)
        ? (link.kc!.startsWith('KC ') ? link.kc! : 'KC ${link.kc}')
        : 'KC Padang';
    final rm = (link.rm != null && link.rm!.isNotEmpty)
        ? link.rm!
        : 'Mohammad Ridwan Majid';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PipelineDetailScreen(pipelineId: link.pipelineId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Kartu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isFromKid) ...[
                          Text(
                            link.customer.name,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                        ],
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Sumber Bisnis: Customer BUMN',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStageBadge(link.stage),
                ],
              ),
              const SizedBox(height: 12),

              // Kotak Info Pengelola
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.bgDisabledCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.apartment_outlined,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$kc · $kanwil',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 15,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            rm,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Footer: Estimasi Premi
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.bgDisabled),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estimasi Premi',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          link.premiShort,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyMbis,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Tahap',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          link.stage,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStageBadge(String stage) {
    Color bg;
    Color fg;
    switch (stage.toUpperCase()) {
      case 'P3':
        bg = AppColors.blueLightBg;
        fg = AppColors.navyMbis;
        break;
      case 'P2':
        bg = AppColors.badgeP2Bg;
        fg = AppColors.alertTitle;
        break;
      case 'P1':
        bg = AppColors.badgeP1Bg;
        fg = AppColors.greenTotal;
        break;
      case 'WON':
        bg = AppColors.greenTotal;
        fg = AppColors.surfaceWhite;
        break;
      case 'DECLINE':
      default:
        bg = AppColors.errorBannerBg;
        fg = AppColors.redRequired;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        stage,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  // ── Header & Empty Helpers ────────────────────────────────────────────────
  Widget _buildSectionHeader({required String title, required String count}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        Text(
          count,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildVisitHistoryHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Riwayat Kunjungan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Tahun berjalan',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        Text(
          'Lihat semua',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.orangeDark,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderDivider),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
