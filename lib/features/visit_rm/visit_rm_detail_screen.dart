import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import 'models/visit_monitor_models.dart';
import 'providers/visit_monitor_provider.dart';
import 'visit_rm_models.dart';
import 'widget/visit_detail_widgets.dart';

class VisitRmDetailScreen extends ConsumerWidget {
  final String visitId;
  final String activeRoleLabel;

  const VisitRmDetailScreen({
    super.key,
    required this.visitId,
    this.activeRoleLabel = 'RM',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(visitDetailProvider(visitId));

    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: _buildAppBar(context, detailAsync.asData?.value),
      body: SafeArea(
        child: detailAsync.when(
          loading: () => _buildLoadingState(),
          error: (err, stack) => _buildErrorState(context, ref, err.toString()),
          data: (detail) => _buildDetailContent(context, detail),
        ),
      ),
    );
  }


  PreferredSizeWidget _buildAppBar(BuildContext context, VisitMonitorDetail? detail) {
    return AppBar(
      backgroundColor: AppColors.surfaceWhite,
      surfaceTintColor: AppColors.transparent,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE3E7EF), height: 1),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF15223B)),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            final path = GoRouterState.of(context).uri.path;
            if (path.startsWith('/kelola/tools')) {
              context.go('/kelola/tools/visit-rm');
            } else {
              context.go('/tools/visit-rm');
            }
          }
        },
      ),
      titleSpacing: 0,
      title: const Text(
        'Detail Visit RM',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Color(0xFF15223B),
        ),
      ),
      actions: [
        if (detail != null && detail.isReviewed)
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.greenTotal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.greenTotal.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: AppColors.greenTotal),
                    SizedBox(width: 4),
                    Text(
                      'Ditinjau',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.greenTotal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- Loading State ---
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.navyMbis),
          SizedBox(height: 14),
          Text(
            'Memuat detail kunjungan...',
            style: TextStyle(fontSize: 13.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // --- Negative Case: Error State ---
  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.alertBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.alertTitle, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Gagal Memuat Detail',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                error.replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(visitDetailProvider(visitId));
                },
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.navyMbis,
                  foregroundColor: AppColors.surfaceWhite,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Detail API Content ---
  Widget _buildDetailContent(BuildContext context, VisitMonitorDetail detail) {
    final stageInfo = VisitRmHelpers.getStageInfo(detail.stage ?? 'P3');
    final lat = double.tryParse(detail.gpsLatitude ?? '') ?? -0.9471;
    final lng = double.tryParse(detail.gpsLongitude ?? '') ?? 100.4172;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Photo banner
          if (detail.photoUrls.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 210,
                decoration: BoxDecoration(
                  gradient: VisitRmHelpers.getAvatarGradient(detail.id),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.network(
                        detail.photoUrls.first,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 56, color: Colors.white70),
                        ),

                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Color(0x8C000000), Colors.transparent],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Colors.white),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    detail.customerAddress ?? (detail.officeName ?? '-'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              detail.activityDate != null
                                  ? 'Check-in ${VisitRmHelpers.formatDateTime(detail.activityDate!)}'
                                  : 'Check-in -',
                              style: const TextStyle(fontSize: 11.5, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF1F6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFB7C1D1), width: 1),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 32, color: Color(0xFF6B7485)),
                  SizedBox(height: 6),
                  Text(
                    'Tidak ada foto kunjungan',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B7485)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),

          // Review Status Banner
          if (detail.isReviewed) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF86EFAC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified, size: 18, color: AppColors.greenTotal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Telah Ditinjau oleh ${detail.review?.reviewedByName ?? 'Atasan'}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (detail.review?.reviewedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Waktu: ${VisitRmHelpers.formatDateTime(detail.review!.reviewedAt!)}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF15803D)),
                    ),
                  ],
                  if (detail.review?.note != null && detail.review!.note!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Catatan: "${detail.review!.note}"',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 2. Rekap Detail Card
          VisitDetailSectionCard(
            title: 'Rekap Detail',
            children: [
              VisitDetailRow(
                'Nama Perusahaan',
                Text(
                  detail.customerName ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'Sumber Bisnis',
                Text(
                  detail.sourceName ?? (detail.sourceType ?? '-'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'Status Kerja Sama',
                Text(
                  detail.customerType ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'Nama RM',
                Text(
                  detail.rmName ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              if (detail.rmNip != null && detail.rmNip!.isNotEmpty)
                VisitDetailRow(
                  'NIP RM',
                  Text(
                    detail.rmNip!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15223B),
                      height: 1.4,
                    ),
                  ),
                ),
              VisitDetailRow(
                'Kantor Wilayah',
                Text(
                  detail.regionName ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'Kantor Cabang',
                Text(
                  detail.officeName ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'Tanggal & Waktu',
                Text(
                  detail.activityDate != null
                      ? VisitRmHelpers.formatDateTime(detail.activityDate!)
                      : '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'Stage Pipeline',
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: stageInfo.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      stageInfo.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: stageInfo.fg,
                      ),
                    ),
                  ),
                ),
              ),
              VisitDetailRow(
                'Jenis Aktivitas',
                Text(
                  detail.type ?? 'Kunjungan Nasabah',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'COB',
                Text(
                  detail.cobName ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'LOB',
                Text(
                  detail.lobName ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'TOC',
                Text(
                  detail.tocName ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'Nilai TSI / Nilai Penjaminan',
                Text(
                  detail.tsi != null ? VisitRmHelpers.formatRupiah(detail.tsi!) : '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'Potensi Premi',
                Text(
                  detail.potensiPremi != null
                      ? VisitRmHelpers.formatRupiah(detail.potensiPremi!)
                      : '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Hasil Kunjungan Card
          VisitDetailSectionCard(
            title: 'Hasil Kunjungan',
            children: [
              VisitDetailRow(
                'Lokasi / Alamat',
                Text(
                  detail.customerAddress ?? (detail.officeName ?? '-'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'Catatan Kunjungan',
                Text(
                  detail.notes ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              VisitDetailRow(
                'Rencana Tindak Lanjut',
                Text(
                  detail.actionPlan ?? '-',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
              ),
              if (detail.nextFollowupDate != null)
                VisitDetailRow(
                  'Tanggal Follow-up',
                  Text(
                    VisitRmHelpers.formatDateTime(detail.nextFollowupDate!),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF15223B),
                      height: 1.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 4. Peta Kunjungan Card
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              border: Border.all(color: const Color(0xFFE3E7EF)),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Peta Kunjungan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15223B),
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 180,
                    color: const Color(0xFFE6EEF2),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MapGraphicPainter(),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$lat, $lng',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15223B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  detail.customerAddress ?? (detail.officeName ?? '-'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF15223B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF0E2B53), width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.map_outlined, size: 16, color: Color(0xFF0E2B53)),
                        SizedBox(width: 6),
                        Text(
                          'Buka di Google Maps',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0E2B53),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. Button "Lihat Pipeline"
          if (detail.pipelineId != null && detail.pipelineId!.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  context.push('/dashboard/pipeline/${detail.pipelineId}');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0E2B53),
                  side: const BorderSide(color: Color(0xFF0E2B53), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Lihat Pipeline',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapGraphicPainter extends CustomPainter {

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / 360;
    final scaleY = size.height / 180;

    canvas.save();
    canvas.scale(scaleX, scaleY);

    final riverPaint = Paint()
      ..color = const Color(0xFFB9D4E6)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final riverPath = Path()
      ..moveTo(0, 120)
      ..cubicTo(60, 100, 120, 140, 180, 118)
      ..cubicTo(240, 96, 300, 90, 360, 110);
    canvas.drawPath(riverPath, riverPaint);

    final gridRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 60), const Offset(360, 60), gridRoadPaint);
    canvas.drawLine(const Offset(0, 150), const Offset(360, 150), gridRoadPaint);
    canvas.drawLine(const Offset(70, 0), const Offset(70, 180), gridRoadPaint);
    canvas.drawLine(const Offset(210, 0), const Offset(210, 180), gridRoadPaint);
    canvas.drawLine(const Offset(300, 0), const Offset(300, 180), gridRoadPaint);

    final secRoadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(20, 20), const Offset(340, 170), secRoadPaint);
    canvas.drawLine(const Offset(0, 95), const Offset(360, 40), secRoadPaint);

    final parkPaint1 = Paint()..color = const Color(0xFFD9E3D2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(88, 72, 40, 28), const Radius.circular(3)),
      parkPaint1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(228, 16, 56, 34), const Radius.circular(3)),
      parkPaint1,
    );

    final parkPaint2 = Paint()..color = const Color(0xFFEDE3D6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(232, 124, 48, 22), const Radius.circular(3)),
      parkPaint2,
    );

    final pulsePaint = Paint()..color = const Color(0xFFE8732A).withValues(alpha: 0.18);
    canvas.drawCircle(const Offset(180, 92), 26, pulsePaint);

    final pinPaint = Paint()
      ..color = const Color(0xFFE8732A)
      ..style = PaintingStyle.fill;
    final pinBorderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pinPath = Path()
      ..moveTo(180, 96)
      ..cubicTo(170, 82, 166, 76, 166, 70)
      ..arcToPoint(const Offset(194, 70), radius: const Radius.circular(14), clockwise: true)
      ..cubicTo(194, 76, 190, 82, 180, 96)
      ..close();

    canvas.drawPath(pinPath, pinPaint);
    canvas.drawPath(pinPath, pinBorderPaint);

    final dotPaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(180, 70), 5, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
