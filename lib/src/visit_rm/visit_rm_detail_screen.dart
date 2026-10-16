import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import 'visit_rm_models.dart';

class VisitRmDetailScreen extends StatefulWidget {
  final String visitId;
  final String activeRoleLabel;

  const VisitRmDetailScreen({
    super.key,
    required this.visitId,
    this.activeRoleLabel = 'Pinca KC Padang',
  });

  @override
  State<VisitRmDetailScreen> createState() => _VisitRmDetailScreenState();
}

class _VisitRmDetailScreenState extends State<VisitRmDetailScreen> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    VisitReviewStore.instance.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    VisitReviewStore.instance.removeListener(_onStoreChanged);
    _noteController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final v = kDefaultVisits.firstWhere(
      (item) => item.id == widget.visitId,
      orElse: () => kDefaultVisits.first,
    );
    final rm = kDefaultRms.firstWhere(
      (r) => r.id == v.rmId,
      orElse: () => const RmModel(id: '', nama: '-', jab: '', cab: '-'),
    );
    final review = VisitReviewStore.instance.getReview(v.id);
    final stageInfo = VisitRmHelpers.getStageInfo(v.stage);
    final isReviewed = review != null;

    return Scaffold(
      backgroundColor: AppColors.bgScreen,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderDivider, height: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textDark),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/kelola/visit-rm');
            }
          },
        ),
        titleSpacing: 0,
        title: const Text(
          'Detail Visit RM',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Photo banner or Empty box
              if (v.foto)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 210,
                    decoration: BoxDecoration(
                      gradient: VisitRmHelpers.getAvatarGradient(v.id),
                    ),
                    child: Stack(
                      children: [
                        const Center(
                          child: Icon(
                            Icons.camera_alt_outlined,
                            size: 56,
                            color: AppColors.bannerCameraIcon,
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
                                colors: [
                                  AppColors.bannerOverlayDark,
                                  AppColors.transparent,
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on,
                                      size: 14,
                                      color: AppColors.surfaceWhite,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        v.lokasi,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.surfaceWhite,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Check-in ${VisitRmHelpers.formatIndoDate(v.tanggal)} · ${v.jam} WIB',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textWhite70,
                                  ),
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
                    color: AppColors.bgDisabled,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.borderInactive,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.no_photography_outlined,
                        size: 32,
                        color: AppColors.iconDropdown,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Tidak ada foto kunjungan',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

              // Rekap Detail Card
              _buildSectionCard(
                title: 'Rekap Detail',
                children: [
                  _buildDetailRow(
                    'Nama Perusahaan',
                    Text(
                      v.perusahaan,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  _buildDetailRow(
                    'Nama RM',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rm.nama,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '${rm.jab} · KC ${rm.cab}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildDetailRow(
                    'Tanggal',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${VisitRmHelpers.getDayName(v.tanggal)}, ${VisitRmHelpers.formatIndoDate(v.tanggal)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                        Text(
                          '${v.jam} WIB',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildDetailRow(
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
                  _buildDetailRow(
                    'Nilai Pipeline',
                    Text(
                      VisitRmHelpers.formatRupiah(v.nilai),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navyMbis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Hasil Kunjungan Card
              _buildSectionCard(
                title: 'Hasil Kunjungan',
                children: [
                  _buildDetailRow(
                    'Lokasi check-in',
                    Text(
                      v.lokasi,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                        height: 1.4,
                      ),
                    ),
                  ),
                  _buildDetailRow(
                    'Tujuan',
                    Text(
                      v.tujuan,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                        height: 1.4,
                      ),
                    ),
                  ),
                  _buildDetailRow(
                    'Hasil',
                    Text(
                      v.hasil,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                        height: 1.4,
                      ),
                    ),
                  ),
                  _buildDetailRow(
                    'Tindak lanjut',
                    Text(
                      v.tindakLanjut,
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
              const SizedBox(height: 14),

              // Tinjauan Atasan Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  border: Border.all(color: AppColors.borderDivider),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tinjauan Atasan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (isReviewed) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.badgeP1Bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '✓ Sudah ditinjau',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.greenTotal,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${review.reviewer} · ${review.reviewedAt}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textLabel,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Catatan: ${review.note.isEmpty ? '-' : review.note}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textDark,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            VisitReviewStore.instance.unmarkReviewed(v.id);
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.orangeDark,
                            padding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text(
                            'Batalkan tanda tinjau',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Catatan / arahan untuk RM (opsional) — sebagai ${widget.activeRoleLabel}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _noteController,
                        maxLines: 3,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: 'mis. Segera kirim QS revisi, jadwalkan kunjungan lanjutan',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: AppColors.hintText,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          filled: true,
                          fillColor: AppColors.surfaceWhite,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.borderDefault, width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.borderDefault, width: 1.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.navyMbis, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            VisitReviewStore.instance.markReviewed(
                              v.id,
                              widget.activeRoleLabel,
                              _noteController.text.trim(),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Kunjungan ditandai sudah ditinjau'),
                                backgroundColor: AppColors.greenTotal,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.greenTotal,
                            foregroundColor: AppColors.surfaceWhite,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Tandai sudah ditinjau',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Button "Lihat Pipeline"
              if (v.pipelineId != null) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      context.push('/dashboard/pipeline/${v.pipelineId}');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navyMbis,
                      side: const BorderSide(color: AppColors.navyMbis, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Lihat Pipeline',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border.all(color: AppColors.borderDivider),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, Widget content) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.bgDisabled)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: content),
        ],
      ),
    );
  }
}
